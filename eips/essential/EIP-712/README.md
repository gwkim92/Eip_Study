# EIP-712: Typed Structured Data Hashing and Signing

> **"서명 가능한 구조화된 데이터의 표준 - 안전한 오프체인 서명"**

## 목차
- [개요](#개요)
- [EIP-712가 해결하는 문제](#eip-712가-해결하는-문제)
- [핵심 개념](#핵심-개념)
- [구현 방법](#구현-방법)
- [실전 예제](#실전-예제)
- [프론트엔드 통합](#프론트엔드-통합)
- [보안 고려사항](#보안-고려사항)
- [FAQ](#faq)

---

## 개요

### EIP-712란?

EIP-712는 **구조화된 데이터를 사람이 읽을 수 있는 형태로 서명**하기 위한 표준입니다. 사용자가 무엇에 서명하는지 명확히 알 수 있게 하여 피싱 공격을 방지합니다.

**핵심 기능:**
- 오프체인에서 서명, 온체인에서 검증
- 가스 비용 절감 (서명만 제출)
- 사람이 읽을 수 있는 서명 메시지
- 체인 간/컨트랙트 간 재사용 방지

### 왜 중요한가?

```
Before EIP-712:
┌─────────────────────────────────────────┐
│  MetaMask 서명 요청                      │
├─────────────────────────────────────────┤
│  Sign this message:                     │
│  0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8 │
│                                         │
│  ❌ 사용자는 무엇에 서명하는지 알 수 없음!│
└─────────────────────────────────────────┘

After EIP-712:
┌─────────────────────────────────────────┐
│  MetaMask 서명 요청                      │
├─────────────────────────────────────────┤
│  Permit                                 │
│  ├─ owner: 0x123...                     │
│  ├─ spender: 0xABC...                   │
│  ├─ value: 1000 USDC                    │
│  ├─ nonce: 0                            │
│  └─ deadline: 2024-12-31                │
│                                         │
│  ✅ 명확하게 무엇에 서명하는지 확인 가능!│
└─────────────────────────────────────────┘
```

---

## EIP-712가 해결하는 문제

### 문제 1: 불명확한 서명 메시지

**Before:**
```solidity
// 사용자는 이게 뭔지 모름
bytes32 hash = keccak256(abi.encodePacked(user, amount));
signature = sign(hash);
```

**After:**
```solidity
// 구조화된 데이터 - 명확함
struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}
```

### 문제 2: 체인 간 재사용 공격

```
공격 시나리오 (EIP-712 없이):
┌─────────────────────────────────────────┐
│  1. Alice가 Ethereum에서 서명            │
│     "100 ETH 전송"                      │
│                                         │
│  2. 공격자가 같은 서명을 Optimism에서    │
│     재사용 → 100 ETH 추가 도난!          │
│                                         │
│  ❌ chainId 구분 없음!                  │
└─────────────────────────────────────────┘

EIP-712 방어:
┌─────────────────────────────────────────┐
│  Domain Separator에 chainId 포함:       │
│  - Ethereum: chainId = 1                │
│  - Optimism: chainId = 10               │
│                                         │
│  → 서명이 다른 체인에서 무효!            │
│  ✅ 재사용 공격 차단!                    │
└─────────────────────────────────────────┘
```

### 문제 3: 컨트랙트 간 재사용 공격

```
공격 시나리오:
┌─────────────────────────────────────────┐
│  1. Alice가 ContractA에 대한 서명        │
│  2. 공격자가 ContractB에서 같은 서명 사용│
│                                         │
│  ❌ 컨트랙트 구분 없음!                  │
└─────────────────────────────────────────┘

EIP-712 방어:
┌─────────────────────────────────────────┐
│  Domain Separator에 컨트랙트 주소 포함:  │
│  - ContractA: 0x123...                  │
│  - ContractB: 0xABC...                  │
│                                         │
│  → 서명이 다른 컨트랙트에서 무효!        │
│  ✅ 재사용 공격 차단!                    │
└─────────────────────────────────────────┘
```

---

## 핵심 개념

### 1. Domain Separator

Domain Separator는 **서명이 어느 컨트랙트/체인을 위한 것인지** 구분합니다.

```solidity
struct EIP712Domain {
    string name;                  // 컨트랙트 이름
    string version;               // 버전
    uint256 chainId;             // 체인 ID
    address verifyingContract;   // 컨트랙트 주소
}

// Type Hash
bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256(
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
);

// Domain Separator 계산
bytes32 DOMAIN_SEPARATOR = keccak256(abi.encode(
    EIP712_DOMAIN_TYPEHASH,
    keccak256(bytes("MyDApp")),      // name
    keccak256(bytes("1")),           // version
    block.chainid,                    // chainId
    address(this)                     // verifyingContract
));
```

**시각화:**
```
Domain Separator =
┌────────────────────────────────────────┐
│  "MyDApp" + "v1" + Ethereum + 0x123... │
├────────────────────────────────────────┤
│  → 이 조합은 이 컨트랙트에만 유효       │
└────────────────────────────────────────┘
```

### 2. Type Hash

메시지 구조를 정의하는 해시입니다.

```solidity
// Permit 구조 정의
struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

// Type Hash
bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);
```

**중요:** 필드 순서와 타입이 정확해야 합니다!

### 3. Struct Hash

실제 데이터의 해시입니다.

```solidity
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
```

### 4. Digest (최종 해시)

서명할 최종 해시입니다.

```solidity
function getDigest(bytes32 structHash) internal view returns (bytes32) {
    return keccak256(abi.encodePacked(
        "\x19\x01",           // EIP-191 prefix
        DOMAIN_SEPARATOR,     // 도메인 구분
        structHash            // 데이터 해시
    ));
}
```

**구조:**
```
Digest = keccak256(
    "\x19\x01" +           ← EIP-191 버전 바이트
    DOMAIN_SEPARATOR +     ← 컨트랙트/체인 식별
    STRUCT_HASH           ← 메시지 데이터
)
```

### 5. 서명 검증

```solidity
function verify(
    address owner,
    address spender,
    uint256 value,
    uint256 nonce,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public view returns (bool) {
    // 1. Digest 계산
    bytes32 structHash = getStructHash(owner, spender, value, nonce, deadline);
    bytes32 digest = getDigest(structHash);

    // 2. 서명자 복구
    address signer = ecrecover(digest, v, r, s);

    // 3. 검증
    return signer == owner && signer != address(0);
}
```

---

## 구현 방법

### 방법 1: 직접 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyEIP712 {
    // 1. Type Hashes 정의
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(address from,address to,uint256 amount)"
    );

    // 2. Domain Separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    string public constant name = "MyDApp";
    string public constant version = "1";

    // 3. Nonce 관리
    mapping(address => uint256) public nonces;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            block.chainid,
            address(this)
        ));
    }

    // 4. Struct Hash
    function getStructHash(
        address from,
        address to,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MESSAGE_TYPEHASH,
            from,
            to,
            amount
        ));
    }

    // 5. Digest
    function getDigest(
        address from,
        address to,
        uint256 amount
    ) public view returns (bytes32) {
        bytes32 structHash = getStructHash(from, to, amount);
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));
    }

    // 6. 서명 검증 및 실행
    function executeWithSignature(
        address from,
        address to,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Digest 계산
        bytes32 digest = getDigest(from, to, amount);

        // 서명자 복구
        address signer = ecrecover(digest, v, r, s);
        require(signer == from, "Invalid signature");
        require(signer != address(0), "Invalid signer");

        // Nonce 증가 (재사용 방지)
        nonces[from]++;

        // 로직 실행
        _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        // 전송 로직
    }
}
```

### 방법 2: OpenZeppelin 사용 (권장)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MyEIP712WithOZ is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(address from,address to,uint256 amount,uint256 nonce)"
    );

    mapping(address => uint256) public nonces;

    constructor() EIP712("MyDApp", "1") {}

    function executeWithSignature(
        address from,
        address to,
        uint256 amount,
        bytes memory signature
    ) external {
        // 1. Struct Hash
        bytes32 structHash = keccak256(abi.encode(
            MESSAGE_TYPEHASH,
            from,
            to,
            amount,
            nonces[from]
        ));

        // 2. Digest (OpenZeppelin 헬퍼 사용)
        bytes32 digest = _hashTypedDataV4(structHash);

        // 3. 서명 검증 (ECDSA 라이브러리 사용)
        address signer = digest.recover(signature);
        require(signer == from, "Invalid signature");

        // 4. Nonce 증가
        nonces[from]++;

        // 5. 실행
        _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        // 전송 로직
    }
}
```

