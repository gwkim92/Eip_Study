// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage} from "./AppStorage.sol";

/**
 * @title DiamondInit
 * @notice Diamond 초기화를 위한 컨트랙트
 * @dev DiamondCut과 함께 사용되어 초기 설정을 수행
 *
 * 사용 시나리오:
 * 1. Diamond 최초 배포 시 초기 데이터 설정
 * 2. 새로운 Facet 추가 시 필요한 초기화
 * 3. 업그레이드 시 마이그레이션 로직
 *
 * 주의사항:
 * - init 함수는 delegatecall로 실행됨 (Diamond의 storage 사용)
 * - 한 번만 실행되도록 설계해야 함
 * - 초기화 실패 시 전체 DiamondCut이 revert됨
 */
contract DiamondInit {

    /**
     * @notice 초기화 완료 이벤트
     * @param name 토큰 이름
     * @param symbol 토큰 심볼
     */
    event DiamondInitialized(string name, string symbol);

    /**
     * @notice ERC20 토큰 기본 정보 초기화
     * @param _name 토큰 이름 (예: "My Token")
     * @param _symbol 토큰 심볼 (예: "MTK")
     * @param _decimals 소수점 자리수 (보통 18)
     *
     * @dev 사용 예시:
     * ```
     * DiamondInit init = new DiamondInit();
     * bytes memory initData = abi.encodeWithSelector(
     *     DiamondInit.init.selector,
     *     "My Token",
     *     "MTK",
     *     18
     * );
     * IDiamondCut(diamond).diamondCut(cuts, address(init), initData);
     * ```
     */
    function init(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) external {
        // AppStorage 접근
        AppStorage storage s;
        assembly {
            s.slot := 0
        }

        // ERC20 기본 정보 설정
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;

        emit DiamondInitialized(_name, _symbol);
    }

    /**
     * @notice ERC20 토큰과 거버넌스 초기화
     * @param _name 토큰 이름
     * @param _symbol 토큰 심볼
     * @param _decimals 소수점 자리수
     * @param _proposalThreshold 제안 생성에 필요한 최소 토큰 양
     * @param _votingPeriod 투표 기간 (초)
     *
     * @dev 거버넌스 기능이 있는 토큰의 초기화
     */
    function initWithGovernance(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _proposalThreshold,
        uint256 _votingPeriod
    ) external {
        AppStorage storage s;
        assembly {
            s.slot := 0
        }

        // ERC20 기본 정보
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;

        // 거버넌스 설정
        s.proposalThreshold = _proposalThreshold;
        s.votingPeriod = _votingPeriod;

        emit DiamondInitialized(_name, _symbol);
    }

    /**
     * @notice 완전한 초기화 (모든 기능 포함)
     * @param _name 토큰 이름
     * @param _symbol 토큰 심볼
     * @param _decimals 소수점 자리수
     * @param _owner 소유자 주소
     * @param _proposalThreshold 제안 임계값
     * @param _votingPeriod 투표 기간
     * @param _rewardRate 스테이킹 보상률
     * @param _minStakingPeriod 최소 스테이킹 기간
     * @param _initialSupply 초기 발행량
     */
    function initFull(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner,
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _rewardRate,
        uint256 _minStakingPeriod,
        uint256 _initialSupply
    ) external {
        AppStorage storage s;
        assembly {
            s.slot := 0
        }

        // ERC20 기본 정보
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;

        // 소유자 설정
        s.owner = _owner;

        // 거버넌스 설정
        s.proposalThreshold = _proposalThreshold;
        s.votingPeriod = _votingPeriod;

        // 스테이킹 설정
        s.rewardRate = _rewardRate;
        s.minStakingPeriod = _minStakingPeriod;

        // 초기 발행량 설정 (소유자에게 할당)
        if (_initialSupply > 0) {
            s.totalSupply = _initialSupply;
            s.balances[_owner] = _initialSupply;
        }

        emit DiamondInitialized(_name, _symbol);
    }

    /**
     * @notice 업그레이드용 초기화 함수
     * @param _newFeatureParam 새 기능에 필요한 파라미터
     *
     * @dev 새로운 Facet 추가 시 필요한 초기화
     * 예: 새로운 기능을 위한 설정값 초기화
     */
    function initUpgrade(uint256 _newFeatureParam) external {
        AppStorage storage s;
        assembly {
            s.slot := 0
        }

        // 새 기능 초기화
        // 예: s.newFeatureValue = _newFeatureParam;

        // 기존 데이터는 그대로 유지됨
    }

    /**
     * @notice 마이그레이션용 초기화 함수
     * @dev 데이터 구조 변경 시 사용
     *
     * 예시: V1에서 V2로 마이그레이션
     * - V1: mapping(address => uint256) balance
     * - V2: mapping(address => uint256) balance + uint256 totalSupply
     */
    function initMigration() external {
        AppStorage storage s;
        assembly {
            s.slot := 0
        }

        // 기존 데이터를 기반으로 새 필드 계산
        // 예: totalSupply를 모든 balance의 합으로 계산
        // (실제로는 이 방법은 비효율적이므로 다른 방법 사용)
    }
}

