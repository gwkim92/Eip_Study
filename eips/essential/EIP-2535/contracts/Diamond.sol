// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "./LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

/**
 * @title Diamond
 * @notice EIP-2535 Diamond Standard의 메인 프록시 컨트랙트
 * @dev 모든 외부 호출의 진입점이 되며, 적절한 Facet으로 라우팅
 *
 * 동작 방식:
 * 1. 사용자가 diamond.transfer(to, amount) 호출
 * 2. fallback()이 msg.sig를 확인 (0xa9059cbb)
 * 3. DiamondStorage에서 해당 selector의 Facet 주소 조회
 * 4. 찾은 Facet으로 delegatecall 실행
 * 5. Facet의 함수가 Diamond의 storage 컨텍스트에서 실행
 *
 * 예시:
 * Diamond (0x123...)
 *   ↓ delegatecall
 *   ERC20Facet (0xABC...)
 *     → transfer() 실행
 *     → Diamond의 storage에 접근
 */
contract Diamond {

    /**
     * @notice Diamond 생성자
     * @param _contractOwner 컨트랙트 소유자 주소
     * @param _diamondCutFacet DiamondCut Facet 주소 (필수)
     *
     * @dev 생성자에서 수행하는 작업:
     * 1. 소유자 설정
     * 2. DiamondCut Facet 등록 (Facet 관리를 위해 필수)
     */
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        // 소유자 설정
        LibDiamond.setContractOwner(_contractOwner);

        // DiamondCut Facet 추가
        // diamondCut() 함수를 사용할 수 있도록 등록
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;

        LibDiamond.addFunctions(_diamondCutFacet, functionSelectors);
    }

    /**
     * @notice 모든 함수 호출을 처리하는 fallback
     * @dev Diamond의 핵심 라우팅 로직
     *
     * 처리 과정:
     * 1. msg.sig (함수 selector) 추출
     * 2. DiamondStorage에서 해당 selector의 Facet 주소 조회
     * 3. Facet 주소가 없으면 revert
     * 4. Facet으로 delegatecall 실행
     * 5. Facet의 return data를 caller에게 반환
     *
     * delegatecall 특징:
     * - msg.sender, msg.value는 원래 호출자의 값 유지
     * - Facet의 코드를 실행하지만 Diamond의 storage 사용
     * - Facet에서 storage를 수정하면 Diamond의 storage가 변경됨
     */
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;

        // Diamond Storage 위치 가져오기
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }

        // msg.sig (함수 selector)로 Facet 주소 조회
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;

        // Facet이 등록되어 있지 않으면 에러
        require(facet != address(0), "Diamond: Function does not exist");

        // Facet으로 delegatecall 실행
        assembly {
            // calldata를 메모리에 복사
            // calldatacopy(t, f, s): memory 위치 t에 calldata f부터 s 바이트 복사
            calldatacopy(0, 0, calldatasize())

            // delegatecall 실행
            // delegatecall(g, a, in, insize, out, outsize)
            // g: gas, a: 주소, in: input 시작, insize: input 크기,
            // out: output 시작, outsize: output 크기
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)

            // return data를 메모리에 복사
            returndatacopy(0, 0, returndatasize())

            // delegatecall 결과에 따라 처리
            switch result
            case 0 {
                // 실패: revert with return data
                revert(0, returndatasize())
            }
            default {
                // 성공: return with return data
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice ETH를 받을 수 있도록 하는 receive 함수
     * @dev payable Diamond을 만들려면 필요
     */
    receive() external payable {}
}

/**
 * 사용 예시:
 *
 * // 1. Diamond 배포
 * DiamondCutFacet cutFacet = new DiamondCutFacet();
 * Diamond diamond = new Diamond(owner, address(cutFacet));
 *
 * // 2. Facet 추가
 * ERC20Facet erc20Facet = new ERC20Facet();
 * bytes4[] memory selectors = [
 *     ERC20Facet.transfer.selector,
 *     ERC20Facet.balanceOf.selector
 * ];
 *
 * IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
 * cuts[0] = IDiamondCut.FacetCut({
 *     facetAddress: address(erc20Facet),
 *     action: IDiamondCut.FacetCutAction.Add,
 *     functionSelectors: selectors
 * });
 *
 * IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");
 *
 * // 3. Diamond를 ERC20처럼 사용
 * IERC20(address(diamond)).transfer(recipient, amount);
 *
 * // 내부 동작:
 * // Diamond.fallback()
 * //   → msg.sig = 0xa9059cbb (transfer selector)
 * //   → DiamondStorage에서 조회
 * //   → ERC20Facet 주소 반환
 * //   → delegatecall(ERC20Facet, calldata)
 * //   → ERC20Facet.transfer() 실행 (Diamond의 storage 사용)
 */
