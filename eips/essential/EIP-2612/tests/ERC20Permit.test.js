const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

/**
 * EIP-2612 (Permit) 종합 테스트
 *
 * 테스트 범위:
 * 1. 기본 permit() 함수 동작
 * 2. Nonce 관리 및 재사용 공격 방지
 * 3. Deadline 유효성 검증
 * 4. 서명 검증 (유효한 서명, 잘못된 서명)
 * 5. approve/transferFrom과의 통합
 * 6. EIP-712 구조화된 데이터 서명
 * 7. 엣지 케이스 및 보안 고려사항
 * 8. 가스 사용량 측정
 */
describe("EIP-2612: Permit 종합 테스트", function () {
    let myPermitToken;
    let manualPermitToken;
    let owner, spender, receiver, attacker;
    let ownerPrivateKey, spenderPrivateKey;

    // EIP-712 Domain Separator 관련
    let chainId;
    let domainSeparator;

    before(async function () {
        [owner, spender, receiver, attacker] = await ethers.getSigners();

        // 테스트용 개인 키 생성 (하드햇 기본 계정)
        ownerPrivateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
        spenderPrivateKey = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";

        // 체인 ID 가져오기
        const network = await ethers.provider.getNetwork();
        chainId = network.chainId;
    });

    beforeEach(async function () {
        // OpenZeppelin 기반 구현 배포
        const MyPermitToken = await ethers.getContractFactory("MyPermitToken");
        myPermitToken = await MyPermitToken.deploy(
            "Permit Token",
            "PMT",
            ethers.parseEther("1000000")
        );
        await myPermitToken.waitForDeployment();

        // 수동 구현 배포
        const ManualPermitToken = await ethers.getContractFactory("ManualERC20Permit");
        manualPermitToken = await ManualPermitToken.deploy(
            "Manual Permit Token",
            "MPT"
        );
        await manualPermitToken.waitForDeployment();

        // 토큰 분배
        await myPermitToken.transfer(owner.address, ethers.parseEther("10000"));
        await manualPermitToken.transfer(owner.address, ethers.parseEther("10000"));
    });

    /**
     * 유틸리티: EIP-712 서명 생성
     */
    async function signPermit(token, ownerAddress, spenderAddress, value, nonce, deadline, privateKey) {
        const domain = {
            name: await token.name(),
            version: "1",
            chainId: chainId,
            verifyingContract: await token.getAddress()
        };

        const types = {
            Permit: [
                { name: "owner", type: "address" },
                { name: "spender", type: "address" },
                { name: "value", type: "uint256" },
                { name: "nonce", type: "uint256" },
                { name: "deadline", type: "uint256" }
            ]
        };

        const message = {
            owner: ownerAddress,
            spender: spenderAddress,
            value: value,
            nonce: nonce,
            deadline: deadline
        };

        // ethers v6 서명 생성
        const wallet = new ethers.Wallet(privateKey);
        const signature = await wallet.signTypedData(domain, types, message);

        // v, r, s 분리
        const sig = ethers.Signature.from(signature);

        return {
            v: sig.v,
            r: sig.r,
            s: sig.s
        };
    }

    describe("1. 기본 Permit 함수 테스트", function () {
        it("유효한 서명으로 permit을 성공적으로 실행해야 함 (OpenZeppelin)", async function () {
            const value = ethers.parseEther("100");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600; // 1시간 후

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            // Permit 실행 전 allowance 확인
            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(0);

            // Permit 실행
            await myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            // Permit 실행 후 allowance 확인
            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(value);
        });

        it("유효한 서명으로 permit을 성공적으로 실행해야 함 (Manual)", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            expect(await manualPermitToken.allowance(owner.address, spender.address)).to.equal(0);

            await manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            expect(await manualPermitToken.allowance(owner.address, spender.address)).to.equal(value);
        });

        it("Permit 후 transferFrom이 정상 동작해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            // spender가 owner의 토큰을 receiver로 전송
            const balanceBefore = await myPermitToken.balanceOf(receiver.address);
            await myPermitToken.connect(spender).transferFrom(owner.address, receiver.address, value);
            const balanceAfter = await myPermitToken.balanceOf(receiver.address);

            expect(balanceAfter - balanceBefore).to.equal(value);
        });
    });

    describe("2. Nonce 관리 테스트", function () {
        it("초기 nonce는 0이어야 함", async function () {
            expect(await myPermitToken.nonces(owner.address)).to.equal(0);
            expect(await manualPermitToken.nonces(owner.address)).to.equal(0);
        });

        it("Permit 실행 후 nonce가 1 증가해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            expect(await myPermitToken.nonces(owner.address)).to.equal(nonce + 1n);
        });

        it("잘못된 nonce로 permit 실행 시 실패해야 함 (재사용 공격 방지)", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            // 잘못된 nonce (현재 + 1) 사용
            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce + 1n,
                deadline,
                ownerPrivateKey
            );

            await expect(
                manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.be.revertedWith("Permit: invalid signature");
        });

        it("동일한 서명을 두 번 사용할 수 없어야 함 (리플레이 공격 방지)", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            // 첫 번째 실행 성공
            await manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            // 두 번째 실행 실패 (nonce가 증가했으므로)
            await expect(
                manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.be.revertedWith("Permit: invalid signature");
        });
    });

    describe("3. Deadline 유효성 검증", function () {
        it("Deadline이 현재 시간보다 이후인 경우 성공해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600; // 1시간 후

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await expect(
                manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.not.be.reverted;
        });

        it("Deadline이 만료된 경우 실패해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) - 1; // 이미 만료

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await expect(
                manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.be.revertedWith("Permit: expired");
        });

        it("시간이 흐른 후 deadline 만료 시 실패해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 60; // 60초 후

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            // 61초 경과
            await time.increase(61);

            await expect(
                manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.be.revertedWith("Permit: expired");
        });
    });

    describe("4. 서명 검증 테스트", function () {
        it("잘못된 서명으로 permit 실행 시 실패해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            // r 값 변조
            const fakeR = "0x1234567890123456789012345678901234567890123456789012345678901234";

            await expect(
                manualPermitToken.permit(owner.address, spender.address, value, deadline, v, fakeR, s)
            ).to.be.revertedWith("Permit: invalid signature");
        });

        it("다른 사람의 서명으로 permit 실행 시 실패해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            // attacker가 서명
            const attackerPrivateKey = "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                attackerPrivateKey
            );

            await expect(
                manualPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.be.revertedWith("Permit: invalid signature");
        });

        it("잘못된 owner 주소로 permit 실행 시 실패해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await manualPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            // owner 주소로 서명했지만 다른 주소 사용
            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await expect(
                manualPermitToken.permit(attacker.address, spender.address, value, deadline, v, r, s)
            ).to.be.revertedWith("Permit: invalid signature");
        });

        it("Zero address owner로 permit 실행 시 실패해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = 0;
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                manualPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await expect(
                manualPermitToken.permit(ethers.ZeroAddress, spender.address, value, deadline, v, r, s)
            ).to.be.revertedWith("Permit: invalid owner");
        });
    });

    describe("5. approve/transferFrom 통합 테스트", function () {
        it("Permit 후 부분적인 transferFrom이 가능해야 함", async function () {
            const value = ethers.parseEther("100");
            const transferAmount = ethers.parseEther("30");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            // 30 전송
            await myPermitToken.connect(spender).transferFrom(owner.address, receiver.address, transferAmount);

            // 남은 allowance 확인
            expect(await myPermitToken.allowance(owner.address, spender.address))
                .to.equal(value - transferAmount);

            // 추가 전송 가능
            await myPermitToken.connect(spender).transferFrom(owner.address, receiver.address, transferAmount);

            expect(await myPermitToken.allowance(owner.address, spender.address))
                .to.equal(value - transferAmount * 2n);
        });

        it("Permit으로 설정한 allowance를 초과하여 transferFrom 시 실패해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            // 허용량 초과 전송 시도
            await expect(
                myPermitToken.connect(spender).transferFrom(
                    owner.address,
                    receiver.address,
                    value + ethers.parseEther("1")
                )
            ).to.be.reverted;
        });

        it("Permit 후 approve로 allowance를 변경할 수 있어야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);

            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(value);

            // approve로 변경
            const newValue = ethers.parseEther("200");
            await myPermitToken.connect(owner).approve(spender.address, newValue);

            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(newValue);
        });
    });

    describe("6. EIP-712 Domain Separator 테스트", function () {
        it("Domain Separator가 올바르게 계산되어야 함", async function () {
            const tokenAddress = await manualPermitToken.getAddress();
            const domainSeparator = await manualPermitToken.getDomainSeparator();

            // 수동으로 계산한 Domain Separator와 비교
            const expectedDomainSeparator = ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                    ["bytes32", "bytes32", "bytes32", "uint256", "address"],
                    [
                        ethers.keccak256(ethers.toUtf8Bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")),
                        ethers.keccak256(ethers.toUtf8Bytes("Manual Permit Token")),
                        ethers.keccak256(ethers.toUtf8Bytes("1")),
                        chainId,
                        tokenAddress
                    ]
                )
            );

            expect(domainSeparator).to.equal(expectedDomainSeparator);
        });

        it("PERMIT_TYPEHASH가 EIP-2612 표준을 따라야 함", async function () {
            const permitTypehash = await manualPermitToken.PERMIT_TYPEHASH();
            const expectedTypehash = ethers.keccak256(
                ethers.toUtf8Bytes("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
            );

            expect(permitTypehash).to.equal(expectedTypehash);
        });
    });

    describe("7. 엣지 케이스 및 보안 테스트", function () {
        it("value가 0인 permit도 정상 동작해야 함", async function () {
            const value = 0n;
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await expect(
                myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.not.be.reverted;

            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(0);
        });

        it("매우 큰 value로 permit 실행이 가능해야 함", async function () {
            const value = ethers.MaxUint256;
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            await expect(
                myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s)
            ).to.not.be.reverted;

            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(ethers.MaxUint256);
        });

        it("여러 spender에게 동시에 permit을 발급할 수 있어야 함", async function () {
            const value = ethers.parseEther("100");
            const deadline = (await time.latest()) + 3600;

            // 첫 번째 spender
            let nonce = await myPermitToken.nonces(owner.address);
            let sig = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );
            await myPermitToken.permit(owner.address, spender.address, value, deadline, sig.v, sig.r, sig.s);

            // 두 번째 spender
            nonce = await myPermitToken.nonces(owner.address);
            sig = await signPermit(
                myPermitToken,
                owner.address,
                receiver.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );
            await myPermitToken.permit(owner.address, receiver.address, value, deadline, sig.v, sig.r, sig.s);

            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(value);
            expect(await myPermitToken.allowance(owner.address, receiver.address)).to.equal(value);
        });

        it("동일한 owner와 spender에 대해 여러 번 permit 실행 가능", async function () {
            const value1 = ethers.parseEther("100");
            const value2 = ethers.parseEther("200");
            const deadline = (await time.latest()) + 3600;

            // 첫 번째 permit
            let nonce = await myPermitToken.nonces(owner.address);
            let sig = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value1,
                nonce,
                deadline,
                ownerPrivateKey
            );
            await myPermitToken.permit(owner.address, spender.address, value1, deadline, sig.v, sig.r, sig.s);
            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(value1);

            // 두 번째 permit (덮어쓰기)
            nonce = await myPermitToken.nonces(owner.address);
            sig = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value2,
                nonce,
                deadline,
                ownerPrivateKey
            );
            await myPermitToken.permit(owner.address, spender.address, value2, deadline, sig.v, sig.r, sig.s);
            expect(await myPermitToken.allowance(owner.address, spender.address)).to.equal(value2);
        });
    });

    describe("8. 가스 사용량 테스트", function () {
        it("Permit의 가스 사용량을 측정해야 함", async function () {
            const value = ethers.parseEther("100");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                spender.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            const tx = await myPermitToken.permit(owner.address, spender.address, value, deadline, v, r, s);
            const receipt = await tx.wait();

            console.log("        Permit 가스 사용량:", receipt.gasUsed.toString());

            // 일반적으로 permit은 70,000 ~ 80,000 가스 정도 사용
            expect(receipt.gasUsed).to.be.lessThan(100000n);
        });

        it("approve + transferFrom vs permit + transferFrom 가스 비교", async function () {
            const value = ethers.parseEther("100");

            // approve 방식
            const approveTx = await myPermitToken.connect(owner).approve(spender.address, value);
            const approveReceipt = await approveTx.wait();
            const transferTx1 = await myPermitToken.connect(spender).transferFrom(
                owner.address,
                receiver.address,
                value
            );
            const transferReceipt1 = await transferTx1.wait();
            const approveGas = approveReceipt.gasUsed + transferReceipt1.gasUsed;

            // permit 방식
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;
            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                receiver.address,
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            const permitTx = await myPermitToken.permit(owner.address, receiver.address, value, deadline, v, r, s);
            const permitReceipt = await permitTx.wait();
            const transferTx2 = await myPermitToken.connect(receiver).transferFrom(
                owner.address,
                attacker.address,
                value
            );
            const transferReceipt2 = await transferTx2.wait();
            const permitGas = permitReceipt.gasUsed + transferReceipt2.gasUsed;

            console.log("        approve + transferFrom 가스:", approveGas.toString());
            console.log("        permit + transferFrom 가스:", permitGas.toString());

            // permit 방식이 약간 더 많은 가스를 사용하지만, 오프체인 서명으로 사용자 경험 개선
        });
    });

    describe("9. DApp 통합 시나리오 테스트", function () {
        let dappContract;

        beforeEach(async function () {
            const DAppWithPermit = await ethers.getContractFactory("DAppWithPermit");
            dappContract = await DAppWithPermit.deploy();
            await dappContract.waitForDeployment();
        });

        it("DApp에서 permit을 사용하여 단일 트랜잭션으로 승인 및 실행", async function () {
            const value = ethers.parseEther("100");
            const nonce = await myPermitToken.nonces(owner.address);
            const deadline = (await time.latest()) + 3600;

            const { v, r, s } = await signPermit(
                myPermitToken,
                owner.address,
                await dappContract.getAddress(),
                value,
                nonce,
                deadline,
                ownerPrivateKey
            );

            // DApp 컨트랙트가 permit과 transferFrom을 한 번에 실행
            const balanceBefore = await myPermitToken.balanceOf(await dappContract.getAddress());

            await dappContract.depositWithPermit(
                await myPermitToken.getAddress(),
                owner.address,
                value,
                deadline,
                v,
                r,
                s
            );

            const balanceAfter = await myPermitToken.balanceOf(await dappContract.getAddress());
            expect(balanceAfter - balanceBefore).to.equal(value);
        });
    });
});