/**
 * 상세 사용 예시:
 *
 * // === 시나리오 1: 최초 배포 시 기본 초기화 ===
 *
 * contract DeployDiamond {
 *     function deploy() external {
 *         // 1. Facet들 배포
 *         DiamondCutFacet cutFacet = new DiamondCutFacet();
 *         ERC20Facet erc20Facet = new ERC20Facet();
 *
 *         // 2. Diamond 배포
 *         Diamond diamond = new Diamond(msg.sender, address(cutFacet));
 *
 *         // 3. FacetCut 준비
 *         IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
 *         cuts[0] = IDiamondCut.FacetCut({
 *             facetAddress: address(erc20Facet),
 *             action: IDiamondCut.FacetCutAction.Add,
 *             functionSelectors: getERC20Selectors()
 *         });
 *
 *         // 4. 초기화 데이터 준비
 *         DiamondInit init = new DiamondInit();
 *         bytes memory initData = abi.encodeWithSelector(
 *             DiamondInit.init.selector,
 *             "Diamond Token",
 *             "DMT",
 *             18
 *         );
 *
 *         // 5. DiamondCut 실행 (Facet 추가 + 초기화)
 *         IDiamondCut(address(diamond)).diamondCut(cuts, address(init), initData);
 *     }
 * }
 *
 * // === 시나리오 2: 거버넌스 기능 추가 ===
 *
 * contract AddGovernance {
 *     function addGovernanceFacet(address diamond) external {
 *         // 1. 거버넌스 Facet 배포
 *         GovernanceFacet govFacet = new GovernanceFacet();
 *
 *         // 2. FacetCut 준비
 *         IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
 *         cuts[0] = IDiamondCut.FacetCut({
 *             facetAddress: address(govFacet),
 *             action: IDiamondCut.FacetCutAction.Add,
 *             functionSelectors: getGovernanceSelectors()
 *         });
 *
 *         // 3. 거버넌스 초기화 데이터
 *         DiamondInit init = new DiamondInit();
 *         bytes memory initData = abi.encodeWithSelector(
 *             DiamondInit.initWithGovernance.selector,
 *             "", // name (이미 설정됨)
 *             "", // symbol (이미 설정됨)
 *             0,  // decimals (이미 설정됨)
 *             100 ether, // proposalThreshold: 100 토큰 필요
 *             7 days     // votingPeriod: 7일
 *         );
 *
 *         // 4. DiamondCut 실행
 *         IDiamondCut(diamond).diamondCut(cuts, address(init), initData);
 *     }
 * }
 *
 * // === 시나리오 3: 완전한 초기화 (한 번에 모든 설정) ===
 *
 * contract DeployFullDiamond {
 *     function deploy() external {
 *         // Facet들 배포
 *         DiamondCutFacet cutFacet = new DiamondCutFacet();
 *         ERC20Facet erc20Facet = new ERC20Facet();
 *         GovernanceFacet govFacet = new GovernanceFacet();
 *         StakingFacet stakingFacet = new StakingFacet();
 *
 *         // Diamond 배포
 *         Diamond diamond = new Diamond(msg.sender, address(cutFacet));
 *
 *         // 모든 Facet 추가
 *         IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);
 *         cuts[0] = createCut(address(erc20Facet), getERC20Selectors());
 *         cuts[1] = createCut(address(govFacet), getGovernanceSelectors());
 *         cuts[2] = createCut(address(stakingFacet), getStakingSelectors());
 *
 *         // 완전한 초기화
 *         DiamondInit init = new DiamondInit();
 *         bytes memory initData = abi.encodeWithSelector(
 *             DiamondInit.initFull.selector,
 *             "Full Diamond Token",  // name
 *             "FDT",                  // symbol
 *             18,                     // decimals
 *             msg.sender,             // owner
 *             100 ether,              // proposalThreshold
 *             7 days,                 // votingPeriod
 *             1e15,                   // rewardRate (0.001 token per second per staked token)
 *             30 days,                // minStakingPeriod
 *             1000000 ether           // initialSupply
 *         );
 *
 *         // DiamondCut 실행
 *         IDiamondCut(address(diamond)).diamondCut(cuts, address(init), initData);
 *     }
 * }
 *
 * // === 시나리오 4: 초기화 없이 Facet만 추가 ===
 *
 * contract AddFacetWithoutInit {
 *     function addFacet(address diamond) external {
 *         // 새 Facet 배포
 *         NewFacet newFacet = new NewFacet();
 *
 *         // FacetCut 준비
 *         IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
 *         cuts[0] = IDiamondCut.FacetCut({
 *             facetAddress: address(newFacet),
 *             action: IDiamondCut.FacetCutAction.Add,
 *             functionSelectors: getNewFacetSelectors()
 *         });
 *
 *         // 초기화 없이 추가
 *         IDiamondCut(diamond).diamondCut(
 *             cuts,
 *             address(0),  // init 없음
 *             ""           // calldata 없음
 *         );
 *     }
 * }
 */

/**
 * ⚠️ 주의사항:
 *
 * 1. 재진입 보호
 *    - init 함수는 한 번만 실행되어야 함
 *    - 플래그를 사용하여 재진입 방지
 *
 * 2. 가스 한도
 *    - 초기화가 너무 복잡하면 가스 한도 초과 가능
 *    - 여러 단계로 나누거나 off-chain에서 일부 처리
 *
 * 3. 실패 처리
 *    - init이 실패하면 전체 DiamondCut이 revert
 *    - 철저한 테스트 필요
 *
 * 4. Storage 접근
 *    - delegatecall로 실행되므로 Diamond의 storage 사용
 *    - AppStorage 패턴 준수 필수
 *
 * 5. 보안
 *    - init 함수는 외부에서 직접 호출되어서는 안 됨
 *    - DiamondCut을 통해서만 호출되도록 설계
 */
