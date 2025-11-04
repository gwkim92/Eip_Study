# EIP-712 - Typed Structured Data Hashing

## 목적
오프체인에서 서명한 데이터를 온체인에서 안전하게 검증하기 위한 표준

## 핵심 개념

### 문제점 (EIP-712 이전)
```solidity
// 위험한 방식
bytes32 hash = keccak256(abi.encodePacked(user, amount));
// 1. 사용자가 무엇에 서명하는지 불명확
// 2. 체인 간 재사용 공격 가능
// 3. 컨트랙트 간 재사용 공격 가능
```

### 해결책 (EIP-712)
```solidity
// 1. Domain Separator 정의 (컨트랙트/체인 구분)
bytes32 private constant TYPE_HASH = keccak256(
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
);

bytes32 public DOMAIN_SEPARATOR;

constructor() {
    DOMAIN_SEPARATOR = keccak256(abi.encode(
        TYPE_HASH,
        keccak256(bytes("MyDApp")),        // 이름
        keccak256(bytes("1")),             // 버전
        block.chainid,                      // 체인 ID
        address(this)                       // 이 컨트랙트 주소
    ));
}

// 2. 메시지 구조 타입 해시
bytes32 public constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);

// 3. 구조화된 데이터 해시
function getStructHash(
    address owner,
    address spender,
    uint256 value,
    uint256 nonce,
    uint256 deadline
) internal pure returns (bytes32) {
    return keccak256(abi.encode(
        PERMIT_TYPEHASH,
        owner,
        spender,
        value,
        nonce,
        deadline
    ));
}

// 4. 최종 다이제스트 생성
function getDigest(
    address owner,
    address spender,
    uint256 value,
    uint256 nonce,
    uint256 deadline
) public view returns (bytes32) {
    bytes32 structHash = getStructHash(owner, spender, value, nonce, deadline);
    return keccak256(abi.encodePacked(
        "\x19\x01",              // EIP-191 버전
        DOMAIN_SEPARATOR,        // 도메인 구분
        structHash               // 데이터 해시
    ));
}

// 5. 서명 검증
function verify(
    address owner,
    address spender,
    uint256 value,
    uint256 nonce,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) public view returns (bool) {
    bytes32 digest = getDigest(owner, spender, value, nonce, deadline);
    address recovered = ecrecover(digest, v, r, s);
    return recovered == owner;
}
```

## 프론트엔드 통합

### ethers.js v6 사용법
```javascript
const domain = {
    name: 'MyDApp',
    version: '1',
    chainId: await provider.getNetwork().chainId,
    verifyingContract: contractAddress
};

const types = {
    Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

const value = {
    owner: ownerAddress,
    spender: spenderAddress,
    value: amount,
    nonce: nonce,
    deadline: deadline
};

const signature = await signer.signTypedData(domain, types, value);
const { v, r, s } = ethers.Signature.from(signature);
```

## 주의사항
- **chainId는 constructor에서 고정하지 말 것** (하드포크 대비)
- **nonce 관리 필수** (재사용 공격 방지)
- **deadline 설정** (서명 만료)

## OpenZeppelin 사용법
```solidity
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MyContract is EIP712 {
    constructor() EIP712("MyDApp", "1") {}

    function _hashTypedDataV4(bytes32 structHash)
        internal view returns (bytes32) {
        return super._hashTypedDataV4(structHash);
    }
}
```

## 샘플 컨트랙트
- [EIP712Example.sol](./contracts/EIP712Example.sol) - 기본 구현
- [EIP712WithOpenZeppelin.sol](./contracts/EIP712WithOpenZeppelin.sol) - OpenZeppelin 사용

## 참고 자료
- [EIP-712 Specification](https://eips.ethereum.org/EIPS/eip-712)
- [OpenZeppelin EIP712 Documentation](https://docs.openzeppelin.com/contracts/4.x/api/utils#EIP712)
