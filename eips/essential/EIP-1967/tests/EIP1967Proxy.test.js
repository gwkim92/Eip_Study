const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * EIP-1967 (Proxy Storage Slots) 종합 테스트
 *
 * 테스트 범위:
 * 1. 프록시 배포 및 초기화
 * 2. 구현 컨트랙트 업그레이드 (upgradeTo, upgradeToAndCall)
 * 3. 스토리지 슬롯 검증 (IMPLEMENTATION_SLOT, ADMIN_SLOT)
 * 4. delegatecall 동작 확인
 * 5. 관리자 권한 관리 (changeAdmin)
 * 6. 스토리지 충돌 방지
 * 7. 업그레이드 시나리오 (V1 → V2 → V3)
 * 8. 보안 테스트 (권한 검증, 잘못된 업그레이드)
 * 9. 가스 최적화 측정
 */
describe("EIP-1967: Proxy Storage Slots 종합 테스트", function () {
    let proxy;
    let logicV1, logicV2;
    let owner, admin, user, attacker;

    // EIP-1967 표준 스토리지 슬롯
    const IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
    const ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

    before(async function () {
        [owner, admin, user, attacker] = await ethers.getSigners();
    });

    beforeEach(async function () {
        // LogicV1 배포
        const LogicV1 = await ethers.getContractFactory("LogicV1");
        logicV1 = await LogicV1.deploy();
        await logicV1.waitForDeployment();

        // LogicV2 배포
        const LogicV2 = await ethers.getContractFactory("LogicV2");
        logicV2 = await LogicV2.deploy();
        await logicV2.waitForDeployment();
    });

    describe("1. 프록시 배포 및 초기화", function () {
        it("프록시가 정상적으로 배포되어야 함", async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();

            expect(await proxy.getAddress()).to.be.properAddress;
        });

        it("초기화 데이터가 없는 프록시 배포가 가능해야 함", async function () {
            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                "0x"
            );
            await proxy.waitForDeployment();

            expect(await proxy.getAddress()).to.be.properAddress;
        });

        it("프록시 배포 시 Upgraded 이벤트가 발생해야 함", async function () {
            const Proxy = await ethers.getContractFactory("EIP1967Proxy");

            await expect(
                Proxy.deploy(
                    await logicV1.getAddress(),
                    admin.address,
                    "0x"
                )
            ).to.emit(Proxy, "Upgraded").withArgs(await logicV1.getAddress());
        });

        it("프록시 배포 시 AdminChanged 이벤트가 발생해야 함", async function () {
            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            const deployment = Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                "0x"
            );

            await expect(deployment)
                .to.emit(Proxy, "AdminChanged")
                .withArgs(ethers.ZeroAddress, admin.address);
        });

        it("구현 컨트랙트가 아닌 주소로 배포 시 실패해야 함", async function () {
            const Proxy = await ethers.getContractFactory("EIP1967Proxy");

            await expect(
                Proxy.deploy(
                    user.address, // EOA 주소
                    admin.address,
                    "0x"
                )
            ).to.be.revertedWith("EIP1967Proxy: implementation is not a contract");
        });

        it("프록시를 통해 초기화 함수가 정상 실행되어야 함", async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();

            // LogicV1 인터페이스로 프록시에 접근
            const proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());

            expect(await proxiedLogic.owner()).to.equal(owner.address);
            expect(await proxiedLogic.name()).to.equal("Counter V1");
            expect(await proxiedLogic.counter()).to.equal(0);
        });
    });

    describe("2. 스토리지 슬롯 검증", function () {
        beforeEach(async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();
        });

        it("IMPLEMENTATION_SLOT에 구현 컨트랙트 주소가 저장되어야 함", async function () {
            const implementationAddress = await ethers.provider.getStorage(
                await proxy.getAddress(),
                IMPLEMENTATION_SLOT
            );

            // 주소를 20바이트로 변환 (왼쪽 12바이트 제거)
            const storedAddress = "0x" + implementationAddress.slice(-40);

            expect(storedAddress.toLowerCase()).to.equal(
                (await logicV1.getAddress()).toLowerCase()
            );
        });

        it("ADMIN_SLOT에 관리자 주소가 저장되어야 함", async function () {
            const adminAddress = await ethers.provider.getStorage(
                await proxy.getAddress(),
                ADMIN_SLOT
            );

            const storedAddress = "0x" + adminAddress.slice(-40);

            expect(storedAddress.toLowerCase()).to.equal(
                admin.address.toLowerCase()
            );
        });

        it("implementation() 함수로 구현 주소를 조회할 수 있어야 함", async function () {
            expect(await proxy.implementation()).to.equal(await logicV1.getAddress());
        });

        it("admin() 함수로 관리자 주소를 조회할 수 있어야 함", async function () {
            expect(await proxy.admin()).to.equal(admin.address);
        });
    });

    describe("3. Delegatecall 동작 확인", function () {
        beforeEach(async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();
        });

        it("프록시를 통해 로직 함수를 호출할 수 있어야 함", async function () {
            const proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());

            expect(await proxiedLogic.counter()).to.equal(0);

            await proxiedLogic.increment();

            expect(await proxiedLogic.counter()).to.equal(1);
        });

        it("프록시의 스토리지에 데이터가 저장되어야 함", async function () {
            const proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());

            await proxiedLogic.increment();
            await proxiedLogic.increment();
            await proxiedLogic.increment();

            expect(await proxiedLogic.counter()).to.equal(3);

            // 프록시를 통해 접근한 카운터 값
            const proxyCounter = await proxiedLogic.counter();

            // 로직 컨트랙트 직접 접근 시 카운터는 0 (다른 스토리지)
            expect(await logicV1.counter()).to.equal(0);
            expect(proxyCounter).to.equal(3);
        });

        it("msg.sender가 원래 호출자로 유지되어야 함", async function () {
            const proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());

            // owner가 transferOwnership 호출
            await proxiedLogic.connect(owner).transferOwnership(user.address);

            expect(await proxiedLogic.owner()).to.equal(user.address);
        });

        it("프록시로 ETH를 전송할 수 있어야 함", async function () {
            const sendAmount = ethers.parseEther("1");

            await owner.sendTransaction({
                to: await proxy.getAddress(),
                value: sendAmount
            });

            const balance = await ethers.provider.getBalance(await proxy.getAddress());
            expect(balance).to.equal(sendAmount);
        });
    });

    describe("4. 구현 컨트랙트 업그레이드", function () {
        beforeEach(async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();

            // V1에서 카운터 증가
            const proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());
            await proxiedLogic.increment();
            await proxiedLogic.increment();
        });

        it("관리자가 upgradeTo로 구현을 업그레이드할 수 있어야 함", async function () {
            expect(await proxy.implementation()).to.equal(await logicV1.getAddress());

            await proxy.connect(admin).upgradeTo(await logicV2.getAddress());

            expect(await proxy.implementation()).to.equal(await logicV2.getAddress());
        });

        it("업그레이드 시 Upgraded 이벤트가 발생해야 함", async function () {
            await expect(
                proxy.connect(admin).upgradeTo(await logicV2.getAddress())
            ).to.emit(proxy, "Upgraded").withArgs(await logicV2.getAddress());
        });

        it("업그레이드 후 기존 스토리지가 유지되어야 함", async function () {
            const proxiedLogicV1 = await ethers.getContractAt("LogicV1", await proxy.getAddress());
            expect(await proxiedLogicV1.counter()).to.equal(2);

            await proxy.connect(admin).upgradeTo(await logicV2.getAddress());

            const proxiedLogicV2 = await ethers.getContractAt("LogicV2", await proxy.getAddress());
            expect(await proxiedLogicV2.counter()).to.equal(2); // 기존 값 유지
            expect(await proxiedLogicV2.owner()).to.equal(owner.address);
            expect(await proxiedLogicV2.name()).to.equal("Counter V1");
        });

        it("upgradeToAndCall로 업그레이드와 초기화를 동시에 실행", async function () {
            const initV2Data = logicV2.interface.encodeFunctionData("initializeV2", [10]);

            await proxy.connect(admin).upgradeToAndCall(
                await logicV2.getAddress(),
                initV2Data
            );

            const proxiedLogicV2 = await ethers.getContractAt("LogicV2", await proxy.getAddress());

            expect(await proxiedLogicV2.multiplier()).to.equal(10);
            expect(await proxiedLogicV2.counter()).to.equal(2); // 기존 값 유지
        });

        it("업그레이드 후 새로운 함수를 사용할 수 있어야 함", async function () {
            const initV2Data = logicV2.interface.encodeFunctionData("initializeV2", [5]);

            await proxy.connect(admin).upgradeToAndCall(
                await logicV2.getAddress(),
                initV2Data
            );

            const proxiedLogicV2 = await ethers.getContractAt("LogicV2", await proxy.getAddress());

            // V2의 새로운 함수 사용
            await proxiedLogicV2.incrementBy(3);

            // multiplier가 5이므로 3 * 5 = 15 증가
            expect(await proxiedLogicV2.counter()).to.equal(2 + 15);
        });

        it("업그레이드 후 버전 정보가 변경되어야 함", async function () {
            const proxiedLogicV1 = await ethers.getContractAt("LogicV1", await proxy.getAddress());
            expect(await proxiedLogicV1.version()).to.equal("1.0.0");

            await proxy.connect(admin).upgradeTo(await logicV2.getAddress());

            const proxiedLogicV2 = await ethers.getContractAt("LogicV2", await proxy.getAddress());
            expect(await proxiedLogicV2.version()).to.equal("2.0.0");
        });
    });

    describe("5. 관리자 권한 관리", function () {
        beforeEach(async function () {
            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                "0x"
            );
            await proxy.waitForDeployment();
        });

        it("관리자만 upgradeTo를 호출할 수 있어야 함", async function () {
            await expect(
                proxy.connect(user).upgradeTo(await logicV2.getAddress())
            ).to.be.revertedWith("EIP1967Proxy: caller is not admin");

            await expect(
                proxy.connect(attacker).upgradeTo(await logicV2.getAddress())
            ).to.be.revertedWith("EIP1967Proxy: caller is not admin");

            // 관리자는 가능
            await expect(
                proxy.connect(admin).upgradeTo(await logicV2.getAddress())
            ).to.not.be.reverted;
        });

        it("관리자만 upgradeToAndCall을 호출할 수 있어야 함", async function () {
            const initData = logicV2.interface.encodeFunctionData("initializeV2", [10]);

            await expect(
                proxy.connect(user).upgradeToAndCall(await logicV2.getAddress(), initData)
            ).to.be.revertedWith("EIP1967Proxy: caller is not admin");

            await expect(
                proxy.connect(admin).upgradeToAndCall(await logicV2.getAddress(), initData)
            ).to.not.be.reverted;
        });

        it("관리자가 changeAdmin으로 관리자를 변경할 수 있어야 함", async function () {
            expect(await proxy.admin()).to.equal(admin.address);

            await proxy.connect(admin).changeAdmin(user.address);

            expect(await proxy.admin()).to.equal(user.address);
        });

        it("changeAdmin 시 AdminChanged 이벤트가 발생해야 함", async function () {
            await expect(
                proxy.connect(admin).changeAdmin(user.address)
            ).to.emit(proxy, "AdminChanged").withArgs(admin.address, user.address);
        });

        it("관리자만 changeAdmin을 호출할 수 있어야 함", async function () {
            await expect(
                proxy.connect(user).changeAdmin(attacker.address)
            ).to.be.revertedWith("EIP1967Proxy: caller is not admin");

            await expect(
                proxy.connect(admin).changeAdmin(user.address)
            ).to.not.be.reverted;
        });

        it("Zero address로 관리자 변경 시 실패해야 함", async function () {
            await expect(
                proxy.connect(admin).changeAdmin(ethers.ZeroAddress)
            ).to.be.revertedWith("EIP1967Proxy: new admin is zero address");
        });

        it("새로운 관리자가 업그레이드 권한을 가져야 함", async function () {
            await proxy.connect(admin).changeAdmin(user.address);

            // 이전 관리자는 권한 없음
            await expect(
                proxy.connect(admin).upgradeTo(await logicV2.getAddress())
            ).to.be.revertedWith("EIP1967Proxy: caller is not admin");

            // 새 관리자는 권한 있음
            await expect(
                proxy.connect(user).upgradeTo(await logicV2.getAddress())
            ).to.not.be.reverted;
        });
    });

    describe("6. 보안 테스트", function () {
        beforeEach(async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();
        });

        it("구현이 아닌 주소로 업그레이드 시 실패해야 함", async function () {
            await expect(
                proxy.connect(admin).upgradeTo(user.address) // EOA
            ).to.be.revertedWith("EIP1967Proxy: implementation is not a contract");
        });

        it("Zero address로 업그레이드 시 실패해야 함", async function () {
            await expect(
                proxy.connect(admin).upgradeTo(ethers.ZeroAddress)
            ).to.be.revertedWith("EIP1967Proxy: implementation is not a contract");
        });

        it("upgradeToAndCall의 초기화 함수가 실패하면 업그레이드도 실패해야 함", async function () {
            // 잘못된 초기화 데이터
            const badInitData = "0x12345678";

            await expect(
                proxy.connect(admin).upgradeToAndCall(await logicV2.getAddress(), badInitData)
            ).to.be.revertedWith("EIP1967Proxy: upgrade call failed");

            // 업그레이드가 되지 않았는지 확인
            expect(await proxy.implementation()).to.equal(await logicV1.getAddress());
        });

        it("프록시를 통해 초기화를 두 번 호출할 수 없어야 함", async function () {
            const proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());

            await expect(
                proxiedLogic.initialize(attacker.address, "Hacked")
            ).to.be.revertedWith("LogicV1: already initialized");
        });

        it("악의적인 사용자가 프록시 관리 함수에 접근할 수 없어야 함", async function () {
            await expect(
                proxy.connect(attacker).upgradeTo(await logicV2.getAddress())
            ).to.be.revertedWith("EIP1967Proxy: caller is not admin");

            await expect(
                proxy.connect(attacker).changeAdmin(attacker.address)
            ).to.be.revertedWith("EIP1967Proxy: caller is not admin");
        });
    });

    describe("7. 스토리지 레이아웃 호환성 테스트", function () {
        beforeEach(async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();
        });

        it("V1에서 V2로 업그레이드 시 스토리지가 올바르게 유지되어야 함", async function () {
            const proxiedLogicV1 = await ethers.getContractAt("LogicV1", await proxy.getAddress());

            await proxiedLogicV1.increment();
            await proxiedLogicV1.increment();
            await proxiedLogicV1.increment();

            const counterV1 = await proxiedLogicV1.counter();
            const ownerV1 = await proxiedLogicV1.owner();
            const nameV1 = await proxiedLogicV1.name();

            // V2로 업그레이드
            const initV2Data = logicV2.interface.encodeFunctionData("initializeV2", [7]);
            await proxy.connect(admin).upgradeToAndCall(await logicV2.getAddress(), initV2Data);

            const proxiedLogicV2 = await ethers.getContractAt("LogicV2", await proxy.getAddress());

            // 기존 스토리지 확인
            expect(await proxiedLogicV2.counter()).to.equal(counterV1);
            expect(await proxiedLogicV2.owner()).to.equal(ownerV1);
            expect(await proxiedLogicV2.name()).to.equal(nameV1);

            // 새 변수 확인
            expect(await proxiedLogicV2.multiplier()).to.equal(7);
        });

        it("업그레이드 후 V1 함수와 V2 함수가 모두 동작해야 함", async function () {
            const initV2Data = logicV2.interface.encodeFunctionData("initializeV2", [2]);
            await proxy.connect(admin).upgradeToAndCall(await logicV2.getAddress(), initV2Data);

            const proxiedLogicV2 = await ethers.getContractAt("LogicV2", await proxy.getAddress());

            // V1 함수 (increment는 V2에서 multiplier 적용)
            await proxiedLogicV2.increment();
            expect(await proxiedLogicV2.counter()).to.equal(2);

            // V2 전용 함수
            await proxiedLogicV2.incrementBy(5);
            expect(await proxiedLogicV2.counter()).to.equal(2 + 10); // 5 * 2

            // V2 전용 함수
            await proxiedLogicV2.connect(owner).resetCounter();
            expect(await proxiedLogicV2.counter()).to.equal(0);
        });

        it("스토리지 슬롯이 변경되지 않아야 함", async function () {
            const implBefore = await ethers.provider.getStorage(
                await proxy.getAddress(),
                IMPLEMENTATION_SLOT
            );
            const adminBefore = await ethers.provider.getStorage(
                await proxy.getAddress(),
                ADMIN_SLOT
            );

            const proxiedLogicV1 = await ethers.getContractAt("LogicV1", await proxy.getAddress());
            await proxiedLogicV1.increment();

            // 로직 실행 후에도 프록시 스토리지 슬롯은 동일
            const implAfter = await ethers.provider.getStorage(
                await proxy.getAddress(),
                IMPLEMENTATION_SLOT
            );
            const adminAfter = await ethers.provider.getStorage(
                await proxy.getAddress(),
                ADMIN_SLOT
            );

            expect(implBefore).to.equal(implAfter);
            expect(adminBefore).to.equal(adminAfter);
        });
    });

    describe("8. 복잡한 업그레이드 시나리오", function () {
        it("여러 번 업그레이드를 수행할 수 있어야 함", async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();

            let proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());
            await proxiedLogic.increment();

            // V1 → V2
            const initV2Data = logicV2.interface.encodeFunctionData("initializeV2", [3]);
            await proxy.connect(admin).upgradeToAndCall(await logicV2.getAddress(), initV2Data);
            expect(await proxy.implementation()).to.equal(await logicV2.getAddress());

            proxiedLogic = await ethers.getContractAt("LogicV2", await proxy.getAddress());
            await proxiedLogic.increment();

            // V2 → V1 (다운그레이드)
            await proxy.connect(admin).upgradeTo(await logicV1.getAddress());
            expect(await proxy.implementation()).to.equal(await logicV1.getAddress());

            // V1 → V2 (재업그레이드)
            await proxy.connect(admin).upgradeTo(await logicV2.getAddress());
            expect(await proxy.implementation()).to.equal(await logicV2.getAddress());
        });

        it("관리자 변경 후 업그레이드가 가능해야 함", async function () {
            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                "0x"
            );
            await proxy.waitForDeployment();

            // 관리자 변경
            await proxy.connect(admin).changeAdmin(user.address);

            // 새 관리자로 업그레이드
            await proxy.connect(user).upgradeTo(await logicV2.getAddress());

            expect(await proxy.implementation()).to.equal(await logicV2.getAddress());
        });
    });

    describe("9. 가스 최적화 테스트", function () {
        beforeEach(async function () {
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                admin.address,
                initData
            );
            await proxy.waitForDeployment();
        });

        it("프록시를 통한 함수 호출 가스 오버헤드 측정", async function () {
            const proxiedLogic = await ethers.getContractAt("LogicV1", await proxy.getAddress());

            // 프록시를 통한 호출
            const proxyTx = await proxiedLogic.increment();
            const proxyReceipt = await proxyTx.wait();

            // 직접 호출 (비교용)
            const directTx = await logicV1.increment();
            const directReceipt = await directTx.wait();

            console.log("        프록시 호출 가스:", proxyReceipt.gasUsed.toString());
            console.log("        직접 호출 가스:", directReceipt.gasUsed.toString());
            console.log("        오버헤드:", (proxyReceipt.gasUsed - directReceipt.gasUsed).toString());

            // 프록시 오버헤드는 일반적으로 2000~3000 가스
            expect(proxyReceipt.gasUsed - directReceipt.gasUsed).to.be.lessThan(5000n);
        });

        it("upgradeTo 가스 사용량 측정", async function () {
            const tx = await proxy.connect(admin).upgradeTo(await logicV2.getAddress());
            const receipt = await tx.wait();

            console.log("        upgradeTo 가스 사용량:", receipt.gasUsed.toString());

            // upgradeTo는 일반적으로 30,000 ~ 40,000 가스 사용
            expect(receipt.gasUsed).to.be.lessThan(50000n);
        });

        it("upgradeToAndCall 가스 사용량 측정", async function () {
            const initV2Data = logicV2.interface.encodeFunctionData("initializeV2", [10]);

            const tx = await proxy.connect(admin).upgradeToAndCall(
                await logicV2.getAddress(),
                initV2Data
            );
            const receipt = await tx.wait();

            console.log("        upgradeToAndCall 가스 사용량:", receipt.gasUsed.toString());

            // upgradeToAndCall은 초기화 함수 실행 포함
            expect(receipt.gasUsed).to.be.lessThan(100000n);
        });
    });

    describe("10. ProxyAdmin 패턴 테스트", function () {
        let proxyAdmin;

        beforeEach(async function () {
            // ProxyAdmin 배포
            const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
            proxyAdmin = await ProxyAdmin.deploy(admin.address);
            await proxyAdmin.waitForDeployment();

            // ProxyAdmin을 관리자로 하는 프록시 배포
            const initData = logicV1.interface.encodeFunctionData("initialize", [
                owner.address,
                "Counter V1"
            ]);

            const Proxy = await ethers.getContractFactory("EIP1967Proxy");
            proxy = await Proxy.deploy(
                await logicV1.getAddress(),
                await proxyAdmin.getAddress(),
                initData
            );
            await proxy.waitForDeployment();
        });

        it("ProxyAdmin을 통해 업그레이드할 수 있어야 함", async function () {
            expect(await proxy.implementation()).to.equal(await logicV1.getAddress());

            await proxyAdmin.connect(admin).upgrade(
                await proxy.getAddress(),
                await logicV2.getAddress()
            );

            expect(await proxy.implementation()).to.equal(await logicV2.getAddress());
        });

        it("ProxyAdmin을 통해 upgradeAndCall을 실행할 수 있어야 함", async function () {
            const initV2Data = logicV2.interface.encodeFunctionData("initializeV2", [5]);

            await proxyAdmin.connect(admin).upgradeAndCall(
                await proxy.getAddress(),
                await logicV2.getAddress(),
                initV2Data
            );

            const proxiedLogicV2 = await ethers.getContractAt("LogicV2", await proxy.getAddress());
            expect(await proxiedLogicV2.multiplier()).to.equal(5);
        });

        it("ProxyAdmin 소유자만 업그레이드할 수 있어야 함", async function () {
            await expect(
                proxyAdmin.connect(user).upgrade(
                    await proxy.getAddress(),
                    await logicV2.getAddress()
                )
            ).to.be.revertedWith("ProxyAdmin: caller is not owner");
        });
    });
});
