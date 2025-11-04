// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC1271
 * @dev EIP-1271 표준 인터페이스: 컨트랙트 서명 검증
 * @dev Interface for EIP-1271: Standard Signature Validation Method for Contracts
 */
interface IERC1271 {
    /**
     * @dev 주어진 서명이 유효한지 검증해야 함
     * @dev Should return whether the signature provided is valid for the provided data
     *
     * @param hash 서명된 데이터의 해시 (보통 EIP-712 형식)
     * @param hash Hash of the data to be signed (usually EIP-712 format)
     *
     * @param signature 검증할 서명 데이터
     * @param signature Signature byte array associated with hash
     *
     * @return magicValue 성공시 0x1626ba7e (bytes4(keccak256("isValidSignature(bytes32,bytes)")))
     * @return magicValue 0x1626ba7e if valid, any other value if invalid
     *
     * MUST NOT modify state (view function)
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue);
}

/**
 * @title ERC1271Constants
 * @dev EIP-1271 관련 상수들
 * @dev Constants related to EIP-1271
 */
library ERC1271Constants {
    /**
     * @dev Magic value to be returned upon successful signature verification
     * bytes4(keccak256("isValidSignature(bytes32,bytes)"))
     */
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    /**
     * @dev Invalid signature value
     */
    bytes4 internal constant INVALID_SIGNATURE = 0xffffffff;
}
