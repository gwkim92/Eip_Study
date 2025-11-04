// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDiamondCut
 * @notice EIP-2535 Diamond Standard의 DiamondCut 인터페이스
 * @dev Diamond에 Facet을 추가/교체/제거하는 표준 인터페이스
 *
 * 이 인터페이스는 EIP-2535에서 정의한 필수 인터페이스입니다.
 * 모든 Diamond 구현은 이 인터페이스를 지원해야 합니다.
 */
interface IDiamondCut {

    /**
     * @notice FacetCut 작업 유형을 정의하는 enum
     * @dev Add: 새 함수 추가, Replace: 기존 함수 교체, Remove: 함수 제거
     */
    enum FacetCutAction {
        Add,     // 0: 새로운 함수를 Diamond에 추가
        Replace, // 1: 기존 함수의 구현을 다른 Facet으로 교체
        Remove   // 2: 함수를 Diamond에서 제거
    }

    /**
     * @notice Facet 작업을 정의하는 구조체
     * @param facetAddress 대상 Facet의 주소 (Remove 시에는 address(0))
     * @param action 수행할 작업 유형 (Add/Replace/Remove)
     * @param functionSelectors 대상 함수들의 selector 배열
     *
     * @dev 예시:
     * ```
     * FacetCut memory cut = FacetCut({
     *     facetAddress: 0xABC...,
     *     action: FacetCutAction.Add,
     *     functionSelectors: [0xa9059cbb, 0x095ea7b3, 0x23b872dd]
     * });
     * ```
     */
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /**
     * @notice DiamondCut 이벤트
     * @param _diamondCut 수행된 FacetCut 작업 배열
     * @param _init 초기화 함수가 호출된 컨트랙트 주소
     * @param _calldata 초기화 함수에 전달된 calldata
     *
     * @dev 모든 DiamondCut 작업 후 발생해야 하는 이벤트
     * off-chain에서 Diamond의 변경 사항을 추적하는 데 사용
     */
    event DiamondCut(
        FacetCut[] _diamondCut,
        address _init,
        bytes _calldata
    );

