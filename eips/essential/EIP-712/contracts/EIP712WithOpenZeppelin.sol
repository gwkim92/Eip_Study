// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title EIP712WithOpenZeppelin
 * @notice OpenZeppelin의 EIP712를 사용한 구현
 * @dev 더 안전하고 표준화된 방식
 */
contract EIP712WithOpenZeppelin is EIP712 {
    using ECDSA for bytes32;

    // Permit Type Hash
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    // Vote Type Hash (추가 예제)
    bytes32 public constant VOTE_TYPEHASH = keccak256(
        "Vote(uint256 proposalId,bool support,address voter,uint256 nonce)"
    );

    // 사용자별 nonce
    mapping(address => uint256) public nonces;

    // 승인 기록
    mapping(address => mapping(address => uint256)) public allowances;

    // 투표 기록
    mapping(uint256 => mapping(address => bool)) public votes;

    // 이벤트
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);

    constructor() EIP712("EIP712WithOpenZeppelin", "1") {}

    /**
     * @notice OpenZeppelin을 사용한 permit 구현
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

        // 구조화된 데이터 해시 생성
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner],
                deadline
            )
        );

        // OpenZeppelin의 _hashTypedDataV4 사용
        bytes32 hash = _hashTypedDataV4(structHash);

        // OpenZeppelin의 ECDSA 라이브러리로 복구
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "EIP712: invalid signature");

        // nonce 증가
        nonces[owner]++;

        // 승인 설정
        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice 서명을 사용한 투표 (추가 활용 예제)
     * @param proposalId 제안 ID
     * @param support 찬성 여부
     * @param voter 투표자
     * @param v 서명의 v 값
     * @param r 서명의 r 값
     * @param s 서명의 s 값
     */
    function voteWithSignature(
        uint256 proposalId,
        bool support,
        address voter,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 구조화된 데이터 해시 생성
        bytes32 structHash = keccak256(
            abi.encode(
                VOTE_TYPEHASH,
                proposalId,
                support,
                voter,
                nonces[voter]
            )
        );

        // EIP-712 다이제스트 생성
        bytes32 hash = _hashTypedDataV4(structHash);

        // 서명 검증
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == voter, "EIP712: invalid signature");

        // nonce 증가
        nonces[voter]++;

        // 투표 기록
        votes[proposalId][voter] = support;
        emit Voted(proposalId, voter, support);
    }

    /**
     * @notice Compact 서명 형식 지원 (EIP-2098)
     * @dev r, vs를 사용한 압축된 서명 형식
     */
    function permitWithCompactSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes32 r,
        bytes32 vs
    ) external {
        require(deadline >= block.timestamp, "EIP712: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner],
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        // Compact 서명 복구
        address signer = ECDSA.recover(hash, r, vs);
        require(signer == owner, "EIP712: invalid signature");

        nonces[owner]++;
        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice bytes 형식의 서명 지원
     * @dev 가장 유연한 형식
     */
    function permitWithBytesSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external {
        require(deadline >= block.timestamp, "EIP712: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner],
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        // bytes 서명 복구
        address signer = ECDSA.recover(hash, signature);
        require(signer == owner, "EIP712: invalid signature");

        nonces[owner]++;
        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice Domain Separator 조회
     * @return EIP-712 도메인 구분자
     */
    function domainSeparatorV4() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice 서명 해시 조회 (디버깅용)
     * @param owner 토큰 소유자
     * @param spender 승인받을 주소
     * @param value 승인 금액
     * @param deadline 서명 만료 시간
     * @return 서명해야 할 해시
     */
    function getPermitHash(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) external view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner],
                deadline
            )
        );
        return _hashTypedDataV4(structHash);
    }
}
