// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibDiamond
 * @notice Diamond Storage를 관리하는 핵심 라이브러리
 * @dev EIP-2535 Diamond Standard의 핵심 구현
 *
 * 주요 기능:
 * - Diamond Storage 접근 및 관리
 * - Facet 추가/교체/제거 함수
 * - 함수 selector 매핑 관리
 * - 소유자 권한 관리
 */
library LibDiamond {

    // ============================================
    // Storage
    // ============================================

    /**
     * @notice Diamond Storage의 고정된 스토리지 슬롯 위치
     * @dev keccak256을 사용하여 충돌하지 않는 위치 확보
     */
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    /**
     * @notice Facet 주소와 함수 selector의 위치 정보
     * @param facetAddress Facet 컨트랙트의 주소
     * @param functionSelectorPosition facetFunctionSelectors 배열에서의 인덱스
     */
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    /**
     * @notice Diamond의 모든 매핑 정보를 담는 Storage 구조체
     * @dev 이 구조체는 고정된 스토리지 슬롯에 저장됨
     */
    struct DiamondStorage {
        // 함수 selector → Facet 정보 매핑
        // 예: transfer.selector (0xa9059cbb) → { facetAddress: 0xABC..., position: 0 }
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;

        // Facet 주소 → 해당 Facet의 모든 함수 selector 배열
        // 예: 0xABC... → [0xa9059cbb, 0x095ea7b3, 0x23b872dd]
        mapping(address => bytes4[]) facetFunctionSelectors;

        // 등록된 모든 Facet 주소 목록
        address[] facetAddresses;

        // 컨트랙트 소유자 (DiamondCut 권한을 가짐)
        address contractOwner;
    }

    // ============================================
    // Events
    // ============================================

    /**
     * @notice Facet 추가/교체/제거 시 발생하는 이벤트
     * @param _diamondCut 수행된 FacetCut 작업 배열
     * @param _init 초기화 함수가 호출된 컨트랙트 주소
     * @param _calldata 초기화 함수에 전달된 calldata
     */
    event DiamondCut(
        FacetCut[] _diamondCut,
        address _init,
        bytes _calldata
    );

    /**
     * @notice 소유자 변경 시 발생하는 이벤트
     * @param previousOwner 이전 소유자
     * @param newOwner 새로운 소유자
     */
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // ============================================
    // Enums & Structs
    // ============================================

    /**
     * @notice DiamondCut에서 수행할 작업 유형
     * @dev Add: 새 함수 추가, Replace: 기존 함수 교체, Remove: 함수 제거
     */
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /**
     * @notice DiamondCut 작업을 정의하는 구조체
     * @param facetAddress 대상 Facet의 주소 (Remove 시에는 무시됨)
     * @param action 수행할 작업 유형 (Add/Replace/Remove)
     * @param functionSelectors 대상 함수들의 selector 배열
     */
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    // ============================================
    // Storage Access
    // ============================================

    /**
     * @notice Diamond Storage에 접근하는 함수
     * @dev assembly를 사용하여 특정 슬롯에 직접 접근
     * @return ds DiamondStorage 구조체의 storage 포인터
     */
    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    // ============================================
    // Ownership Functions
    // ============================================

    /**
     * @notice 컨트랙트 소유자 설정
     * @param _newOwner 새로운 소유자 주소
     */
    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @notice 현재 소유자 조회
     * @return contractOwner_ 소유자 주소
     */
    function contractOwner()
        internal
        view
        returns (address contractOwner_)
    {
        contractOwner_ = diamondStorage().contractOwner;
    }

    /**
     * @notice 소유자만 호출 가능하도록 검증
     * @dev 소유자가 아니면 revert
     */
    function enforceIsContractOwner() internal view {
        require(
            msg.sender == diamondStorage().contractOwner,
            "LibDiamond: Must be contract owner"
        );
    }

    // ============================================
    // DiamondCut Functions
    // ============================================

    /**
     * @notice DiamondCut 작업 수행 (Facet 추가/교체/제거)
     * @param _diamondCut 수행할 FacetCut 작업 배열
     * @param _init 초기화 컨트랙트 주소 (선택사항)
     * @param _calldata 초기화 함수 호출 데이터 (선택사항)
     */
    function diamondCut(
        FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            FacetCutAction action = _diamondCut[facetIndex].action;

            if (action == FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert("LibDiamond: Incorrect FacetCutAction");
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);

        // 초기화 함수 실행 (제공된 경우)
        initializeDiamondCut(_init, _calldata);
    }

    /**
     * @notice 새로운 함수들을 Diamond에 추가
     * @param _facetAddress 추가할 Facet의 주소
     * @param _functionSelectors 추가할 함수 selector 배열
     */
    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "LibDiamond: No selectors in facet to cut"
        );
        DiamondStorage storage ds = diamondStorage();

        require(
            _facetAddress != address(0),
            "LibDiamond: Add facet can't be address(0)"
        );

        // Facet이 컨트랙트인지 확인
        uint96 selectorPosition = uint96(
            ds.facetFunctionSelectors[_facetAddress].length
        );

        // 새로운 Facet인 경우 facetAddresses 배열에 추가
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        // 각 함수 selector 등록
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;

            require(
                oldFacetAddress == address(0),
                "LibDiamond: Can't add function that already exists"
            );

            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @notice 기존 함수들을 새로운 Facet으로 교체
     * @param _facetAddress 교체할 Facet의 주소
     * @param _functionSelectors 교체할 함수 selector 배열
     */
    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "LibDiamond: No selectors in facet to cut"
        );
        DiamondStorage storage ds = diamondStorage();

        require(
            _facetAddress != address(0),
            "LibDiamond: Replace facet can't be address(0)"
        );

        uint96 selectorPosition = uint96(
            ds.facetFunctionSelectors[_facetAddress].length
        );

        // 새로운 Facet인 경우 추가
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        // 각 함수 selector 교체
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;

            require(
                oldFacetAddress != _facetAddress,
                "LibDiamond: Can't replace function with same function"
            );

            require(
                oldFacetAddress != address(0),
                "LibDiamond: Can't replace function that doesn't exist"
            );

            // 기존 함수 제거
            removeFunction(ds, oldFacetAddress, selector);

            // 새로운 함수 추가
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @notice Diamond에서 함수들 제거
     * @param _facetAddress 사용되지 않음 (호환성을 위해 유지)
     * @param _functionSelectors 제거할 함수 selector 배열
     */
    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "LibDiamond: No selectors in facet to cut"
        );
        DiamondStorage storage ds = diamondStorage();

        require(
            _facetAddress == address(0),
            "LibDiamond: Remove facet address must be address(0)"
        );

        // 각 함수 selector 제거
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;

            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    // ============================================
    // Internal Helper Functions
    // ============================================

    /**
     * @notice 새로운 Facet을 facetAddresses 배열에 추가
     * @param ds DiamondStorage 포인터
     * @param _facetAddress 추가할 Facet 주소
     */
    function addFacet(
        DiamondStorage storage ds,
        address _facetAddress
    ) internal {
        enforceHasContractCode(
            _facetAddress,
            "LibDiamond: New facet has no code"
        );
        ds.facetAddresses.push(_facetAddress);
    }

    /**
     * @notice 함수 selector를 Diamond에 등록
     * @param ds DiamondStorage 포인터
     * @param _selector 등록할 함수 selector
     * @param _selectorPosition selector 배열에서의 위치
     * @param _facetAddress Facet 주소
     */
    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds
            .selectorToFacetAndPosition[_selector]
            .functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    /**
     * @notice Diamond에서 함수 selector 제거
     * @param ds DiamondStorage 포인터
     * @param _facetAddress 제거할 함수가 속한 Facet 주소
     * @param _selector 제거할 함수 selector
     */
    function removeFunction(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        require(
            _facetAddress != address(0),
            "LibDiamond: Can't remove function that doesn't exist"
        );

        // immutable 함수는 제거 불가
        require(
            _facetAddress != address(this),
            "LibDiamond: Can't remove immutable function"
        );

        // selector 배열에서 제거 (마지막 요소와 swap 후 pop)
        uint256 selectorPosition = ds
            .selectorToFacetAndPosition[_selector]
            .functionSelectorPosition;
        uint256 lastSelectorPosition = ds
            .facetFunctionSelectors[_facetAddress].length - 1;

        // 제거할 selector와 마지막 selector가 다른 경우 swap
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress][
                lastSelectorPosition
            ];
            ds.facetFunctionSelectors[_facetAddress][
                selectorPosition
            ] = lastSelector;
            ds
                .selectorToFacetAndPosition[lastSelector]
                .functionSelectorPosition = uint96(selectorPosition);
        }

        // 마지막 요소 제거
        ds.facetFunctionSelectors[_facetAddress].pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // Facet에 함수가 없으면 Facet도 제거
        if (lastSelectorPosition == 0) {
            // facetAddresses 배열에서 제거
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition;

            // 제거할 Facet의 위치 찾기
            for (uint256 i; i < ds.facetAddresses.length; i++) {
                if (ds.facetAddresses[i] == _facetAddress) {
                    facetAddressPosition = i;
                    break;
                }
            }

            // 마지막 요소와 swap 후 pop
            if (facetAddressPosition != lastFacetAddressPosition) {
                ds.facetAddresses[facetAddressPosition] = ds.facetAddresses[
                    lastFacetAddressPosition
                ];
            }
            ds.facetAddresses.pop();
        }
    }

    /**
     * @notice 초기화 함수 실행
     * @param _init 초기화 컨트랙트 주소
     * @param _calldata 초기화 함수 호출 데이터
     */
    function initializeDiamondCut(
        address _init,
        bytes memory _calldata
    ) internal {
        if (_init == address(0)) {
            return;
        }

        enforceHasContractCode(
            _init,
            "LibDiamond: _init address has no code"
        );

        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert("LibDiamond: _init function reverted");
            }
        }
    }

    /**
     * @notice 주소에 컨트랙트 코드가 있는지 확인
     * @param _contract 확인할 주소
     * @param _errorMessage 에러 시 메시지
     */
    function enforceHasContractCode(
        address _contract,
        string memory _errorMessage
    ) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}
