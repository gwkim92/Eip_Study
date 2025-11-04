// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1271.sol";

/**
 * @title EIP1271Example
 * @dev EIP-1271의 기본 구현 예제: 단일 소유자 지갑
 * @dev Basic implementation example of EIP-1271: Single owner wallet
 *
 * 이 컨트랙트는 하나의 소유자를 가지며, 소유자의 서명만을 유효한 것으로 인정합니다.
 * This contract has a single owner and only recognizes the owner's signature as valid.
 */
contract EIP1271Example is IERC1271 {
    // 컨트랙트 소유자 주소
    // Contract owner address
    address public owner;

    // Magic value for EIP-1271
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    /**
     * @dev 소유자 변경 이벤트
     * @dev Owner change event
     */
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev 서명 검증 이벤트
     * @dev Signature validation event
     */
    event SignatureValidated(bytes32 indexed hash, bool isValid);

    /**
     * @dev 생성자: 배포자를 초기 소유자로 설정
     * @dev Constructor: Set deployer as initial owner
     */
    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }

    /**
     * @dev 소유자만 호출 가능한 modifier
     * @dev Modifier to restrict access to owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @dev EIP-1271 서명 검증 구현
     * @dev Implementation of EIP-1271 signature verification
     *
     * @param hash 서명된 메시지 해시
     * @param hash Hash of the signed message
     *
     * @param signature 서명 데이터 (v, r, s를 포함한 65바이트)
     * @param signature Signature data (65 bytes containing v, r, s)
     *
     * @return magicValue 유효한 서명이면 0x1626ba7e, 그렇지 않으면 0xffffffff
     * @return magicValue 0x1626ba7e if valid, 0xffffffff otherwise
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
        // 서명 길이 확인 (65바이트: r(32) + s(32) + v(1))
        // Check signature length (65 bytes: r(32) + s(32) + v(1))
        require(signature.length == 65, "Invalid signature length");

        // 서명에서 r, s, v 추출
        // Extract r, s, v from signature
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // 첫 32바이트는 배열 길이, 그 다음부터 실제 데이터
            // First 32 bytes is array length, actual data starts after
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        // v 값 조정 (27 또는 28이어야 함)
        // Adjust v value (must be 27 or 28)
        if (v < 27) {
            v += 27;
        }

        // ecrecover로 서명자 복구
        // Recover signer using ecrecover
        address signer = ecrecover(hash, v, r, s);

        // 서명자가 소유자인지 확인
        // Check if signer is the owner
        bool isValid = (signer != address(0) && signer == owner);

        return isValid ? MAGICVALUE : bytes4(0xffffffff);
    }

    /**
     * @dev 소유자 변경
     * @dev Change owner
     *
     * @param newOwner 새로운 소유자 주소
     * @param newOwner New owner address
     */
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        require(newOwner != owner, "Same as current owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnerChanged(oldOwner, newOwner);
    }

    /**
     * @dev ETH 수신 가능
     * @dev Allow receiving ETH
     */
    receive() external payable {}

    /**
     * @dev 트랜잭션 실행 (소유자만)
     * @dev Execute transaction (owner only)
     *
     * @param to 대상 주소
     * @param to Target address
     *
     * @param value 전송할 ETH 양
     * @param value Amount of ETH to send
     *
     * @param data 호출 데이터
     * @param data Call data
     */
    function execute(
        address to,
        uint256 value,
        bytes memory data
    ) external onlyOwner returns (bytes memory) {
        require(to != address(0), "Invalid target");

        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "Transaction failed");

        return result;
    }

    /**
     * @dev 현재 컨트랙트의 ETH 잔액 조회
     * @dev Get current contract ETH balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title EIP1271WithEIP712
 * @dev EIP-1271과 EIP-712를 결합한 고급 예제
 * @dev Advanced example combining EIP-1271 with EIP-712
 *
 * EIP-712를 사용하여 구조화된 데이터에 서명하고,
 * EIP-1271을 사용하여 컨트랙트에서 해당 서명을 검증합니다.
 *
 * Uses EIP-712 for signing structured data and
 * EIP-1271 for verifying signatures in the contract.
 */
contract EIP1271WithEIP712 is IERC1271 {
    address public owner;
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    // EIP-712 도메인 타입 해시
    // EIP-712 Domain type hash
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    // 메시지 타입 해시
    // Message type hash
    bytes32 private constant MESSAGE_TYPEHASH = keccak256(
        "Message(address to,uint256 value,bytes data,uint256 nonce)"
    );

    // 도메인 분리자
    // Domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // 재사용 방지를 위한 nonce
    // Nonce for replay protection
    uint256 public nonce;

    /**
     * @dev 메시지 구조체
     * @dev Message struct
     */
    struct Message {
        address to;
        uint256 value;
        bytes data;
        uint256 nonce;
    }

    constructor() {
        owner = msg.sender;

        // 도메인 분리자 생성
        // Create domain separator
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes("EIP1271WithEIP712")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    /**
     * @dev EIP-712 구조화된 데이터 해시 생성
     * @dev Create EIP-712 structured data hash
     */
    function hashMessage(Message memory message) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            MESSAGE_TYPEHASH,
            message.to,
            message.value,
            keccak256(message.data),
            message.nonce
        ));

        // EIP-712 최종 해시
        // EIP-712 final hash
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));
    }

    /**
     * @dev EIP-1271 서명 검증 (EIP-712 해시 사용)
     * @dev EIP-1271 signature verification (using EIP-712 hash)
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        address signer = ecrecover(hash, v, r, s);
        bool isValid = (signer != address(0) && signer == owner);

        return isValid ? MAGICVALUE : bytes4(0xffffffff);
    }

    /**
     * @dev 서명된 메시지 실행
     * @dev Execute signed message
     */
    function executeWithSignature(
        Message memory message,
        bytes memory signature
    ) external returns (bytes memory) {
        require(message.nonce == nonce, "Invalid nonce");

        bytes32 messageHash = hashMessage(message);

        // EIP-1271로 서명 검증
        // Verify signature with EIP-1271
        require(
            this.isValidSignature(messageHash, signature) == MAGICVALUE,
            "Invalid signature"
        );

        nonce++;

        (bool success, bytes memory result) = message.to.call{value: message.value}(message.data);
        require(success, "Execution failed");

        return result;
    }

    receive() external payable {}
}