    /**
     * @notice Diamond에 Facet을 추가/교체/제거
     * @param _diamondCut 수행할 FacetCut 작업 배열
     * @param _init 초기화 컨트랙트 주소 (선택사항, 없으면 address(0))
     * @param _calldata 초기화 함수 호출 데이터 (선택사항, 없으면 "")
     *
     * @dev 함수 동작:
     * 1. _diamondCut 배열의 각 작업을 순서대로 처리
     * 2. DiamondCut 이벤트 발생
     * 3. _init이 address(0)이 아니면 초기화 함수 실행
     *
     * 제약사항:
     * - 오직 컨트랙트 소유자만 호출 가능
     * - Add: 이미 존재하는 함수는 추가 불가
     * - Replace: 존재하지 않는 함수는 교체 불가
     * - Remove: facetAddress는 반드시 address(0)이어야 함
     *
     * 사용 예시:
     * ```
     * // 1. FacetCut 배열 생성
     * IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
     * cuts[0] = IDiamondCut.FacetCut({
     *     facetAddress: address(newFacet),
     *     action: IDiamondCut.FacetCutAction.Add,
     *     functionSelectors: [selector1, selector2]
     * });
     *
     * // 2. 초기화 데이터 준비 (선택사항)
     * bytes memory initData = abi.encodeWithSelector(
     *     InitContract.init.selector,
     *     arg1,
     *     arg2
     * );
     *
     * // 3. DiamondCut 실행
     * IDiamondCut(diamond).diamondCut(cuts, address(initContract), initData);
     * ```
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}

/**
 * 상세 가이드:
 *
 * === Add (새 함수 추가) ===
 *
 * 언제 사용:
 * - 새로운 기능을 Diamond에 추가할 때
 * - 새로운 Facet을 배포하고 그 함수들을 등록할 때
 *
 * 요구사항:
 * - facetAddress는 유효한 컨트랙트 주소여야 함
 * - functionSelectors에 포함된 selector들이 아직 등록되지 않아야 함
 * - functionSelectors 배열은 비어있지 않아야 함
 *
 * 예시:
 * ```
 * FacetCut memory addCut = FacetCut({
 *     facetAddress: address(newFacet),
 *     action: FacetCutAction.Add,
 *     functionSelectors: [
 *         bytes4(keccak256("newFunction1()")),
 *         bytes4(keccak256("newFunction2(uint256)"))
 *     ]
 * });
 * ```
 *
 * === Replace (기존 함수 교체) ===
 *
 * 언제 사용:
 * - 버그를 수정할 때
 * - 기능을 업그레이드할 때
 * - 로직을 개선할 때
 *
 * 요구사항:
 * - facetAddress는 유효한 컨트랙트 주소여야 함
 * - functionSelectors에 포함된 selector들이 이미 등록되어 있어야 함
 * - 같은 Facet 주소로는 교체 불가 (의미 없음)
 *
 * 예시:
 * ```
 * FacetCut memory replaceCut = FacetCut({
 *     facetAddress: address(upgradedFacet),
 *     action: FacetCutAction.Replace,
 *     functionSelectors: [
 *         OldFacet.buggyFunction.selector
 *     ]
 * });
 * ```
 *
 * === Remove (함수 제거) ===
 *
 * 언제 사용:
 * - 더 이상 사용하지 않는 기능을 제거할 때
 * - 보안 문제가 있는 함수를 비활성화할 때
 * - 컨트랙트 크기를 줄이고 싶을 때
 *
 * 요구사항:
 * - facetAddress는 반드시 address(0)이어야 함
 * - functionSelectors에 포함된 selector들이 이미 등록되어 있어야 함
 * - immutable 함수(Diamond 자체의 함수)는 제거 불가
 *
 * 예시:
 * ```
 * FacetCut memory removeCut = FacetCut({
 *     facetAddress: address(0),  // 반드시 0 주소
 *     action: FacetCutAction.Remove,
 *     functionSelectors: [
 *         bytes4(keccak256("deprecatedFunction()"))
 *     ]
 * });
 * ```
 *
 * === 초기화 함수 ===
 *
 * 언제 사용:
 * - Facet 추가 후 초기 설정이 필요할 때
 * - 여러 변수를 한 번에 설정해야 할 때
 * - 마이그레이션 로직이 필요할 때
 *
 * 주의사항:
 * - 초기화 함수는 delegatecall로 실행됨
 * - 초기화 함수는 한 번만 실행되도록 설계해야 함
 * - 초기화가 필요없으면 address(0)과 "" 전달
 *
 * 예시:
 * ```
 * // InitContract.sol
 * contract DiamondInit {
 *     function init(string memory name, string memory symbol) external {
 *         AppStorage storage s;
 *         assembly { s.slot := 0 }
 *         s.name = name;
 *         s.symbol = symbol;
 *         s.decimals = 18;
 *     }
 * }
 *
 * // 사용
 * bytes memory initData = abi.encodeWithSelector(
 *     DiamondInit.init.selector,
 *     "MyToken",
 *     "MTK"
 * );
 * diamondCut(cuts, address(diamondInit), initData);
 * ```
 *
 * === 복합 작업 ===
 *
 * 여러 작업을 한 번에 수행할 수 있습니다:
 * ```
 * FacetCut[] memory cuts = new FacetCut[](3);
 *
 * cuts[0] = FacetCut({
 *     facetAddress: address(facetA),
 *     action: FacetCutAction.Add,
 *     functionSelectors: newSelectors
 * });
 *
 * cuts[1] = FacetCut({
 *     facetAddress: address(facetB),
 *     action: FacetCutAction.Replace,
 *     functionSelectors: upgradeSelectors
 * });
 *
 * cuts[2] = FacetCut({
 *     facetAddress: address(0),
 *     action: FacetCutAction.Remove,
 *     functionSelectors: removeSelectors
 * });
 *
 * diamondCut(cuts, address(0), "");
 * ```
 */
