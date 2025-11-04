// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDiamondLoupe
 * @notice Diamond의 Facet 정보를 조회하는 인터페이스
 * @dev EIP-2535에서 정의한 필수 인터페이스
 *
 * Diamond의 투명성을 제공하기 위한 인터페이스입니다.
 * 이를 통해 사용자는 Diamond가 어떤 함수를 지원하는지,
 * 각 함수가 어떤 Facet에 구현되어 있는지 확인할 수 있습니다.
 */
interface IDiamondLoupe {

    /**
     * @notice Facet 정보를 담는 구조체
     * @param facetAddress Facet의 컨트랙트 주소
     * @param functionSelectors 해당 Facet이 제공하는 함수 selector 배열
     */
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /**
     * @notice 모든 Facet과 함수 정보 조회
     * @return facets_ Facet 배열 (주소와 함수 selector 목록)
     *
     * @dev 사용 예시:
     * ```
     * IDiamondLoupe.Facet[] memory allFacets = IDiamondLoupe(diamond).facets();
     * for (uint i = 0; i < allFacets.length; i++) {
     *     console.log("Facet:", allFacets[i].facetAddress);
     *     for (uint j = 0; j < allFacets[i].functionSelectors.length; j++) {
     *         console.log("  Selector:", allFacets[i].functionSelectors[j]);
     *     }
     * }
     * ```
     */
    function facets() external view returns (Facet[] memory facets_);

    /**
     * @notice 특정 Facet이 제공하는 모든 함수 selector 조회
     * @param _facet 조회할 Facet 주소
     * @return facetFunctionSelectors_ 함수 selector 배열
     *
     * @dev 사용 예시:
     * ```
     * bytes4[] memory selectors = IDiamondLoupe(diamond)
     *     .facetFunctionSelectors(address(erc20Facet));
     * // selectors = [0xa9059cbb, 0x095ea7b3, 0x23b872dd, ...]
     * ```
     */
    function facetFunctionSelectors(address _facet)
        external
        view
        returns (bytes4[] memory facetFunctionSelectors_);

    /**
     * @notice 등록된 모든 Facet 주소 조회
     * @return facetAddresses_ Facet 주소 배열
     *
     * @dev 사용 예시:
     * ```
     * address[] memory addresses = IDiamondLoupe(diamond).facetAddresses();
     * // addresses = [0xABC..., 0xDEF..., 0x123..., ...]
     * ```
     */
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /**
     * @notice 특정 함수 selector가 어떤 Facet에 구현되어 있는지 조회
     * @param _functionSelector 조회할 함수 selector
     * @return facetAddress_ Facet 주소
     *
     * @dev 사용 예시:
     * ```
     * // transfer 함수가 어디에 구현되어 있는지 확인
     * address facet = IDiamondLoupe(diamond)
     *     .facetAddress(bytes4(keccak256("transfer(address,uint256)")));
     * // facet = 0xABC... (ERC20Facet 주소)
     * ```
     */
    function facetAddress(bytes4 _functionSelector)
        external
        view
        returns (address facetAddress_);
}

/**
 * DiamondLoupe를 구현하는 Facet
 */
contract DiamondLoupeFacet is IDiamondLoupe {

    // LibDiamond의 storage 구조체 참조
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        mapping(address => bytes4[]) facetFunctionSelectors;
        address[] facetAddresses;
        address contractOwner;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice 모든 Facet과 함수 정보 조회
     */
    function facets() external view override returns (Facet[] memory facets_) {
        DiamondStorage storage ds = diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);

        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddress_];
        }
    }

    /**
     * @notice 특정 Facet이 제공하는 모든 함수 selector 조회
     */
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        DiamondStorage storage ds = diamondStorage();
        facetFunctionSelectors_ = ds.facetFunctionSelectors[_facet];
    }

    /**
     * @notice 등록된 모든 Facet 주소 조회
     */
    function facetAddresses()
        external
        view
        override
        returns (address[] memory facetAddresses_)
    {
        DiamondStorage storage ds = diamondStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /**
     * @notice 특정 함수 selector가 어떤 Facet에 구현되어 있는지 조회
     */
    function facetAddress(bytes4 _functionSelector)
        external
        view
        override
        returns (address facetAddress_)
    {
        DiamondStorage storage ds = diamondStorage();
        facetAddress_ = ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }
}

