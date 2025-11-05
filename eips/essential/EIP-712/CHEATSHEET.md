# EIP-712 Cheat Sheet

> **빠른 참조 가이드** - EIP-712 Typed Structured Data Hashing

## 🎯 핵심 개념 (5초 요약)

```
EIP-712 = 구조화된 데이터 서명 표준
- 사람이 읽을 수 있는 서명
- 체인/컨트랙트 간 재사용 방지
- 오프체인 서명 → 온체인 검증
```

## 📝 4단계 구현

```solidity
// 1. Domain Separator
bytes32 DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256("MyDApp"),
    keccak256("1"),
    block.chainid,
    address(this)
));

// 2. Type Hash
bytes32 TYPE_HASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);

// 3. Struct Hash
bytes32 structHash = keccak256(abi.encode(
    TYPE_HASH,
    owner,
    spender,
    value,
    nonce,
    deadline
));

// 4. Digest
bytes32 digest = keccak256(abi.encodePacked(
    "\x19\x01",
    DOMAIN_SEPARATOR,
    structHash
));

// 5. 검증
address signer = ecrecover(digest, v, r, s);
```

## 💻 기본 템플릿

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyEIP712 {
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(address from,address to,uint256 amount)"
    );

    bytes32 public immutable DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes("MyDApp")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    function executeWithSignature(
        address from,
        address to,
        uint256 amount,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        bytes32 structHash = keccak256(abi.encode(
            MESSAGE_TYPEHASH,
            from,
            to,
            amount
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0) && signer == from, "Invalid");

        nonces[from]++;
        // Execute logic
    }
}
```

## 🌐 Frontend (ethers.js v6)

```javascript
// 1. Domain
const domain = {
    name: 'MyDApp',
    version: '1',
    chainId: (await provider.getNetwork()).chainId,
    verifyingContract: contractAddress
};

// 2. Types
const types = {
    Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

// 3. Value
const value = {
    owner: await signer.getAddress(),
    spender: spenderAddress,
    value: ethers.parseUnits('1000', 18),
    nonce: 0,
    deadline: Math.floor(Date.now() / 1000) + 3600
};

// 4. 서명
const sig = await signer.signTypedData(domain, types, value);
const { v, r, s } = ethers.Signature.from(sig);

// 5. 전송
await contract.permit(value.owner, value.spender, value.value, value.deadline, v, r, s);
```

## 📊 OpenZeppelin 사용

```solidity
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MyContract is EIP712 {
    using ECDSA for bytes32;

    bytes32 constant TYPE_HASH = keccak256("Message(...)");

    constructor() EIP712("MyDApp", "1") {}

    function execute(bytes memory sig) external {
        bytes32 structHash = keccak256(abi.encode(TYPE_HASH, ...));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(sig);
        // Verify & execute
    }
}
```

## ⚠️ 보안 체크리스트

```solidity
□ Nonce 관리
  ✅ nonces[user]++ 반드시 실행

□ Deadline 확인
  ✅ require(block.timestamp <= deadline)

□ ecrecover 검증
  ✅ require(signer != address(0))
  ✅ require(signer == expectedSigner)

□ chainId 동적 처리
  ✅ block.chainid 사용 (하드코딩 X)

□ Signature Malleability
  ✅ OpenZeppelin ECDSA 사용 권장
```

## 🔑 주요 상수

```solidity
// EIP-191 Prefix
"\x19\x01"

// Domain Separator Type
"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"

// 일반적인 Type Hash 예시
"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
"Vote(uint256 proposalId,bool support,address voter,uint256 nonce)"
"MetaTransaction(address from,address to,bytes data,uint256 nonce)"
```

## 💡 일반적인 실수

### 실수 1: Type Hash 순서 틀림
```solidity
// ❌ 틀림
"Permit(uint256 value,address owner,address spender)"

// ✅ 맞음
"Permit(address owner,address spender,uint256 value)"
```

### 실수 2: chainId 고정
```solidity
// ❌ 하드포크 시 문제
DOMAIN_SEPARATOR = keccak256(abi.encode(..., 1, ...));

// ✅ 동적
DOMAIN_SEPARATOR = keccak256(abi.encode(..., block.chainid, ...));
```

### 실수 3: ecrecover 0 검사 누락
```solidity
// ❌ 취약
address signer = ecrecover(digest, v, r, s);
require(signer == owner);

// ✅ 안전
address signer = ecrecover(digest, v, r, s);
require(signer != address(0));
require(signer == owner);
```

## 🎓 사용 사례

```
✅ EIP-2612 Permit (가장 일반적)
✅ 메타 트랜잭션
✅ DAO 투표
✅ 오프체인 주문서 (0x, OpenSea)
✅ 위임 서명
✅ 배치 작업
```

## 📈 구현 흐름도

```
Frontend (오프체인)
  ↓
1. Domain + Types + Value 구성
  ↓
2. signTypedData() 호출
  ↓
3. 서명 받음 (v, r, s)
  ↓
4. 컨트랙트 함수 호출 (서명 포함)
  ↓
Contract (온체인)
  ↓
5. Struct Hash 계산
  ↓
6. Digest 계산
  ↓
7. ecrecover로 서명자 복구
  ↓
8. 검증 후 로직 실행
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 설명
- [EIP-712 Spec](https://eips.ethereum.org/EIPS/eip-712)
- [OpenZeppelin EIP712](https://docs.openzeppelin.com/contracts/4.x/api/utils#EIP712)

---

**핵심 요약:** Domain Separator + Type Hash + Struct Data → Digest → ecrecover

**마지막 업데이트: 2024**
