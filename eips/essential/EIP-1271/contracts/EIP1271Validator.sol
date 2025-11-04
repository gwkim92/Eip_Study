// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1271.sol";

/**
 * @title EIP1271Validator
 * @dev EIP-1271 서명을 검증하는 유틸리티 컨트랙트
 * @dev Utility contract for validating EIP-1271 signatures
 *
 * EOA와 스마트 컨트랙트 모두의 서명을 검증할 수 있는 통합 검증기입니다.
 * A unified validator that can verify signatures from both EOAs and smart contracts.
 */
contract EIP1271Validator {
    // EIP-1271 magic value
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    /**
     * @dev 서명 검증 이벤트
     * @dev Signature validation event
     */
    event SignatureValidated(
        address indexed signer,
        bytes32 indexed hash,
        bool isValid,
        bool isContract
    );

    /**
     * @dev 범용 서명 검증 함수
     * @dev Universal signature validation function
     *
     * EOA와 컨트랙트를 모두 지원합니다.
     * Supports both EOA and contracts.
     *
     * @param signer 서명자 주소 (EOA 또는 컨트랙트)
     * @param signer Signer address (EOA or contract)
     *
     * @param hash 서명된 메시지 해시
     * @param hash Hash of the signed message
     *
     * @param signature 서명 데이터
     * @param signature Signature data
     *
     * @return isValid 서명이 유효한지 여부
     * @return isValid Whether the signature is valid
     */
    function isValidSignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) public view returns (bool isValid) {
        // 컨트랙트 여부 확인
        // Check if contract
        bool isContract = _isContract(signer);

        if (isContract) {
            // 컨트랙트: EIP-1271 사용
            // Contract: Use EIP-1271
            isValid = _validateContractSignature(signer, hash, signature);
        } else {
            // EOA: ecrecover 사용
            // EOA: Use ecrecover
            isValid = _validateEOASignature(signer, hash, signature);
        }

        emit SignatureValidated(signer, hash, isValid, isContract);

        return isValid;
    }

    /**
     * @dev 컨트랙트 서명 검증 (EIP-1271)
     * @dev Validate contract signature (EIP-1271)
     */
    function _validateContractSignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) private view returns (bool) {
        try IERC1271(signer).isValidSignature(hash, signature)
            returns (bytes4 magicValue) {
            return magicValue == MAGICVALUE;
        } catch {
            return false;
        }
    }

    /**
     * @dev EOA 서명 검증 (ecrecover)
     * @dev Validate EOA signature (ecrecover)
     */
    function _validateEOASignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) private pure returns (bool) {
        if (signature.length != 65) {
            return false;
        }

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

        // v 값 검증
        // Validate v value
        if (v != 27 && v != 28) {
            return false;
        }

        // s 값 가단성 방지 (EIP-2)
        // Prevent s value malleability (EIP-2)
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return false;
        }

        address recoveredSigner = ecrecover(hash, v, r, s);

        return recoveredSigner != address(0) && recoveredSigner == signer;
    }

    /**
     * @dev 주소가 컨트랙트인지 확인
     * @dev Check if address is a contract
     */
    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev 배치 서명 검증
     * @dev Batch signature validation
     *
     * 여러 서명을 한 번에 검증합니다.
     * Validates multiple signatures at once.
     */
    function batchValidateSignatures(
        address[] memory signers,
        bytes32[] memory hashes,
        bytes[] memory signatures
    ) external view returns (bool[] memory results) {
        require(
            signers.length == hashes.length && hashes.length == signatures.length,
            "Array length mismatch"
        );

        results = new bool[](signers.length);

        for (uint256 i = 0; i < signers.length; i++) {
            results[i] = isValidSignature(signers[i], hashes[i], signatures[i]);
        }

        return results;
    }
}

/**
 * @title SignatureValidator
 * @dev 고급 서명 검증 기능을 제공하는 컨트랙트
 * @dev Contract providing advanced signature validation features
 */
contract SignatureValidator is EIP1271Validator {
    /**
     * @dev 서명 타입
     * @dev Signature types
     */
    enum SignatureType {
        EIP712,           // EIP-712 구조화된 데이터
        ETH_SIGN,         // eth_sign (deprecated)
        PERSONAL_SIGN,    // personal_sign
        CONTRACT          // EIP-1271 컨트랙트 서명
    }

    /**
     * @dev EIP-712 도메인 분리자를 사용한 서명 검증
     * @dev Signature validation using EIP-712 domain separator
     */
    function validateEIP712Signature(
        address signer,
        bytes32 domainSeparator,
        bytes32 structHash,
        bytes memory signature
    ) external view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        return isValidSignature(signer, digest, signature);
    }

    /**
     * @dev Personal sign 메시지 검증
     * @dev Personal sign message validation
     */
    function validatePersonalSignature(
        address signer,
        bytes memory message,
        bytes memory signature
    ) external view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n",
            _toString(message.length),
            message
        ));

        return isValidSignature(signer, messageHash, signature);
    }

    /**
     * @dev 숫자를 문자열로 변환
     * @dev Convert number to string
     */
    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}