---

## 실전 예제

### 예제 1: Permit (EIP-2612)

가장 일반적인 EIP-712 사용 사례입니다.

```solidity
contract PermitToken is ERC20, EIP712 {
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    mapping(address => uint256) public nonces;

    constructor() ERC20("PermitToken", "PMT") EIP712("PermitToken", "1") {}

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Expired");

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            nonces[owner]++,
            deadline
        ));

        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ecrecover(digest, v, r, s);

        require(signer == owner, "Invalid signature");

        _approve(owner, spender, value);
    }
}
```

**사용 흐름:**
```
1. Frontend: 사용자가 approve 서명
   ↓
2. Backend: 서명을 permit() 함수에 전달
   ↓
3. Contract: 서명 검증 후 approve 실행
   ↓
4. Contract: transferFrom으로 토큰 전송

✅ 가스비 1번만 지불 (approve 트랜잭션 불필요)
```

### 예제 2: 메타 트랜잭션

```solidity
contract MetaTransaction is EIP712 {
    bytes32 public constant META_TX_TYPEHASH = keccak256(
        "MetaTransaction(address from,address to,bytes data,uint256 nonce)"
    );

    mapping(address => uint256) public nonces;

    constructor() EIP712("MetaTx", "1") {}

    function executeMetaTx(
        address from,
        address to,
        bytes calldata data,
        bytes calldata signature
    ) external returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(
            META_TX_TYPEHASH,
            from,
            to,
            keccak256(data),
            nonces[from]++
        ));

        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, signature);

        require(signer == from, "Invalid signature");

        // 사용자 대신 실행
        (bool success, bytes memory result) = to.call(data);
        require(success, "Meta tx failed");

        return result;
    }
}
```

