// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title ERC20Permit Token
 * @notice EIP-2612를 지원하는 ERC-20 토큰
 * @dev OpenZeppelin의 ERC20Permit을 사용한 구현
 */
contract MyPermitToken is ERC20, ERC20Permit {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) ERC20Permit(name) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @notice 토큰 발행 (테스트용)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title Manual ERC20Permit
 * @notice EIP-2612의 수동 구현 (교육용)
 * @dev OpenZeppelin 없이 직접 구현한 버전
 */
contract ManualERC20Permit is ERC20 {
    // EIP-712 Domain Separator
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    // Permit Type Hash
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    // Domain Separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    // 사용자별 nonce
    mapping(address => uint256) private _nonces;

    // 이벤트 (EIP-2612 표준)
    event PermitUsed(
        address indexed owner,
        address indexed spender,
        uint256 value,
        uint256 deadline
    );

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        // Domain Separator 계산
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes("1")), // version
                block.chainid,
                address(this)
            )
        );

        // 초기 공급량
        _mint(msg.sender, 1000000 * 10**18);
    }

    /**
     * @notice Permit 함수 (EIP-2612)
     * @param owner 토큰 소유자
     * @param spender 승인받을 주소
     * @param value 승인 금액
     * @param deadline 서명 만료 시간
     * @param v 서명 v
     * @param r 서명 r
     * @param s 서명 s
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
        require(deadline >= block.timestamp, "Permit: expired");
        require(owner != address(0), "Permit: invalid owner");

        // 구조화된 데이터 해시
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner],
                deadline
            )
        );

        // EIP-712 다이제스트
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        // 서명 검증
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "Permit: invalid signature"
        );

        // nonce 증가
        _nonces[owner]++;

        // 승인
        _approve(owner, spender, value);

        emit PermitUsed(owner, spender, value, deadline);
    }

    /**
     * @notice 사용자의 현재 nonce 조회
     * @param owner 토큰 소유자
     * @return 현재 nonce
     */
    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @notice EIP-712 도메인 구분자 조회
     * @return Domain Separator
     */
    function getDomainSeparator() external view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    /**
     * @notice 토큰 발행 (테스트용)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
