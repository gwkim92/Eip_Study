// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EIP712Example
 * @notice EIP-712 Typed Structured Data Hashing 기본 구현
 * @dev 오프체인 서명을 온체인에서 검증하는 예제
 */
contract EIP712Example {
    // EIP-712 Domain Separator Type Hash
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    // Permit 메시지 Type Hash
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    // Domain Separator (체인 및 컨트랙트 식별)
    bytes32 public immutable DOMAIN_SEPARATOR;

    // 컨트랙트 이름
    string public constant name = "EIP712Example";

    // 컨트랙트 버전
    string public constant version = "1";

    // 사용자별 nonce (재사용 공격 방지)
    mapping(address => uint256) public nonces;

    // 승인 기록
    mapping(address => mapping(address => uint256)) public allowances;

    // 이벤트
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // Domain Separator 계산 (체인별로 다름)
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice 구조화된 데이터의 해시 생성
     * @param owner 토큰 소유자
     * @param spender 승인받을 주소
     * @param value 승인 금액
     * @param nonce 현재 nonce
     * @param deadline 서명 만료 시간
     * @return 구조화된 데이터의 해시
     */
    function getStructHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
    }

    /**
     * @notice EIP-712 다이제스트 생성
     * @param owner 토큰 소유자
     * @param spender 승인받을 주소
     * @param value 승인 금액
     * @param nonce 현재 nonce
     * @param deadline 서명 만료 시간
     * @return EIP-712 표준 다이제스트
     */
    function getDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 structHash = getStructHash(owner, spender, value, nonce, deadline);
        return keccak256(
            abi.encodePacked(
                "\x19\x01",         // EIP-191 버전 바이트
                DOMAIN_SEPARATOR,   // 도메인 구분자
                structHash          // 구조화된 데이터 해시
            )
        );
    }

    /**
     * @notice 서명을 사용한 permit (ERC-2612 스타일)
     * @param owner 토큰 소유자
     * @param spender 승인받을 주소
     * @param value 승인 금액
     * @param deadline 서명 만료 시간
     * @param v 서명의 v 값
     * @param r 서명의 r 값
     * @param s 서명의 s 값
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "EIP712: expired deadline");

        // 다이제스트 생성
        bytes32 digest = getDigest(owner, spender, value, nonces[owner], deadline);

        // 서명 검증
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0), "EIP712: invalid signature");
        require(recoveredAddress == owner, "EIP712: unauthorized");

        // nonce 증가 (재사용 방지)
        nonces[owner]++;

        // 승인 설정
        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice 서명 검증 (상태 변경 없이)
     * @param owner 토큰 소유자
     * @param spender 승인받을 주소
     * @param value 승인 금액
     * @param deadline 서명 만료 시간
     * @param v 서명의 v 값
     * @param r 서명의 r 값
     * @param s 서명의 s 값
     * @return 서명이 유효한지 여부
     */
    function verify(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool) {
        if (deadline < block.timestamp) {
            return false;
        }

        bytes32 digest = getDigest(owner, spender, value, nonces[owner], deadline);
        address recoveredAddress = ecrecover(digest, v, r, s);

        return recoveredAddress == owner && recoveredAddress != address(0);
    }

    /**
     * @notice 일반 승인 함수 (참고용)
     * @param spender 승인받을 주소
     * @param value 승인 금액
     */
    function approve(address spender, uint256 value) external returns (bool) {
        allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
}