### 예제 3: DAO 투표

```solidity
contract DAOVoting is EIP712 {
    bytes32 public constant VOTE_TYPEHASH = keccak256(
        "Vote(uint256 proposalId,bool support,address voter,uint256 nonce)"
    );

    mapping(address => uint256) public nonces;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor() EIP712("DAO", "1") {}

    function voteWithSignature(
        uint256 proposalId,
        bool support,
        address voter,
        bytes calldata signature
    ) external {
        require(!hasVoted[proposalId][voter], "Already voted");

        bytes32 structHash = keccak256(abi.encode(
            VOTE_TYPEHASH,
            proposalId,
            support,
            voter,
            nonces[voter]++
        ));

        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, signature);

        require(signer == voter, "Invalid signature");

        hasVoted[proposalId][voter] = true;
        _recordVote(proposalId, support, voter);
    }

    function _recordVote(uint256 proposalId, bool support, address voter) internal {
        // 투표 기록
    }
}
```

---

## 프론트엔드 통합

### ethers.js v6

```javascript
import { ethers } from 'ethers';

// 1. Domain 정의
const domain = {
    name: 'MyDApp',
    version: '1',
    chainId: (await provider.getNetwork()).chainId,
    verifyingContract: contractAddress
};

// 2. Types 정의
const types = {
    Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

// 3. Value (실제 데이터)
const value = {
    owner: await signer.getAddress(),
    spender: spenderAddress,
    value: ethers.parseUnits('1000', 18),
    nonce: await contract.nonces(await signer.getAddress()),
    deadline: Math.floor(Date.now() / 1000) + 3600  // 1시간 후
};

// 4. 서명
const signature = await signer.signTypedData(domain, types, value);

// 5. 서명 분리
const { v, r, s } = ethers.Signature.from(signature);

// 6. 컨트랙트 호출
const tx = await contract.permit(
    value.owner,
    value.spender,
    value.value,
    value.deadline,
    v, r, s
);
await tx.wait();
```

### web3.js

```javascript
import Web3 from 'web3';

const web3 = new Web3(provider);

const domain = [
    { name: "name", type: "string" },
    { name: "version", type: "string" },
    { name: "chainId", type: "uint256" },
    { name: "verifyingContract", type: "address" }
];

const permit = [
    { name: "owner", type: "address" },
    { name: "spender", type: "address" },
    { name: "value", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" }
];

const domainData = {
    name: "MyDApp",
    version: "1",
    chainId: await web3.eth.getChainId(),
    verifyingContract: contractAddress
};

const message = {
    owner: userAddress,
    spender: spenderAddress,
    value: "1000000000000000000",
    nonce: "0",
    deadline: Math.floor(Date.now() / 1000) + 3600
};

const data = JSON.stringify({
    types: {
        EIP712Domain: domain,
        Permit: permit
    },
    domain: domainData,
    primaryType: "Permit",
    message: message
});

const signature = await web3.currentProvider.request({
    method: "eth_signTypedData_v4",
    params: [userAddress, data]
});
```

