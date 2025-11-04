// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "./LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

/**
 * @title DiamondCutFacet
 * @notice Diamond에 Facet을 추가/교체/제거하는 관리 Facet
 * @dev EIP-2535에서 정의한 DiamondCut 인터페이스 구현
 *
 * 주요 기능:
 * - Add: 새로운 함수를 Diamond에 추가
 * - Replace: 기존 함수의 구현을 다른 Facet으로 교체
 * - Remove: 함수를 Diamond에서 제거
 *
 * 보안:
 * - 오직 컨트랙트 소유자만 호출 가능
 * - 잘못된 작업은 revert
 */
contract DiamondCutFacet is IDiamondCut {

    /**
     * @notice Facet 추가/교체/제거를 수행하는 메인 함수
     * @param _diamondCut 수행할 작업 배열 (여러 작업을 한 번에 처리 가능)
     * @param _init 초기화 컨트랙트 주소 (선택사항)
     * @param _calldata 초기화 함수 호출 데이터 (선택사항)
     *
     * @dev 작동 방식:
     * 1. 소유자 권한 확인
     * 2. 각 FacetCut 작업을 순서대로 처리
     * 3. DiamondCut 이벤트 발생
     * 4. 초기화 함수가 제공된 경우 실행
     *
     * 예시 1: 새 Facet 추가
     * ```
     * FacetCut[] memory cuts = new FacetCut[](1);
     * cuts[0] = FacetCut({
     *     facetAddress: address(newFacet),
     *     action: FacetCutAction.Add,
     *     functionSelectors: [selector1, selector2, selector3]
     * });
     * diamondCut(cuts, address(0), "");
     * ```
     *
     * 예시 2: 함수 교체 (업그레이드)
     * ```
     * FacetCut[] memory cuts = new FacetCut[](1);
     * cuts[0] = FacetCut({
     *     facetAddress: address(upgradedFacet),
     *     action: FacetCutAction.Replace,
     *     functionSelectors: [existingSelector]
     * });
     * diamondCut(cuts, address(0), "");
     * ```
     *
     * 예시 3: 함수 제거
     * ```
     * FacetCut[] memory cuts = new FacetCut[](1);
     * cuts[0] = FacetCut({
     *     facetAddress: address(0),  // Remove 시에는 무시됨
     *     action: FacetCutAction.Remove,
     *     functionSelectors: [selectorToRemove]
     * });
     * diamondCut(cuts, address(0), "");
     * ```
     *
     * 예시 4: 초기화와 함께 추가
     * ```
     * DiamondInit initContract = new DiamondInit();
     * bytes memory initData = abi.encodeWithSelector(
     *     DiamondInit.init.selector,
     *     "arg1",
     *     "arg2"
     * );
     *
     * diamondCut(cuts, address(initContract), initData);
     * ```
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        // 소유자만 호출 가능
        LibDiamond.enforceIsContractOwner();

        // LibDiamond의 diamondCut 함수로 실제 작업 수행
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}

/**
 * 상세 사용 예시:
 *
 * // === 시나리오 1: ERC20 토큰 기능 추가 ===
 *
 * // 1. ERC20Facet 배포
 * ERC20Facet erc20Facet = new ERC20Facet();
 *
 * // 2. 추가할 함수 selector 준비
 * bytes4[] memory selectors = new bytes4[](6);
 * selectors[0] = ERC20Facet.transfer.selector;
 * selectors[1] = ERC20Facet.transferFrom.selector;
 * selectors[2] = ERC20Facet.approve.selector;
 * selectors[3] = ERC20Facet.balanceOf.selector;
 * selectors[4] = ERC20Facet.allowance.selector;
 * selectors[5] = ERC20Facet.totalSupply.selector;
 *
 * // 3. FacetCut 생성
 * IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
 * cuts[0] = IDiamondCut.FacetCut({
 *     facetAddress: address(erc20Facet),
 *     action: IDiamondCut.FacetCutAction.Add,
 *     functionSelectors: selectors
 * });
 *
 * // 4. 초기화 데이터 준비
 * DiamondInit init = new DiamondInit();
 * bytes memory initData = abi.encodeWithSelector(
 *     DiamondInit.init.selector,
 *     "MyToken",
 *     "MTK",
 *     18
 * );
 *
 * // 5. DiamondCut 실행
 * IDiamondCut(diamond).diamondCut(cuts, address(init), initData);
 *
 * // === 시나리오 2: 버그 수정 (함수 교체) ===
 *
 * // 1. 버그가 있는 함수의 selector
 * bytes4 buggySelector = ERC20Facet.transfer.selector;
 *
 * // 2. 수정된 Facet 배포
 * ERC20FacetV2 fixedFacet = new ERC20FacetV2();
 *
 * // 3. 교체 작업 생성
 * IDiamondCut.FacetCut[] memory fixes = new IDiamondCut.FacetCut[](1);
 * fixes[0] = IDiamondCut.FacetCut({
 *     facetAddress: address(fixedFacet),
 *     action: IDiamondCut.FacetCutAction.Replace,
 *     functionSelectors: [buggySelector]
 * });
 *
 * // 4. 교체 실행 (초기화 불필요)
 * IDiamondCut(diamond).diamondCut(fixes, address(0), "");
 *
 * // === 시나리오 3: 기능 제거 (deprecated) ===
 *
 * // 1. 제거할 함수 selector
 * bytes4[] memory selectorsToRemove = new bytes4[](2);
 * selectorsToRemove[0] = bytes4(keccak256("oldFunction1()"));
 * selectorsToRemove[1] = bytes4(keccak256("oldFunction2()"));
 *
 * // 2. 제거 작업 생성
 * IDiamondCut.FacetCut[] memory removals = new IDiamondCut.FacetCut[](1);
 * removals[0] = IDiamondCut.FacetCut({
 *     facetAddress: address(0),  // Remove 시에는 사용되지 않음
 *     action: IDiamondCut.FacetCutAction.Remove,
 *     functionSelectors: selectorsToRemove
 * });
 *
 * // 3. 제거 실행
 * IDiamondCut(diamond).diamondCut(removals, address(0), "");
 *
 * // === 시나리오 4: 복합 작업 (추가 + 교체 + 제거) ===
 *
 * IDiamondCut.FacetCut[] memory multiCuts = new IDiamondCut.FacetCut[](3);
 *
 * // 새 기능 추가
 * multiCuts[0] = IDiamondCut.FacetCut({
 *     facetAddress: address(newFacet),
 *     action: IDiamondCut.FacetCutAction.Add,
 *     functionSelectors: newSelectors
 * });
 *
 * // 기존 기능 업그레이드
 * multiCuts[1] = IDiamondCut.FacetCut({
 *     facetAddress: address(upgradedFacet),
 *     action: IDiamondCut.FacetCutAction.Replace,
 *     functionSelectors: upgradeSelectors
 * });
 *
 * // 오래된 기능 제거
 * multiCuts[2] = IDiamondCut.FacetCut({
 *     facetAddress: address(0),
 *     action: IDiamondCut.FacetCutAction.Remove,
 *     functionSelectors: deprecatedSelectors
 * });
 *
 * // 한 번에 실행
 * IDiamondCut(diamond).diamondCut(multiCuts, address(0), "");
 */

/**
 * 주의사항:
 *
 * 1. 함수 selector 충돌
 *    - 같은 selector를 가진 함수는 추가 불가
 *    - 함수명이 다르더라도 selector가 같으면 충돌 발생 가능
 *
 * 2. Storage 충돌
 *    - 모든 Facet은 동일한 storage 레이아웃을 공유해야 함
 *    - AppStorage 패턴 사용 권장
 *
 * 3. 권한 관리
 *    - diamondCut()은 매우 강력한 함수
 *    - 반드시 안전한 소유자 관리 메커니즘 필요
 *    - 멀티시그 또는 타임락 사용 권장
 *
 * 4. 테스트
 *    - 프로덕션 배포 전 철저한 테스트 필수
 *    - 각 FacetCutAction별로 테스트
 *    - 초기화 함수도 반드시 테스트
 *
 * 5. 가스 최적화
 *    - 한 번에 여러 작업을 수행하는 것이 가스 효율적
 *    - selector 배열이 너무 크면 가스 한도 초과 가능
 */
