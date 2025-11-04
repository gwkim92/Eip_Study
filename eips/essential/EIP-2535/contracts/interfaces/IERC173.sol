// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC173
 * @notice 컨트랙트 소유권 관리를 위한 표준 인터페이스
 * @dev ERC-173: Contract Ownership Standard
 *
 * Diamond Pattern에서 소유권 관리에 사용됩니다.
 * EIP-2535는 이 인터페이스 구현을 권장합니다.
 */
interface IERC173 {

    /**
     * @notice 소유권 이전 이벤트
     * @param previousOwner 이전 소유자
     * @param newOwner 새로운 소유자
     */
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @notice 현재 소유자 조회
     * @return owner_ 소유자 주소
     */
    function owner() external view returns (address owner_);

    /**
     * @notice 소유권 이전
     * @param _newOwner 새로운 소유자 주소
     *
     * @dev 오직 현재 소유자만 호출 가능
     * address(0)으로 이전하면 소유권 포기
     */
    function transferOwnership(address _newOwner) external;
}

/**
 * @title OwnershipFacet
 * @notice ERC173 인터페이스를 구현하는 Facet
 * @dev Diamond의 소유권 관리 기능 제공
 */
contract OwnershipFacet is IERC173 {

    struct DiamondStorage {
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
     * @notice 현재 소유자 조회
     */
    function owner() external view override returns (address owner_) {
        owner_ = diamondStorage().contractOwner;
    }

    /**
     * @notice 소유권 이전
     * @param _newOwner 새로운 소유자 주소
     */
    function transferOwnership(address _newOwner) external override {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;

        require(msg.sender == previousOwner, "OwnershipFacet: Must be owner");
        require(_newOwner != address(0), "OwnershipFacet: New owner is zero address");

        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }
}

/**
 * 사용 예시:
 *
 * // === 기본 사용 ===
 *
 * contract UseDiamond {
 *     function checkOwner(address diamond) external view returns (address) {
 *         return IERC173(diamond).owner();
 *     }
 *
 *     function changeOwner(address diamond, address newOwner) external {
 *         IERC173(diamond).transferOwnership(newOwner);
 *     }
 * }
 *
 * // === 멀티시그와 함께 사용 ===
 *
 * contract MultiSigOwnership {
 *     address public diamond;
 *     mapping(address => bool) public signers;
 *     uint256 public requiredSignatures = 2;
 *
 *     struct OwnershipTransfer {
 *         address newOwner;
 *         uint256 confirmations;
 *         mapping(address => bool) confirmed;
 *     }
 *
 *     OwnershipTransfer public pendingTransfer;
 *
 *     function proposeOwnershipTransfer(address newOwner) external {
 *         require(signers[msg.sender], "Not a signer");
 *
 *         pendingTransfer.newOwner = newOwner;
 *         pendingTransfer.confirmations = 1;
 *         pendingTransfer.confirmed[msg.sender] = true;
 *     }
 *
 *     function confirmOwnershipTransfer() external {
 *         require(signers[msg.sender], "Not a signer");
 *         require(!pendingTransfer.confirmed[msg.sender], "Already confirmed");
 *
 *         pendingTransfer.confirmed[msg.sender] = true;
 *         pendingTransfer.confirmations++;
 *
 *         if (pendingTransfer.confirmations >= requiredSignatures) {
 *             IERC173(diamond).transferOwnership(pendingTransfer.newOwner);
 *         }
 *     }
 * }
 *
 * // === 타임락과 함께 사용 ===
 *
 * contract TimelockOwnership {
 *     address public diamond;
 *     uint256 public constant TIMELOCK_DURATION = 2 days;
 *
 *     struct PendingTransfer {
 *         address newOwner;
 *         uint256 executeTime;
 *     }
 *
 *     PendingTransfer public pending;
 *
 *     function proposeOwnershipTransfer(address newOwner) external {
 *         require(msg.sender == IERC173(diamond).owner(), "Not owner");
 *
 *         pending.newOwner = newOwner;
 *         pending.executeTime = block.timestamp + TIMELOCK_DURATION;
 *     }
 *
 *     function executeOwnershipTransfer() external {
 *         require(pending.newOwner != address(0), "No pending transfer");
 *         require(block.timestamp >= pending.executeTime, "Timelock not expired");
 *
 *         IERC173(diamond).transferOwnership(pending.newOwner);
 *
 *         delete pending;
 *     }
 * }
 */