---

## 보안 고려사항

### 1. Nonce 관리

```solidity
// ✅ 올바른 nonce 관리
mapping(address => uint256) public nonces;

function executeWithSignature(...) external {
    uint256 nonce = nonces[msg.sender];
    // 검증...
    nonces[msg.sender]++;  // 반드시 증가!
}
```

### 2. Deadline 설정

```solidity
// ✅ 서명 만료 시간 확인
function permit(..., uint256 deadline, ...) external {
    require(block.timestamp <= deadline, "Signature expired");
    // ...
}
```

### 3. chainId 동적 처리

```solidity
// ❌ 나쁜 예: 하드포크 시 문제
constructor() {
    DOMAIN_SEPARATOR = keccak256(abi.encode(
        ...
        1,  // 고정된 chainId
        ...
    ));
}

// ✅ 좋은 예: 동적 chainId
constructor() {
    DOMAIN_SEPARATOR = keccak256(abi.encode(
        ...
        block.chainid,  // 동적
        ...
    ));
}
```

### 4. ecrecover 0 주소 체크

```solidity
// ❌ 취약한 코드
address signer = ecrecover(digest, v, r, s);
require(signer == owner, "Invalid");

// ✅ 안전한 코드
address signer = ecrecover(digest, v, r, s);
require(signer != address(0), "Invalid signature");
require(signer == owner, "Wrong signer");
```

### 5. Signature Malleability

```solidity
// OpenZeppelin ECDSA 사용 (권장)
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

address signer = ECDSA.recover(digest, signature);
// ECDSA.recover는 malleability 보호 포함
```

---

## FAQ

### Q1: EIP-712와 EIP-191의 차이는?

**A:**
```
EIP-191: 기본 서명 표준
- prefix만 추가: "\x19Ethereum Signed Message:\n"
- 구조화되지 않음

EIP-712: 고급 서명 표준
- 구조화된 데이터
- Domain Separator
- Type Hash
- 사람이 읽을 수 있음
```

### Q2: 왜 "\x19\x01" prefix를 사용하나?

**A:** EIP-191 호환성을 위해서입니다.
- `\x19`: "Ethereum Signed Message"임을 표시
- `\x01`: EIP-712 버전

### Q3: Domain Separator를 immutable로 해도 되나?

**A:** 하드포크 대비를 위해 동적으로 계산하는 것이 안전합니다.

```solidity
// 권장 방법
function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return keccak256(abi.encode(
        EIP712_DOMAIN_TYPEHASH,
        keccak256(bytes(name)),
        keccak256(bytes(version)),
        block.chainid,  // 동적
        address(this)
    ));
}
```

### Q4: nonce를 건너뛸 수 있나?

**A:** 기본 구현은 순차적이지만, 선택적으로 가능합니다.

```solidity
// 순차적 nonce (기본)
mapping(address => uint256) public nonces;

// 비순차적 nonce (DAI 방식)
mapping(address => mapping(uint256 => bool)) public nonceUsed;
```

---

## 참고 자료

### 공식 문서
- [EIP-712 Specification](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-191 Specification](https://eips.ethereum.org/EIPS/eip-191)

### 실전 예제
- [contracts/EIP712Example.sol](./contracts/EIP712Example.sol)
- [contracts/EIP712WithOpenZeppelin.sol](./contracts/EIP712WithOpenZeppelin.sol)
- [CHEATSHEET.md](./CHEATSHEET.md)

### 라이브러리
- [OpenZeppelin EIP712](https://docs.openzeppelin.com/contracts/4.x/api/utils#EIP712)
- [ethers.js Typed Data](https://docs.ethers.org/v6/api/hashing/#TypedDataEncoder)

---

## 요약

**EIP-712 한 줄 요약:**
> "구조화된 데이터를 안전하게 서명하고 검증하는 표준입니다."

**핵심 포인트:**
1. ✅ **명확성**: 사람이 읽을 수 있는 서명 메시지
2. ✅ **안전성**: 체인/컨트랙트 간 재사용 방지
3. ✅ **효율성**: 오프체인 서명으로 가스 절감
4. ✅ **표준화**: 모든 지갑이 지원

**다음 학습:**
- [EIP-2612 (Permit)](../EIP-2612/README.md)
- [EIP-1271 (Contract Signatures)](../EIP-1271/README.md)

---

*최종 업데이트: 2024년*
*작성자: EIP Study Group*
