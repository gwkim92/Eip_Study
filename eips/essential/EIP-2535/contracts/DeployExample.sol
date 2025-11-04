// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Diamond} from "./Diamond.sol";
import {DiamondCutFacet} from "./DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./interfaces/IDiamondLoupe.sol";
import {OwnershipFacet} from "./interfaces/IERC173.sol";
import {ERC20Facet, ERC20AdvancedFacet, GovernanceFacet, StakingFacet, AdminFacet} from "./ExampleFacets.sol";
import {DiamondInit} from "./DiamondInit.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

/**
 * @title DeployDiamond
 * @notice Diamond 배포 및 초기화를 위한 헬퍼 컨트랙트
 * @dev 실제 배포 스크립트에서 참고할 수 있는 예제
 *
 * 배포 순서:
 * 1. 모든 Facet 배포
 * 2. Diamond 배포 (DiamondCutFacet 포함)
 * 3. 나머지 Facet들을 DiamondCut으로 추가
 * 4. 초기화 실행
 */
contract DeployDiamond {

    /**
     * @notice 기본 ERC20 Diamond 배포
     * @param _owner Diamond 소유자
     * @param _name 토큰 이름
     * @param _symbol 토큰 심볼
     * @return diamond Diamond 주소
     *
     * @dev 포함 기능: ERC20 기본 + DiamondCut + DiamondLoupe + Ownership
     */
    function deployBasicDiamond(
        address _owner,
        string memory _name,
        string memory _symbol
    ) external returns (address diamond) {
        // 1. Facet들 배포
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC20Facet erc20Facet = new ERC20Facet();

        // 2. Diamond 배포 (DiamondCutFacet은 생성자에서 자동 추가됨)
        Diamond d = new Diamond(_owner, address(diamondCutFacet));
        diamond = address(d);

        // 3. 추가할 Facet들 준비
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);

        // DiamondLoupe Facet
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getDiamondLoupeSelectors()
        });

        // Ownership Facet
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getOwnershipSelectors()
        });

        // ERC20 Facet
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getERC20Selectors()
        });

        // 4. 초기화 데이터 준비
        DiamondInit diamondInit = new DiamondInit();
        bytes memory initData = abi.encodeWithSelector(
            DiamondInit.init.selector,
            _name,
            _symbol,
            18
        );

        // 5. DiamondCut 실행 (Facet 추가 + 초기화)
        IDiamondCut(diamond).diamondCut(cuts, address(diamondInit), initData);
    }

    /**
     * @notice 고급 기능이 포함된 Diamond 배포
     * @param _owner Diamond 소유자
     * @param _name 토큰 이름
     * @param _symbol 토큰 심볼
     * @return diamond Diamond 주소
     *
     * @dev 포함 기능: 기본 기능 + ERC20 고급 + 거버넌스 + 스테이킹 + 관리자
     */
    function deployAdvancedDiamond(
        address _owner,
        string memory _name,
        string memory _symbol
    ) external returns (address diamond) {
        // 1. 모든 Facet 배포
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC20Facet erc20Facet = new ERC20Facet();
        ERC20AdvancedFacet erc20AdvancedFacet = new ERC20AdvancedFacet();
        GovernanceFacet governanceFacet = new GovernanceFacet();
        StakingFacet stakingFacet = new StakingFacet();
        AdminFacet adminFacet = new AdminFacet();

        // 2. Diamond 배포
        Diamond d = new Diamond(_owner, address(diamondCutFacet));
        diamond = address(d);

        // 3. 모든 Facet 추가 준비
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](7);

        cuts[0] = createFacetCut(
            address(diamondLoupeFacet),
            getDiamondLoupeSelectors()
        );

        cuts[1] = createFacetCut(
            address(ownershipFacet),
            getOwnershipSelectors()
        );

        cuts[2] = createFacetCut(
            address(erc20Facet),
            getERC20Selectors()
        );

        cuts[3] = createFacetCut(
            address(erc20AdvancedFacet),
            getERC20AdvancedSelectors()
        );

        cuts[4] = createFacetCut(
            address(governanceFacet),
            getGovernanceSelectors()
        );

        cuts[5] = createFacetCut(
            address(stakingFacet),
            getStakingSelectors()
        );

        cuts[6] = createFacetCut(
            address(adminFacet),
            getAdminSelectors()
        );

        // 4. 완전한 초기화
        DiamondInit diamondInit = new DiamondInit();
        bytes memory initData = abi.encodeWithSelector(
            DiamondInit.initFull.selector,
            _name,
            _symbol,
            18,
            _owner,
            100 ether,    // proposalThreshold: 100 토큰
            7 days,       // votingPeriod: 7일
            1e15,         // rewardRate: 0.001 토큰/초
            30 days,      // minStakingPeriod: 30일
            1000000 ether // initialSupply: 1,000,000 토큰
        );

        // 5. DiamondCut 실행
        IDiamondCut(diamond).diamondCut(cuts, address(diamondInit), initData);
    }

    /**
     * @notice 기존 Diamond에 새 Facet 추가
     * @param diamond Diamond 주소
     * @param facetAddress 추가할 Facet 주소
     * @param selectors 추가할 함수 selector 배열
     */
    function addFacet(
        address diamond,
        address facetAddress,
        bytes4[] memory selectors
    ) external {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    /**
     * @notice 기존 Facet의 함수를 다른 Facet으로 교체
     * @param diamond Diamond 주소
     * @param newFacetAddress 새 Facet 주소
     * @param selectors 교체할 함수 selector 배열
     */
    function replaceFacet(
        address diamond,
        address newFacetAddress,
        bytes4[] memory selectors
    ) external {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: newFacetAddress,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    /**
     * @notice Diamond에서 함수 제거
     * @param diamond Diamond 주소
     * @param selectors 제거할 함수 selector 배열
     */
    function removeFunctions(
        address diamond,
        bytes4[] memory selectors
    ) external {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    // ============================================
    // Helper Functions: Function Selector 생성
    // ============================================

    function createFacetCut(
        address facetAddress,
        bytes4[] memory selectors
    ) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function getDiamondLoupeSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;
        return selectors;
    }

    function getOwnershipSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = OwnershipFacet.owner.selector;
        selectors[1] = OwnershipFacet.transferOwnership.selector;
        return selectors;
    }

    function getERC20Selectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = ERC20Facet.transfer.selector;
        selectors[1] = ERC20Facet.transferFrom.selector;
        selectors[2] = ERC20Facet.approve.selector;
        selectors[3] = ERC20Facet.balanceOf.selector;
        selectors[4] = ERC20Facet.allowance.selector;
        selectors[5] = ERC20Facet.totalSupply.selector;
        selectors[6] = ERC20Facet.name.selector;
        selectors[7] = ERC20Facet.symbol.selector;
        selectors[8] = ERC20Facet.decimals.selector;
        return selectors;
    }

    function getERC20AdvancedSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = ERC20AdvancedFacet.mint.selector;
        selectors[1] = ERC20AdvancedFacet.burn.selector;
        selectors[2] = ERC20AdvancedFacet.burnFrom.selector;
        selectors[3] = ERC20AdvancedFacet.increaseAllowance.selector;
        selectors[4] = ERC20AdvancedFacet.decreaseAllowance.selector;
        return selectors;
    }

    function getGovernanceSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = GovernanceFacet.propose.selector;
        selectors[1] = GovernanceFacet.vote.selector;
        selectors[2] = GovernanceFacet.executeProposal.selector;
        selectors[3] = GovernanceFacet.getProposal.selector;
        return selectors;
    }

    function getStakingSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = StakingFacet.stake.selector;
        selectors[1] = StakingFacet.unstake.selector;
        selectors[2] = StakingFacet.claimRewards.selector;
        selectors[3] = StakingFacet.getStakeInfo.selector;
        return selectors;
    }

    function getAdminSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = AdminFacet.pause.selector;
        selectors[1] = AdminFacet.unpause.selector;
        selectors[2] = AdminFacet.blacklist.selector;
        selectors[3] = AdminFacet.unblacklist.selector;
        selectors[4] = AdminFacet.whitelist.selector;
        selectors[5] = AdminFacet.unwhitelist.selector;
        selectors[6] = AdminFacet.isPaused.selector;
        selectors[7] = AdminFacet.isBlacklisted.selector;
        selectors[8] = AdminFacet.isWhitelisted.selector;
        return selectors;
    }
}