/**
 * 사용 예시:
 *
 * // === Diamond 정보 탐색 ===
 *
 * contract DiamondExplorer {
 *     function exploreDiamond(address diamond) external view {
 *         IDiamondLoupe loupe = IDiamondLoupe(diamond);
 *
 *         // 1. 모든 Facet 조회
 *         IDiamondLoupe.Facet[] memory allFacets = loupe.facets();
 *         console.log("Total Facets:", allFacets.length);
 *
 *         // 2. 각 Facet의 함수 출력
 *         for (uint i = 0; i < allFacets.length; i++) {
 *             console.log("\nFacet:", allFacets[i].facetAddress);
 *             console.log("Functions:", allFacets[i].functionSelectors.length);
 *
 *             for (uint j = 0; j < allFacets[i].functionSelectors.length; j++) {
 *                 bytes4 selector = allFacets[i].functionSelectors[j];
 *                 console.log("  -", bytes4ToString(selector));
 *             }
 *         }
 *
 *         // 3. 특정 함수가 어디에 있는지 확인
 *         bytes4 transferSelector = bytes4(keccak256("transfer(address,uint256)"));
 *         address transferFacet = loupe.facetAddress(transferSelector);
 *         console.log("\ntransfer() is in:", transferFacet);
 *     }
 *
 *     function bytes4ToString(bytes4 _bytes) internal pure returns (string memory) {
 *         bytes memory s = new bytes(8);
 *         for (uint i = 0; i < 4; i++) {
 *             bytes1 b = _bytes[i];
 *             bytes1 hi = bytes1(uint8(b) / 16);
 *             bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
 *             s[2*i] = char(hi);
 *             s[2*i+1] = char(lo);
 *         }
 *         return string(abi.encodePacked("0x", s));
 *     }
 *
 *     function char(bytes1 b) internal pure returns (bytes1 c) {
 *         if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
 *         else return bytes1(uint8(b) + 0x57);
 *     }
 * }
 *
 * // === 프론트엔드에서 사용 ===
 *
 * // JavaScript/TypeScript
 * const diamond = new ethers.Contract(diamondAddress, IDiamondLoupe.abi, provider);
 *
 * // 모든 Facet 정보 가져오기
 * const facets = await diamond.facets();
 * console.log("Facets:", facets);
 *
 * // 특정 함수가 어디에 있는지 확인
 * const transferSelector = ethers.utils.id("transfer(address,uint256)").slice(0, 10);
 * const facetAddress = await diamond.facetAddress(transferSelector);
 * console.log("transfer function is in:", facetAddress);
 *
 * // 모든 Facet 주소 가져오기
 * const addresses = await diamond.facetAddresses();
 * console.log("All facet addresses:", addresses);
 *
 * // === 보안 검증 ===
 *
 * contract DiamondVerifier {
 *     function verifyDiamond(address diamond) external view returns (bool) {
 *         IDiamondLoupe loupe = IDiamondLoupe(diamond);
 *
 *         // 1. diamondCut 함수가 존재하는지 확인
 *         bytes4 diamondCutSelector = bytes4(
 *             keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)")
 *         );
 *         address cutFacet = loupe.facetAddress(diamondCutSelector);
 *         require(cutFacet != address(0), "diamondCut not found");
 *
 *         // 2. 모든 Facet이 유효한 컨트랙트인지 확인
 *         address[] memory facetAddresses = loupe.facetAddresses();
 *         for (uint i = 0; i < facetAddresses.length; i++) {
 *             uint256 size;
 *             address facet = facetAddresses[i];
 *             assembly {
 *                 size := extcodesize(facet)
 *             }
 *             require(size > 0, "Invalid facet: no code");
 *         }
 *
 *         // 3. 중복된 함수 selector가 없는지 확인
 *         bytes4[] memory allSelectors;
 *         IDiamondLoupe.Facet[] memory allFacets = loupe.facets();
 *
 *         for (uint i = 0; i < allFacets.length; i++) {
 *             bytes4[] memory selectors = allFacets[i].functionSelectors;
 *             for (uint j = 0; j < selectors.length; j++) {
 *                 // 중복 확인 로직...
 *             }
 *         }
 *
 *         return true;
 *     }
 * }
 */
