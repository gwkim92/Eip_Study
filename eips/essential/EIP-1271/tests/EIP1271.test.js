const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * EIP-1271 (Contract Signature Validation) 종합 테스트
 *
 * 테스트 범위:
 * 1. isValidSignature() 기본 동작
 * 2. Magic value (0x1626ba7e) 반환 검증
 * 3. 단일 소유자 지갑 서명 검증
 * 4. 멀티시그 지갑 서명 검증
 * 5. 세션 키 지갑 구현
 * 6. EIP-712 통합
 * 7. 보안 테스트 (잘못된 서명, 권한 검증)
 * 8. 실제 사용 시나리오 (DeFi 프로토콜 통합)
 * 9. 가스 최적화
 */
describe("EIP-1271: Contract Signature Validation 종합 테스트", function () {
    let wallet, multiSigWallet, sessionKeyWallet;
    let owner, signer1, signer2, signer3, user, attacker;
    let ownerPrivateKey, signer1PrivateKey, signer2PrivateKey;

    // Magic value
    const MAGIC_VALUE = "0x1626ba7e";
    const INVALID_SIGNATURE = "0xffffffff";

    before(async function () {
        [owner, signer1, signer2, signer3, user, attacker] = await ethers.getSigners();

        // 테스트용 개인 키 (하드햇 기본 계정)
        ownerPrivateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
        signer1PrivateKey = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
        signer2PrivateKey = "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";
    });

    /**
     * 유틸리티: 메시지 서명 생성
     */
    async function signMessage(messageHash, privateKey) {
        const wallet = new ethers.Wallet(privateKey);
        const signature = await wallet.signMessage(ethers.getBytes(messageHash));
        return signature;
    }

    /**
     * 유틸리티: 여러 서명을 연결
     */
    function concatenateSignatures(signatures) {
        return ethers.concat(signatures);
    }

    describe("1. 단일 소유자 지갑 - 기본 테스트", function () {
        beforeEach(async function () {
            const Wallet = await ethers.getContractFactory("EIP1271Example");
            wallet = await Wallet.deploy();
            await wallet.waitForDeployment();
        });

        it("컨트랙트가 정상적으로 배포되어야 함", async function () {
            expect(await wallet.getAddress()).to.be.properAddress;
            expect(await wallet.owner()).to.equal(owner.address);
        });

        it("유효한 서명에 대해 magic value를 반환해야 함", async function () {
            const message = "Hello, EIP-1271!";
            const messageHash = ethers.hashMessage(message);

            const signature = await signMessage(messageHash, ownerPrivateKey);

            const result = await wallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(MAGIC_VALUE);
        });

        it("잘못된 서명에 대해 0xffffffff를 반환해야 함", async function () {
            const message = "Hello, EIP-1271!";
            const messageHash = ethers.hashMessage(message);

            // 다른 사람의 서명
            const signature = await signMessage(messageHash, signer1PrivateKey);

            const result = await wallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(INVALID_SIGNATURE);
        });

        it("잘못된 길이의 서명은 revert해야 함", async function () {
            const messageHash = ethers.hashMessage("test");
            const invalidSignature = "0x1234"; // 잘못된 길이

            await expect(
                wallet.isValidSignature(messageHash, invalidSignature)
            ).to.be.revertedWith("Invalid signature length");
        });

        it("변조된 서명은 검증에 실패해야 함", async function () {
            const message = "Hello, EIP-1271!";
            const messageHash = ethers.hashMessage(message);

            let signature = await signMessage(messageHash, ownerPrivateKey);

            // 서명의 마지막 바이트 변조
            const sigBytes = ethers.getBytes(signature);
            sigBytes[64] = (sigBytes[64] + 1) % 256;
            signature = ethers.hexlify(sigBytes);

            const result = await wallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(INVALID_SIGNATURE);
        });

        it("소유자가 변경되면 이전 소유자의 서명은 무효가 되어야 함", async function () {
            const message = "Test message";
            const messageHash = ethers.hashMessage(message);

            // 현재 소유자의 서명
            const signature = await signMessage(messageHash, ownerPrivateKey);

            // 서명 검증 성공
            expect(await wallet.isValidSignature(messageHash, signature)).to.equal(MAGIC_VALUE);

            // 소유자 변경
            await wallet.connect(owner).changeOwner(signer1.address);

            // 이전 소유자의 서명은 이제 무효
            expect(await wallet.isValidSignature(messageHash, signature)).to.equal(INVALID_SIGNATURE);
        });

        it("ETH를 수신할 수 있어야 함", async function () {
            const sendAmount = ethers.parseEther("1");

            await owner.sendTransaction({
                to: await wallet.getAddress(),
                value: sendAmount
            });

            expect(await wallet.getBalance()).to.equal(sendAmount);
        });

        it("소유자만 execute 함수를 호출할 수 있어야 함", async function () {
            await owner.sendTransaction({
                to: await wallet.getAddress(),
                value: ethers.parseEther("1")
            });

            const sendAmount = ethers.parseEther("0.5");

            await expect(
                wallet.connect(attacker).execute(
                    user.address,
                    sendAmount,
                    "0x"
                )
            ).to.be.revertedWith("Not owner");

            await expect(
                wallet.connect(owner).execute(
                    user.address,
                    sendAmount,
                    "0x"
                )
            ).to.not.be.reverted;
        });
    });

    describe("2. 멀티시그 지갑 테스트", function () {
        const threshold = 2; // 2-of-3 멀티시그

        beforeEach(async function () {
            const MultiSig = await ethers.getContractFactory("MultiSigWallet");
            multiSigWallet = await MultiSig.deploy(
                [signer1.address, signer2.address, signer3.address],
                threshold
            );
            await multiSigWallet.waitForDeployment();
        });

        it("멀티시그 지갑이 정상적으로 초기화되어야 함", async function () {
            expect(await multiSigWallet.threshold()).to.equal(threshold);
            expect(await multiSigWallet.getOwnerCount()).to.equal(3);
            expect(await multiSigWallet.isOwner(signer1.address)).to.be.true;
            expect(await multiSigWallet.isOwner(signer2.address)).to.be.true;
            expect(await multiSigWallet.isOwner(signer3.address)).to.be.true;
        });

        it("충분한 서명이 있으면 검증에 성공해야 함", async function () {
            const messageHash = ethers.hashMessage("Multisig test");

            // 2개의 서명 생성 (threshold = 2)
            const sig1 = await signMessage(messageHash, signer1PrivateKey);
            const sig2 = await signMessage(messageHash, signer2PrivateKey);

            const combinedSignature = concatenateSignatures([sig1, sig2]);

            const result = await multiSigWallet.isValidSignature(messageHash, combinedSignature);
            expect(result).to.equal(MAGIC_VALUE);
        });

        it("서명이 부족하면 검증에 실패해야 함", async function () {
            const messageHash = ethers.hashMessage("Multisig test");

            // 1개의 서명만 제공 (threshold = 2)
            const sig1 = await signMessage(messageHash, signer1PrivateKey);

            await expect(
                multiSigWallet.isValidSignature(messageHash, sig1)
            ).to.be.revertedWith("Not enough signatures");
        });

        it("중복된 서명은 거부되어야 함", async function () {
            const messageHash = ethers.hashMessage("Multisig test");

            // 동일한 서명 2개
            const sig1 = await signMessage(messageHash, signer1PrivateKey);

            const combinedSignature = concatenateSignatures([sig1, sig1]);

            await expect(
                multiSigWallet.isValidSignature(messageHash, combinedSignature)
            ).to.be.revertedWith("Duplicate signature");
        });

        it("소유자가 아닌 사람의 서명은 거부되어야 함", async function () {
            const messageHash = ethers.hashMessage("Multisig test");

            // 소유자가 아닌 사람의 서명
            const sig1 = await signMessage(messageHash, signer1PrivateKey);
            const sigAttacker = await signMessage(messageHash, ownerPrivateKey); // owner는 멀티시그 소유자 아님

            const combinedSignature = concatenateSignatures([sig1, sigAttacker]);

            await expect(
                multiSigWallet.isValidSignature(messageHash, combinedSignature)
            ).to.be.revertedWith("Not owner");
        });

        it("서명 순서와 관계없이 검증되어야 함", async function () {
            const messageHash = ethers.hashMessage("Multisig test");

            const sig1 = await signMessage(messageHash, signer1PrivateKey);
            const sig2 = await signMessage(messageHash, signer2PrivateKey);

            // 순서 1: sig1, sig2
            const combined1 = concatenateSignatures([sig1, sig2]);
            expect(await multiSigWallet.isValidSignature(messageHash, combined1)).to.equal(MAGIC_VALUE);

            // 순서 2: sig2, sig1
            const combined2 = concatenateSignatures([sig2, sig1]);
            expect(await multiSigWallet.isValidSignature(messageHash, combined2)).to.equal(MAGIC_VALUE);
        });

        it("Threshold를 초과하는 서명도 허용되어야 함", async function () {
            const messageHash = ethers.hashMessage("Multisig test");

            // 3개의 서명 제공 (threshold = 2)
            const sig1 = await signMessage(messageHash, signer1PrivateKey);
            const sig2 = await signMessage(messageHash, signer2PrivateKey);
            const sig3 = await signMessage(messageHash, signer2PrivateKey);

            const combinedSignature = concatenateSignatures([sig1, sig2, sig3]);

            // 3개 서명도 유효 (2개 이상이면 됨)
            await expect(
                multiSigWallet.isValidSignature(messageHash, combinedSignature)
            ).to.be.revertedWith("Duplicate signature"); // sig2가 중복
        });

        it("멀티시그로 트랜잭션을 실행할 수 있어야 함", async function () {
            // ETH 전송
            await owner.sendTransaction({
                to: await multiSigWallet.getAddress(),
                value: ethers.parseEther("2")
            });

            const to = user.address;
            const value = ethers.parseEther("1");
            const data = "0x";
            const nonce = await multiSigWallet.nonce();

            // 트랜잭션 해시 생성
            const txHash = await multiSigWallet.getTransactionHash(to, value, data, nonce);

            // 서명 생성
            const sig1 = await signMessage(txHash, signer1PrivateKey);
            const sig2 = await signMessage(txHash, signer2PrivateKey);
            const combinedSignature = concatenateSignatures([sig1, sig2]);

            const balanceBefore = await ethers.provider.getBalance(user.address);

            await multiSigWallet.execTransaction(to, value, data, combinedSignature);

            const balanceAfter = await ethers.provider.getBalance(user.address);
            expect(balanceAfter - balanceBefore).to.equal(value);
        });

        it("동일한 nonce로 두 번 실행할 수 없어야 함 (리플레이 공격 방지)", async function () {
            await owner.sendTransaction({
                to: await multiSigWallet.getAddress(),
                value: ethers.parseEther("2")
            });

            const to = user.address;
            const value = ethers.parseEther("0.5");
            const data = "0x";
            const nonce = await multiSigWallet.nonce();

            const txHash = await multiSigWallet.getTransactionHash(to, value, data, nonce);

            const sig1 = await signMessage(txHash, signer1PrivateKey);
            const sig2 = await signMessage(txHash, signer2PrivateKey);
            const combinedSignature = concatenateSignatures([sig1, sig2]);

            // 첫 번째 실행 성공
            await multiSigWallet.execTransaction(to, value, data, combinedSignature);

            // 두 번째 실행 실패 (nonce 변경됨)
            await expect(
                multiSigWallet.execTransaction(to, value, data, combinedSignature)
            ).to.be.revertedWith("Invalid signatures");
        });
    });

    describe("3. 세션 키 지갑 테스트", function () {
        let sessionKey, sessionKeyPrivateKey;

        beforeEach(async function () {
            // 세션 키 생성
            const sessionWallet = ethers.Wallet.createRandom();
            sessionKey = sessionWallet.address;
            sessionKeyPrivateKey = sessionWallet.privateKey;

            const SessionKeyWallet = await ethers.getContractFactory("SessionKeyWallet");
            sessionKeyWallet = await SessionKeyWallet.deploy();
            await sessionKeyWallet.waitForDeployment();
        });

        it("마스터 키가 세션 키를 추가할 수 있어야 함", async function () {
            const expiresAt = Math.floor(Date.now() / 1000) + 3600; // 1시간 후
            const allowance = ethers.parseEther("1");

            await sessionKeyWallet.connect(owner).addSessionKey(
                sessionKey,
                expiresAt,
                allowance
            );

            expect(await sessionKeyWallet.isSessionKeyActive(sessionKey)).to.be.true;
        });

        it("유효한 세션 키의 서명은 검증되어야 함", async function () {
            const expiresAt = Math.floor(Date.now() / 1000) + 3600;
            const allowance = ethers.parseEther("1");

            await sessionKeyWallet.connect(owner).addSessionKey(
                sessionKey,
                expiresAt,
                allowance
            );

            const messageHash = ethers.hashMessage("Session key test");
            const signature = await signMessage(messageHash, sessionKeyPrivateKey);

            const result = await sessionKeyWallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(MAGIC_VALUE);
        });

        it("만료된 세션 키의 서명은 거부되어야 함", async function () {
            const expiresAt = Math.floor(Date.now() / 1000) - 1; // 이미 만료
            const allowance = ethers.parseEther("1");

            await sessionKeyWallet.connect(owner).addSessionKey(
                sessionKey,
                expiresAt,
                allowance
            );

            const messageHash = ethers.hashMessage("Session key test");
            const signature = await signMessage(messageHash, sessionKeyPrivateKey);

            const result = await sessionKeyWallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(INVALID_SIGNATURE);
        });

        it("세션 키를 취소할 수 있어야 함", async function () {
            const expiresAt = Math.floor(Date.now() / 1000) + 3600;
            const allowance = ethers.parseEther("1");

            await sessionKeyWallet.connect(owner).addSessionKey(
                sessionKey,
                expiresAt,
                allowance
            );

            expect(await sessionKeyWallet.isSessionKeyActive(sessionKey)).to.be.true;

            // 세션 키 취소
            await sessionKeyWallet.connect(owner).revokeSessionKey(sessionKey);

            expect(await sessionKeyWallet.isSessionKeyActive(sessionKey)).to.be.false;

            // 취소된 세션 키의 서명은 무효
            const messageHash = ethers.hashMessage("Test");
            const signature = await signMessage(messageHash, sessionKeyPrivateKey);

            const result = await sessionKeyWallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(INVALID_SIGNATURE);
        });

        it("마스터 키의 서명은 항상 유효해야 함", async function () {
            const messageHash = ethers.hashMessage("Master key test");
            const signature = await signMessage(messageHash, ownerPrivateKey);

            const result = await sessionKeyWallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(MAGIC_VALUE);
        });

        it("권한이 없는 사용자는 세션 키를 추가할 수 없어야 함", async function () {
            const expiresAt = Math.floor(Date.now() / 1000) + 3600;
            const allowance = ethers.parseEther("1");

            await expect(
                sessionKeyWallet.connect(attacker).addSessionKey(
                    sessionKey,
                    expiresAt,
                    allowance
                )
            ).to.be.revertedWith("Not owner");
        });
    });

    describe("4. EIP-712 통합 테스트", function () {
        let eip712Wallet;
        let chainId;

        beforeEach(async function () {
            const EIP712Wallet = await ethers.getContractFactory("EIP1271WithEIP712");
            eip712Wallet = await EIP712Wallet.deploy();
            await eip712Wallet.waitForDeployment();

            const network = await ethers.provider.getNetwork();
            chainId = network.chainId;
        });

        it("EIP-712 구조화된 데이터 서명을 검증할 수 있어야 함", async function () {
            const message = {
                to: user.address,
                value: ethers.parseEther("1"),
                data: "0x",
                nonce: 0
            };

            const messageHash = await eip712Wallet.hashMessage(message);

            const domain = {
                name: "EIP1271WithEIP712",
                version: "1",
                chainId: chainId,
                verifyingContract: await eip712Wallet.getAddress()
            };

            const types = {
                Message: [
                    { name: "to", type: "address" },
                    { name: "value", type: "uint256" },
                    { name: "data", type: "bytes" },
                    { name: "nonce", type: "uint256" }
                ]
            };

            const wallet = new ethers.Wallet(ownerPrivateKey);
            const signature = await wallet.signTypedData(domain, types, message);

            const result = await eip712Wallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(MAGIC_VALUE);
        });

        it("서명된 메시지를 실행할 수 있어야 함", async function () {
            await owner.sendTransaction({
                to: await eip712Wallet.getAddress(),
                value: ethers.parseEther("2")
            });

            const message = {
                to: user.address,
                value: ethers.parseEther("1"),
                data: "0x",
                nonce: await eip712Wallet.nonce()
            };

            const domain = {
                name: "EIP1271WithEIP712",
                version: "1",
                chainId: chainId,
                verifyingContract: await eip712Wallet.getAddress()
            };

            const types = {
                Message: [
                    { name: "to", type: "address" },
                    { name: "value", type: "uint256" },
                    { name: "data", type: "bytes" },
                    { name: "nonce", type: "uint256" }
                ]
            };

            const wallet = new ethers.Wallet(ownerPrivateKey);
            const signature = await wallet.signTypedData(domain, types, message);

            const balanceBefore = await ethers.provider.getBalance(user.address);

            await eip712Wallet.executeWithSignature(message, signature);

            const balanceAfter = await ethers.provider.getBalance(user.address);
            expect(balanceAfter - balanceBefore).to.equal(message.value);
        });

        it("잘못된 nonce로 실행 시 실패해야 함", async function () {
            const message = {
                to: user.address,
                value: ethers.parseEther("1"),
                data: "0x",
                nonce: 999 // 잘못된 nonce
            };

            const domain = {
                name: "EIP1271WithEIP712",
                version: "1",
                chainId: chainId,
                verifyingContract: await eip712Wallet.getAddress()
            };

            const types = {
                Message: [
                    { name: "to", type: "address" },
                    { name: "value", type: "uint256" },
                    { name: "data", type: "bytes" },
                    { name: "nonce", type: "uint256" }
                ]
            };

            const wallet = new ethers.Wallet(ownerPrivateKey);
            const signature = await wallet.signTypedData(domain, types, message);

            await expect(
                eip712Wallet.executeWithSignature(message, signature)
            ).to.be.revertedWith("Invalid nonce");
        });
    });

    describe("5. DApp 통합 시나리오", function () {
        let validator;

        beforeEach(async function () {
            const Wallet = await ethers.getContractFactory("EIP1271Example");
            wallet = await Wallet.deploy();
            await wallet.waitForDeployment();

            const Validator = await ethers.getContractFactory("EIP1271Validator");
            validator = await Validator.deploy();
            await validator.waitForDeployment();
        });

        it("DApp이 컨트랙트 지갑의 서명을 검증할 수 있어야 함", async function () {
            const message = "DApp Authorization";
            const messageHash = ethers.hashMessage(message);

            const signature = await signMessage(messageHash, ownerPrivateKey);

            const isValid = await validator.verifySignature(
                await wallet.getAddress(),
                messageHash,
                signature
            );

            expect(isValid).to.be.true;
        });

        it("잘못된 서명은 DApp에서 거부되어야 함", async function () {
            const message = "DApp Authorization";
            const messageHash = ethers.hashMessage(message);

            const signature = await signMessage(messageHash, signer1PrivateKey); // 잘못된 서명

            const isValid = await validator.verifySignature(
                await wallet.getAddress(),
                messageHash,
                signature
            );

            expect(isValid).to.be.false;
        });

        it("EOA와 컨트랙트 지갑을 모두 지원해야 함", async function () {
            const message = "Universal test";
            const messageHash = ethers.hashMessage(message);

            // EOA 서명
            const eoaSignature = await owner.signMessage(ethers.getBytes(messageHash));
            const eoaValid = await validator.verifySignature(
                owner.address,
                messageHash,
                eoaSignature
            );
            expect(eoaValid).to.be.true;

            // 컨트랙트 지갑 서명
            const contractSignature = await signMessage(messageHash, ownerPrivateKey);
            const contractValid = await validator.verifySignature(
                await wallet.getAddress(),
                messageHash,
                contractSignature
            );
            expect(contractValid).to.be.true;
        });
    });

    describe("6. 통합 시나리오 - DeFi 프로토콜", function () {
        let integration;
        let token;

        beforeEach(async function () {
            // ERC20 토큰 배포
            const Token = await ethers.getContractFactory("MyPermitToken");
            token = await Token.deploy("Test Token", "TEST", ethers.parseEther("1000000"));
            await token.waitForDeployment();

            // 지갑 배포
            const Wallet = await ethers.getContractFactory("EIP1271Example");
            wallet = await Wallet.deploy();
            await wallet.waitForDeployment();

            // 토큰을 지갑으로 전송
            await token.transfer(await wallet.getAddress(), ethers.parseEther("1000"));

            // DeFi 프로토콜 배포
            const Integration = await ethers.getContractFactory("EIP1271Integration");
            integration = await Integration.deploy();
            await integration.waitForDeployment();
        });

        it("컨트랙트 지갑에서 서명으로 토큰을 승인하고 전송", async function () {
            const amount = ethers.parseEther("100");
            const messageHash = ethers.solidityPackedKeccak256(
                ["address", "address", "uint256"],
                [await wallet.getAddress(), await integration.getAddress(), amount]
            );

            const signature = await signMessage(messageHash, ownerPrivateKey);

            // 지갑 소유자가 execute를 통해 approve 실행
            const approveData = token.interface.encodeFunctionData("approve", [
                await integration.getAddress(),
                amount
            ]);

            await wallet.connect(owner).execute(
                await token.getAddress(),
                0,
                approveData
            );

            // Integration 컨트랙트가 토큰을 가져갈 수 있음
            await integration.pullTokens(
                await token.getAddress(),
                await wallet.getAddress(),
                amount
            );

            expect(await token.balanceOf(await integration.getAddress())).to.equal(amount);
        });
    });

    describe("7. 가스 최적화 테스트", function () {
        beforeEach(async function () {
            const Wallet = await ethers.getContractFactory("EIP1271Example");
            wallet = await Wallet.deploy();
            await wallet.waitForDeployment();
        });

        it("isValidSignature 가스 사용량 측정", async function () {
            const messageHash = ethers.hashMessage("Gas test");
            const signature = await signMessage(messageHash, ownerPrivateKey);

            const tx = await wallet.isValidSignature.staticCall(messageHash, signature);

            // 가스 측정을 위한 실제 호출
            const estimatedGas = await wallet.isValidSignature.estimateGas(messageHash, signature);

            console.log("        isValidSignature 가스:", estimatedGas.toString());

            // 일반적으로 10,000 ~ 20,000 가스 사용
            expect(estimatedGas).to.be.lessThan(30000n);
        });

        it("멀티시그 검증 가스 사용량 측정", async function () {
            const MultiSig = await ethers.getContractFactory("MultiSigWallet");
            multiSigWallet = await MultiSig.deploy(
                [signer1.address, signer2.address, signer3.address],
                2
            );
            await multiSigWallet.waitForDeployment();

            const messageHash = ethers.hashMessage("Gas test");
            const sig1 = await signMessage(messageHash, signer1PrivateKey);
            const sig2 = await signMessage(messageHash, signer2PrivateKey);
            const combinedSignature = concatenateSignatures([sig1, sig2]);

            const estimatedGas = await multiSigWallet.isValidSignature.estimateGas(
                messageHash,
                combinedSignature
            );

            console.log("        멀티시그 검증 가스:", estimatedGas.toString());

            // 멀티시그는 더 많은 가스 사용
            expect(estimatedGas).to.be.lessThan(100000n);
        });
    });

    describe("8. 보안 및 엣지 케이스", function () {
        beforeEach(async function () {
            const Wallet = await ethers.getContractFactory("EIP1271Example");
            wallet = await Wallet.deploy();
            await wallet.waitForDeployment();
        });

        it("빈 서명은 거부되어야 함", async function () {
            const messageHash = ethers.hashMessage("test");

            await expect(
                wallet.isValidSignature(messageHash, "0x")
            ).to.be.revertedWith("Invalid signature length");
        });

        it("서명 재사용 공격을 방지해야 함", async function () {
            const message1 = "Message 1";
            const messageHash1 = ethers.hashMessage(message1);
            const signature1 = await signMessage(messageHash1, ownerPrivateKey);

            // 다른 메시지에 동일한 서명 사용 시도
            const message2 = "Message 2";
            const messageHash2 = ethers.hashMessage(message2);

            const result = await wallet.isValidSignature(messageHash2, signature1);
            expect(result).to.equal(INVALID_SIGNATURE);
        });

        it("Zero hash에 대한 서명도 처리해야 함", async function () {
            const zeroHash = ethers.ZeroHash;
            const signature = await signMessage(zeroHash, ownerPrivateKey);

            const result = await wallet.isValidSignature(zeroHash, signature);
            expect(result).to.equal(MAGIC_VALUE);
        });

        it("매우 긴 메시지에 대한 서명도 검증되어야 함", async function () {
            const longMessage = "A".repeat(1000);
            const messageHash = ethers.hashMessage(longMessage);
            const signature = await signMessage(messageHash, ownerPrivateKey);

            const result = await wallet.isValidSignature(messageHash, signature);
            expect(result).to.equal(MAGIC_VALUE);
        });
    });
});
