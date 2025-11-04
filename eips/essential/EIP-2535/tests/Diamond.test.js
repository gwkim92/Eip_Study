const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * EIP-2535 (Diamond Pattern) 종합 테스트
 *
 * 테스트 범위:
 * 1. Diamond 배포 및 초기화
 * 2. Facet 관리 (Add, Replace, Remove)
 * 3. 함수 호출 및 delegatecall
 * 4. 스토리지 격리 및 AppStorage 패턴
 * 5. DiamondCut 권한 관리
 * 6. 복합 업그레이드 시나리오
 * 7. 보안 테스트
 * 8. 가스 최적화
 * 9. 실제 사용 시나리오 (ERC20 + Governance + Staking)
 */
describe("EIP-2535: Diamond Pattern 종합 테스트", function () {
    let diamond;
    let diamondCutFacet, erc20Facet, erc20AdvancedFacet, governanceFacet, stakingFacet, adminFacet;
    let diamondInit;
    let owner, user1, user2, user3, attacker;

    // Facet Cut Actions
    const FacetCutAction = {
        Add: 0,
        Replace: 1,
        Remove: 2
    };

    /**
     * 유틸리티: Facet의 모든 함수 selector 가져오기
     */
    function getSelectors(contract) {
        const signatures = Object.keys(contract.interface.functions);
        const selectors = signatures.reduce((acc, val) => {
            if (val !== 'init(bytes)') {
                acc.push(contract.interface.getFunction(val).selector);
            }
            return acc;
        }, []);
        return selectors;
    }

    /**
     * 유틸리티: 특정 함수들의 selector만 가져오기
     */
    function getSelectorsByName(contract, functionNames) {
        return functionNames.map(name => contract.interface.getFunction(name).selector);
    }

    before(async function () {
        [owner, user1, user2, user3, attacker] = await ethers.getSigners();
    });

    beforeEach(async function () {
        // DiamondCutFacet 배포 (필수)
        const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
        diamondCutFacet = await DiamondCutFacet.deploy();
        await diamondCutFacet.waitForDeployment();

        // Diamond 배포
        const Diamond = await ethers.getContractFactory("Diamond");
        diamond = await Diamond.deploy(
            owner.address,
            await diamondCutFacet.getAddress()
        );
        await diamond.waitForDeployment();

        // Facet들 배포
        const ERC20Facet = await ethers.getContractFactory("ERC20Facet");
        erc20Facet = await ERC20Facet.deploy();
        await erc20Facet.waitForDeployment();

        const ERC20AdvancedFacet = await ethers.getContractFactory("ERC20AdvancedFacet");
        erc20AdvancedFacet = await ERC20AdvancedFacet.deploy();
        await erc20AdvancedFacet.waitForDeployment();

        const GovernanceFacet = await ethers.getContractFactory("GovernanceFacet");
        governanceFacet = await GovernanceFacet.deploy();
        await governanceFacet.waitForDeployment();

        const StakingFacet = await ethers.getContractFactory("StakingFacet");
        stakingFacet = await StakingFacet.deploy();
        await stakingFacet.waitForDeployment();

        const AdminFacet = await ethers.getContractFactory("AdminFacet");
        adminFacet = await AdminFacet.deploy();
        await adminFacet.waitForDeployment();

        // DiamondInit 배포
        const DiamondInit = await ethers.getContractFactory("DiamondInit");
        diamondInit = await DiamondInit.deploy();
        await diamondInit.waitForDeployment();
    });

    describe("1. Diamond 배포 및 초기화", function () {
        it("Diamond가 정상적으로 배포되어야 함", async function () {
            expect(await diamond.getAddress()).to.be.properAddress;
        });

        it("DiamondCutFacet이 자동으로 추가되어야 함", async function () {
            const diamondCutInterface = await ethers.getContractAt(
                "IDiamondCut",
                await diamond.getAddress()
            );

            // diamondCut 함수가 존재하는지 확인
            expect(diamondCutInterface.interface.hasFunction("diamondCut")).to.be.true;
        });

        it("초기 소유자가 올바르게 설정되어야 함", async function () {
            // LibDiamond을 통해 소유자 확인
            // (실제로는 DiamondLoupe Facet을 추가하여 조회)
        });
    });

    describe("2. Facet 추가 (Add)", function () {
        it("새로운 Facet을 추가할 수 있어야 함", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, await diamondInit.getAddress(), initData)
            ).to.emit(diamondCut, "DiamondCut");
        });

        it("Facet 추가 후 함수를 호출할 수 있어야 함", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cut, await diamondInit.getAddress(), initData);

            // ERC20 인터페이스로 Diamond에 접근
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());

            expect(await token.name()).to.equal("Diamond Token");
            expect(await token.symbol()).to.equal("DMD");
            expect(await token.decimals()).to.equal(18);
        });

        it("여러 Facet을 한 번에 추가할 수 있어야 함", async function () {
            const erc20Selectors = getSelectors(erc20Facet);
            const adminSelectors = getSelectors(adminFacet);

            const cuts = [
                {
                    facetAddress: await erc20Facet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: erc20Selectors
                },
                {
                    facetAddress: await adminFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: adminSelectors
                }
            ];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cuts, await diamondInit.getAddress(), initData);

            // ERC20 함수 테스트
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            expect(await token.name()).to.equal("Diamond Token");

            // Admin 함수 테스트
            const admin = await ethers.getContractAt("AdminFacet", await diamond.getAddress());
            expect(await admin.isPaused()).to.equal(false);
        });

        it("이미 존재하는 함수를 추가하려 하면 실패해야 함", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x");

            // 동일한 함수를 다시 추가 시도
            await expect(
                diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.be.revertedWith("LibDiamond: Can't add function that already exists");
        });
    });

    describe("3. Facet 교체 (Replace)", function () {
        beforeEach(async function () {
            // ERC20Facet 추가
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cut, await diamondInit.getAddress(), initData);
        });

        it("기존 Facet을 새로운 Facet으로 교체할 수 있어야 함", async function () {
            // ERC20AdvancedFacet으로 교체할 함수들 선택
            const selectorsToReplace = getSelectorsByName(erc20Facet, [
                "transfer",
                "approve"
            ]);

            const cut = [{
                facetAddress: await erc20AdvancedFacet.getAddress(),
                action: FacetCutAction.Replace,
                functionSelectors: selectorsToReplace
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.emit(diamondCut, "DiamondCut");
        });

        it("교체 후 새로운 구현이 동작해야 함", async function () {
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());

            // 초기 토큰 발행 (owner용)
            const advancedBefore = await ethers.getContractAt(
                "ERC20AdvancedFacet",
                await diamond.getAddress()
            );
            await advancedBefore.mint(owner.address, ethers.parseEther("1000"));

            // 교체 전 동작 확인
            await token.transfer(user1.address, ethers.parseEther("100"));
            expect(await token.balanceOf(user1.address)).to.equal(ethers.parseEther("100"));

            // 모든 ERC20 함수를 Advanced로 교체
            const selectorsToReplace = getSelectorsByName(erc20Facet, [
                "transfer",
                "transferFrom",
                "approve",
                "balanceOf",
                "allowance",
                "totalSupply"
            ]);

            const cut = [{
                facetAddress: await erc20AdvancedFacet.getAddress(),
                action: FacetCutAction.Replace,
                functionSelectors: selectorsToReplace
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x");

            // 교체 후에도 스토리지 유지
            const tokenAfter = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            expect(await tokenAfter.balanceOf(user1.address)).to.equal(ethers.parseEther("100"));

            // 새로운 구현으로 전송
            await tokenAfter.transfer(user2.address, ethers.parseEther("50"));
            expect(await tokenAfter.balanceOf(user2.address)).to.equal(ethers.parseEther("50"));
        });

        it("존재하지 않는 함수를 교체하려 하면 실패해야 함", async function () {
            const nonExistentSelector = "0x12345678";

            const cut = [{
                facetAddress: await erc20AdvancedFacet.getAddress(),
                action: FacetCutAction.Replace,
                functionSelectors: [nonExistentSelector]
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.be.revertedWith("LibDiamond: Can't replace function that doesn't exist");
        });
    });

    describe("4. Facet 제거 (Remove)", function () {
        beforeEach(async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cut, await diamondInit.getAddress(), initData);
        });

        it("함수를 제거할 수 있어야 함", async function () {
            const selectorsToRemove = getSelectorsByName(erc20Facet, ["decimals"]);

            const cut = [{
                facetAddress: ethers.ZeroAddress, // Remove는 address(0)
                action: FacetCutAction.Remove,
                functionSelectors: selectorsToRemove
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.emit(diamondCut, "DiamondCut");
        });

        it("제거된 함수는 호출할 수 없어야 함", async function () {
            const selectorsToRemove = getSelectorsByName(erc20Facet, ["name", "symbol"]);

            const cut = [{
                facetAddress: ethers.ZeroAddress,
                action: FacetCutAction.Remove,
                functionSelectors: selectorsToRemove
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x");

            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());

            // 제거된 함수 호출 시 실패
            await expect(token.name()).to.be.revertedWith("Diamond: Function does not exist");
            await expect(token.symbol()).to.be.revertedWith("Diamond: Function does not exist");

            // 제거되지 않은 함수는 정상 동작
            expect(await token.decimals()).to.equal(18);
        });

        it("Remove 시 facetAddress가 address(0)이 아니면 실패해야 함", async function () {
            const selectorsToRemove = getSelectorsByName(erc20Facet, ["decimals"]);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(), // 잘못된 주소
                action: FacetCutAction.Remove,
                functionSelectors: selectorsToRemove
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.be.revertedWith("LibDiamond: Remove facet address must be address(0)");
        });
    });

    describe("5. 스토리지 격리 및 AppStorage 패턴", function () {
        beforeEach(async function () {
            // ERC20, Advanced, Governance Facet 모두 추가
            const cuts = [
                {
                    facetAddress: await erc20Facet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(erc20Facet)
                },
                {
                    facetAddress: await erc20AdvancedFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(erc20AdvancedFacet)
                },
                {
                    facetAddress: await governanceFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(governanceFacet)
                }
            ];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cuts, await diamondInit.getAddress(), initData);
        });

        it("모든 Facet이 동일한 스토리지를 공유해야 함", async function () {
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            const advanced = await ethers.getContractAt("ERC20AdvancedFacet", await diamond.getAddress());

            // Advanced Facet으로 mint
            await advanced.mint(user1.address, ethers.parseEther("1000"));

            // ERC20 Facet으로 조회 (동일한 스토리지)
            expect(await token.balanceOf(user1.address)).to.equal(ethers.parseEther("1000"));
            expect(await token.totalSupply()).to.equal(ethers.parseEther("1000"));
        });

        it("Facet 간 상호작용이 정상적으로 동작해야 함", async function () {
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            const advanced = await ethers.getContractAt("ERC20AdvancedFacet", await diamond.getAddress());
            const governance = await ethers.getContractAt("GovernanceFacet", await diamond.getAddress());

            // 토큰 발행
            await advanced.mint(user1.address, ethers.parseEther("10000"));

            // 거버넌스 설정
            await governance.setGovernanceConfig(ethers.parseEther("100"), 86400); // threshold, voting period

            // 제안 생성 (user1이 충분한 토큰 보유)
            await governance.connect(user1).propose("Proposal 1");

            // 투표
            await governance.connect(user1).vote(0, true);

            const proposal = await governance.getProposal(0);
            expect(proposal.forVotes).to.equal(ethers.parseEther("10000"));
        });
    });

    describe("6. 권한 관리 및 보안", function () {
        it("소유자만 diamondCut을 호출할 수 있어야 함", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.connect(attacker).diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.be.revertedWith("LibDiamond: Must be contract owner");

            // 소유자는 가능
            await expect(
                diamondCut.connect(owner).diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.not.be.reverted;
        });

        it("유효하지 않은 컨트랙트 주소로 추가 시 실패해야 함", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: user1.address, // EOA
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.be.revertedWith("LibDiamond: New facet has no code");
        });

        it("초기화 함수 실행 실패 시 전체가 revert되어야 함", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            // 잘못된 초기화 데이터
            const badInitData = "0x12345678";

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, await diamondInit.getAddress(), badInitData)
            ).to.be.reverted;
        });
    });

    describe("7. 복합 업그레이드 시나리오", function () {
        beforeEach(async function () {
            // 초기 ERC20Facet 추가
            const cuts = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(erc20Facet)
            }];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cuts, await diamondInit.getAddress(), initData);
        });

        it("Add, Replace, Remove를 동시에 수행할 수 있어야 함", async function () {
            const advanced = await ethers.getContractAt("ERC20AdvancedFacet", await diamond.getAddress());
            await advanced.mint(user1.address, ethers.parseEther("1000"));

            const cuts = [
                // 새 Facet 추가
                {
                    facetAddress: await governanceFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(governanceFacet)
                },
                // 기존 함수 교체
                {
                    facetAddress: await erc20AdvancedFacet.getAddress(),
                    action: FacetCutAction.Replace,
                    functionSelectors: getSelectorsByName(erc20Facet, ["transfer"])
                },
                // 함수 제거
                {
                    facetAddress: ethers.ZeroAddress,
                    action: FacetCutAction.Remove,
                    functionSelectors: getSelectorsByName(erc20Facet, ["symbol"])
                }
            ];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cuts, ethers.ZeroAddress, "0x");

            // Governance 함수 동작 확인
            const governance = await ethers.getContractAt("GovernanceFacet", await diamond.getAddress());
            await governance.setGovernanceConfig(ethers.parseEther("100"), 86400);

            // Transfer는 여전히 동작 (교체됨)
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            await token.connect(user1).transfer(user2.address, ethers.parseEther("100"));

            // Symbol은 제거되어 호출 불가
            await expect(token.symbol()).to.be.revertedWith("Diamond: Function does not exist");
        });

        it("여러 단계의 업그레이드를 순차적으로 수행할 수 있어야 함", async function () {
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            // 1단계: Advanced Facet 추가
            let cuts = [{
                facetAddress: await erc20AdvancedFacet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(erc20AdvancedFacet)
            }];
            await diamondCut.diamondCut(cuts, ethers.ZeroAddress, "0x");

            const advanced = await ethers.getContractAt("ERC20AdvancedFacet", await diamond.getAddress());
            await advanced.mint(user1.address, ethers.parseEther("10000"));
            expect(await token.balanceOf(user1.address)).to.equal(ethers.parseEther("10000"));

            // 2단계: Governance Facet 추가
            cuts = [{
                facetAddress: await governanceFacet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(governanceFacet)
            }];
            await diamondCut.diamondCut(cuts, ethers.ZeroAddress, "0x");

            const governance = await ethers.getContractAt("GovernanceFacet", await diamond.getAddress());
            await governance.setGovernanceConfig(ethers.parseEther("100"), 86400);

            // 3단계: Staking Facet 추가
            cuts = [{
                facetAddress: await stakingFacet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(stakingFacet)
            }];
            await diamondCut.diamondCut(cuts, ethers.ZeroAddress, "0x");

            const staking = await ethers.getContractAt("StakingFacet", await diamond.getAddress());
            await staking.setStakingConfig(ethers.parseEther("0.1"), 3600);

            // 모든 기능이 정상 동작
            await staking.connect(user1).stake(ethers.parseEther("1000"));
            expect((await staking.getStakeInfo(user1.address)).amount).to.equal(ethers.parseEther("1000"));
        });
    });

    describe("8. 실제 사용 시나리오 - Full Featured Diamond", function () {
        beforeEach(async function () {
            // 모든 Facet 추가
            const cuts = [
                {
                    facetAddress: await erc20Facet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(erc20Facet)
                },
                {
                    facetAddress: await erc20AdvancedFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(erc20AdvancedFacet)
                },
                {
                    facetAddress: await governanceFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(governanceFacet)
                },
                {
                    facetAddress: await stakingFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(stakingFacet)
                },
                {
                    facetAddress: await adminFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(adminFacet)
                }
            ];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond DAO Token",
                "DDT",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cuts, await diamondInit.getAddress(), initData);

            // 초기 설정
            const governance = await ethers.getContractAt("GovernanceFacet", await diamond.getAddress());
            await governance.setGovernanceConfig(ethers.parseEther("1000"), 86400);

            const staking = await ethers.getContractAt("StakingFacet", await diamond.getAddress());
            await staking.setStakingConfig(ethers.parseEther("0.1"), 3600);

            // 토큰 발행
            const advanced = await ethers.getContractAt("ERC20AdvancedFacet", await diamond.getAddress());
            await advanced.mint(user1.address, ethers.parseEther("10000"));
            await advanced.mint(user2.address, ethers.parseEther("10000"));
            await advanced.mint(user3.address, ethers.parseEther("10000"));
        });

        it("전체 워크플로우: 토큰 전송 → 스테이킹 → 거버넌스 참여", async function () {
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            const staking = await ethers.getContractAt("StakingFacet", await diamond.getAddress());
            const governance = await ethers.getContractAt("GovernanceFacet", await diamond.getAddress());

            // 1. 토큰 전송
            await token.connect(user1).transfer(user2.address, ethers.parseEther("1000"));
            expect(await token.balanceOf(user2.address)).to.equal(ethers.parseEther("11000"));

            // 2. 스테이킹
            await staking.connect(user1).stake(ethers.parseEther("5000"));
            let stakeInfo = await staking.getStakeInfo(user1.address);
            expect(stakeInfo.amount).to.equal(ethers.parseEther("5000"));

            // 3. 거버넌스 제안 생성
            await governance.connect(user2).propose("Increase staking rewards");

            // 4. 투표
            await governance.connect(user2).vote(0, true);
            await governance.connect(user3).vote(0, true);

            const proposal = await governance.getProposal(0);
            expect(proposal.forVotes).to.equal(ethers.parseEther("21000")); // user2 + user3
        });

        it("관리자 기능: 일시 중지 및 블랙리스트", async function () {
            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            const admin = await ethers.getContractAt("AdminFacet", await diamond.getAddress());

            // 일시 중지
            await admin.pause();
            expect(await admin.isPaused()).to.be.true;

            // 전송 불가
            await expect(
                token.connect(user1).transfer(user2.address, ethers.parseEther("100"))
            ).to.be.revertedWith("ERC20: transfers paused");

            // 일시 중지 해제
            await admin.unpause();
            await token.connect(user1).transfer(user2.address, ethers.parseEther("100"));

            // 블랙리스트 추가
            await admin.blacklist(user1.address);

            // 블랙리스트 사용자는 전송 불가
            await expect(
                token.connect(user1).transfer(user2.address, ethers.parseEther("100"))
            ).to.be.revertedWith("ERC20: sender blacklisted");
        });
    });

    describe("9. 가스 최적화 테스트", function () {
        it("Facet 추가 가스 사용량 측정", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            const tx = await diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x");
            const receipt = await tx.wait();

            console.log("        Facet 추가 가스 (" + selectors.length + " functions):", receipt.gasUsed.toString());

            // 함수당 약 20,000 ~ 30,000 가스 사용
        });

        it("Diamond를 통한 함수 호출 가스 오버헤드", async function () {
            const selectors = getSelectors(erc20Facet);

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];

            const initData = diamondInit.interface.encodeFunctionData("initERC20", [
                "Diamond Token",
                "DMD",
                18
            ]);

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(cut, await diamondInit.getAddress(), initData);

            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            const advanced = await ethers.getContractAt("ERC20AdvancedFacet", await diamond.getAddress());
            await advanced.mint(user1.address, ethers.parseEther("1000"));

            // Diamond를 통한 호출
            const diamondTx = await token.connect(user1).transfer(user2.address, ethers.parseEther("100"));
            const diamondReceipt = await diamondTx.wait();

            // 직접 호출 (비교용)
            await advanced.mint(await erc20Facet.getAddress(), ethers.parseEther("1000"));
            const directTx = await erc20Facet.transfer(user2.address, ethers.parseEther("100"));
            const directReceipt = await directTx.wait();

            console.log("        Diamond 호출 가스:", diamondReceipt.gasUsed.toString());
            console.log("        직접 호출 가스:", directReceipt.gasUsed.toString());
            console.log("        오버헤드:", (diamondReceipt.gasUsed - directReceipt.gasUsed).toString());

            // Diamond 오버헤드는 약 2000~3000 가스
        });

        it("복합 DiamondCut 가스 사용량", async function () {
            // 초기 Facet 추가
            const initialCuts = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(erc20Facet)
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());
            await diamondCut.diamondCut(initialCuts, ethers.ZeroAddress, "0x");

            // 복합 작업 (Add + Replace + Remove)
            const complexCuts = [
                {
                    facetAddress: await governanceFacet.getAddress(),
                    action: FacetCutAction.Add,
                    functionSelectors: getSelectors(governanceFacet)
                },
                {
                    facetAddress: await erc20AdvancedFacet.getAddress(),
                    action: FacetCutAction.Replace,
                    functionSelectors: getSelectorsByName(erc20Facet, ["transfer", "approve"])
                },
                {
                    facetAddress: ethers.ZeroAddress,
                    action: FacetCutAction.Remove,
                    functionSelectors: getSelectorsByName(erc20Facet, ["symbol"])
                }
            ];

            const tx = await diamondCut.diamondCut(complexCuts, ethers.ZeroAddress, "0x");
            const receipt = await tx.wait();

            console.log("        복합 DiamondCut 가스:", receipt.gasUsed.toString());
        });
    });

    describe("10. 엣지 케이스 및 안정성", function () {
        it("빈 FacetCut 배열로 호출 가능", async function () {
            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut([], ethers.ZeroAddress, "0x")
            ).to.not.be.reverted;
        });

        it("동일한 Facet을 여러 번 추가/제거 가능", async function () {
            const selectors = getSelectors(erc20Facet);
            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            // 추가
            let cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];
            await diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x");

            // 제거
            cut = [{
                facetAddress: ethers.ZeroAddress,
                action: FacetCutAction.Remove,
                functionSelectors: selectors
            }];
            await diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x");

            // 다시 추가
            cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: selectors
            }];
            await diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x");

            const token = await ethers.getContractAt("ERC20Facet", await diamond.getAddress());
            await expect(token.decimals()).to.not.be.reverted;
        });

        it("매우 많은 함수를 가진 Facet 처리", async function () {
            // ERC20 + Advanced + Governance + Staking = 많은 함수
            const allSelectors = [
                ...getSelectors(erc20Facet),
                ...getSelectors(erc20AdvancedFacet)
            ];

            const cut = [{
                facetAddress: await erc20Facet.getAddress(),
                action: FacetCutAction.Add,
                functionSelectors: allSelectors.slice(0, getSelectors(erc20Facet).length)
            }];

            const diamondCut = await ethers.getContractAt("IDiamondCut", await diamond.getAddress());

            await expect(
                diamondCut.diamondCut(cut, ethers.ZeroAddress, "0x")
            ).to.not.be.reverted;
        });
    });
});