/**
 * 사용 예시 (Hardhat 스크립트):
 *
 * // scripts/deploy.js
 * const { ethers } = require("hardhat");
 *
 * async function main() {
 *     const [deployer] = await ethers.getSigners();
 *     console.log("Deploying contracts with:", deployer.address);
 *
 *     // 1. DeployDiamond 배포
 *     const DeployDiamond = await ethers.getContractFactory("DeployDiamond");
 *     const deployHelper = await DeployDiamond.deploy();
 *     await deployHelper.deployed();
 *
 *     // 2. Basic Diamond 배포
 *     const tx = await deployHelper.deployBasicDiamond(
 *         deployer.address,
 *         "My Diamond Token",
 *         "MDT"
 *     );
 *     const receipt = await tx.wait();
 *
 *     // Diamond 주소 추출 (이벤트에서)
 *     const diamondAddress = receipt.events[0].address;
 *     console.log("Diamond deployed to:", diamondAddress);
 *
 *     // 3. Diamond 사용
 *     const ERC20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
 *     const name = await ERC20.name();
 *     console.log("Token name:", name);
 * }
 *
 * main()
 *     .then(() => process.exit(0))
 *     .catch((error) => {
 *         console.error(error);
 *         process.exit(1);
 *     });
 *
 * // scripts/upgrade.js
 * async function upgrade() {
 *     const diamondAddress = "0x..."; // 기존 Diamond 주소
 *
 *     // 새로운 Facet 배포
 *     const ERC20FacetV2 = await ethers.getContractFactory("ERC20FacetV2");
 *     const newFacet = await ERC20FacetV2.deploy();
 *     await newFacet.deployed();
 *
 *     // DeployDiamond 컨트랙트 사용
 *     const DeployDiamond = await ethers.getContractAt(
 *         "DeployDiamond",
 *         deployHelperAddress
 *     );
 *
 *     // transfer 함수만 교체
 *     await DeployDiamond.replaceFacet(
 *         diamondAddress,
 *         newFacet.address,
 *         [ERC20FacetV2.interface.getSighash("transfer(address,uint256)")]
 *     );
 *
 *     console.log("Upgrade completed");
 * }
 *
 * // scripts/test-diamond.js
 * async function testDiamond() {
 *     const diamondAddress = "0x...";
 *     const [owner, user1] = await ethers.getSigners();
 *
 *     // ERC20 기능 테스트
 *     const token = await ethers.getContractAt("ERC20Facet", diamondAddress);
 *     await token.transfer(user1.address, ethers.utils.parseEther("100"));
 *
 *     // 거버넌스 기능 테스트
 *     const governance = await ethers.getContractAt("GovernanceFacet", diamondAddress);
 *     await governance.propose("Proposal description");
 *
 *     // 스테이킹 기능 테스트
 *     const staking = await ethers.getContractAt("StakingFacet", diamondAddress);
 *     await staking.stake(ethers.utils.parseEther("50"));
 *
 *     // DiamondLoupe로 정보 확인
 *     const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
 *     const facets = await loupe.facets();
 *     console.log("Total facets:", facets.length);
 * }
 */