/**
 * @title OrderValidator
 * @dev NFT 마켓플레이스 주문 검증 예제
 * @dev NFT marketplace order validation example
 *
 * OpenSea, Rarible 등의 마켓플레이스에서 사용하는 패턴입니다.
 * Pattern used by marketplaces like OpenSea and Rarible.
 */
contract OrderValidator {
    // EIP-1271 magic value
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    /**
     * @dev 주문 구조체
     * @dev Order struct
     */
    struct Order {
        address maker;           // 주문 생성자
        address taker;           // 주문 수락자 (0이면 누구나 가능)
        address nftContract;     // NFT 컨트랙트 주소
        uint256 tokenId;         // NFT 토큰 ID
        uint256 price;           // 가격 (wei)
        uint256 expirationTime;  // 만료 시간
        uint256 salt;            // 재사용 방지를 위한 솔트
    }

    // EIP-712 타입 해시
    // EIP-712 type hashes
    bytes32 private constant ORDER_TYPEHASH = keccak256(
        "Order(address maker,address taker,address nftContract,uint256 tokenId,uint256 price,uint256 expirationTime,uint256 salt)"
    );

    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public immutable DOMAIN_SEPARATOR;

    // 취소된 주문
    // Cancelled orders
    mapping(bytes32 => bool) public cancelledOrders;

    // 완료된 주문
    // Fulfilled orders
    mapping(bytes32 => bool) public fulfilledOrders;

    event OrderCancelled(bytes32 indexed orderHash);
    event OrderFulfilled(bytes32 indexed orderHash);

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes("OrderValidator")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    /**
     * @dev 주문 해시 계산
     * @dev Calculate order hash
     */
    function hashOrder(Order memory order) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            ORDER_TYPEHASH,
            order.maker,
            order.taker,
            order.nftContract,
            order.tokenId,
            order.price,
            order.expirationTime,
            order.salt
        ));

        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));
    }

    /**
     * @dev 주문 검증 (EOA 및 스마트 컨트랙트 지갑 지원)
     * @dev Validate order (supports EOA and smart contract wallets)
     */
    function validateOrder(
        Order memory order,
        bytes memory signature
    ) public view returns (bool) {
        // 기본 검증
        // Basic validation
        require(order.maker != address(0), "Invalid maker");
        require(order.expirationTime > block.timestamp, "Order expired");

        bytes32 orderHash = hashOrder(order);

        // 취소/완료된 주문 확인
        // Check cancelled/fulfilled orders
        require(!cancelledOrders[orderHash], "Order cancelled");
        require(!fulfilledOrders[orderHash], "Order fulfilled");

        // 서명 검증
        // Validate signature
        if (_isContract(order.maker)) {
            // 컨트랙트 지갑: EIP-1271
            // Contract wallet: EIP-1271
            try IERC1271(order.maker).isValidSignature(orderHash, signature)
                returns (bytes4 magicValue) {
                return magicValue == MAGICVALUE;
            } catch {
                return false;
            }
        } else {
            // EOA: ecrecover
            return _validateEOASignature(order.maker, orderHash, signature);
        }
    }

    /**
     * @dev EOA 서명 검증
     * @dev Validate EOA signature
     */
    function _validateEOASignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) private pure returns (bool) {
        if (signature.length != 65) {
            return false;
        }

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

        address recoveredSigner = ecrecover(hash, v, r, s);
        return recoveredSigner != address(0) && recoveredSigner == signer;
    }

    /**
     * @dev 주소가 컨트랙트인지 확인
     * @dev Check if address is a contract
     */
    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev 주문 취소
     * @dev Cancel order
     */
    function cancelOrder(Order memory order) external {
        require(msg.sender == order.maker, "Not order maker");

        bytes32 orderHash = hashOrder(order);
        require(!cancelledOrders[orderHash], "Already cancelled");

        cancelledOrders[orderHash] = true;

        emit OrderCancelled(orderHash);
    }

    /**
     * @dev 주문 완료 표시 (실제 구현에서는 NFT 전송도 포함)
     * @dev Mark order as fulfilled (actual implementation would include NFT transfer)
     */
    function fulfillOrder(Order memory order, bytes memory signature) external payable {
        require(validateOrder(order, signature), "Invalid order");
        require(
            order.taker == address(0) || order.taker == msg.sender,
            "Invalid taker"
        );
        require(msg.value >= order.price, "Insufficient payment");

        bytes32 orderHash = hashOrder(order);
        fulfilledOrders[orderHash] = true;

        // 실제 구현에서는 여기서 NFT 전송 로직 추가
        // Actual implementation would include NFT transfer logic here

        emit OrderFulfilled(orderHash);

        // 판매자에게 지불
        // Pay seller
        payable(order.maker).transfer(order.price);

        // 잔액 환불
        // Refund excess
        if (msg.value > order.price) {
            payable(msg.sender).transfer(msg.value - order.price);
        }
    }
}
