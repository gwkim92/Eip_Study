# EIP-712 빠른 시작 가이드 (Quick Start Guide)

## 5분 안에 EIP-712 이해하기 (Get Started in 5 Minutes)

### 1. 핵심 개념 (Basic Concept)

```
일반 서명                    EIP-712 서명
   |                              |
   | 0x1c8aff... (해시)          | 구조화된 데이터
   v                              v
무엇에 서명?                명확한 서명 내용
```

**핵심**: EIP-712는 사용자가 **무엇에 서명하는지 명확하게 보여줍니다**!

---

## 2. 최소 구현 (Minimal Implementation)

### 기본 구조

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleEIP712 {
    // 1️⃣ Domain Separator 계산
    bytes32 public DOMAIN_SEPARATOR;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("MyDApp")),      // 이름
            keccak256(bytes("1")),           // 버전
            block.chainid,                   // 체인 ID
            address(this)                    // 컨트랙트 주소
        ));
    }

    // 2️⃣ Struct 정의
    struct Message {
        address from;
        address to;
        uint256 amount;
        uint256 nonce;
    }

    // 3️⃣ Type Hash
    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(address from,address to,uint256 amount,uint256 nonce)"
    );

    // 4️⃣ 서명 검증
    function verifySignature(
        address from,
        address to,
        uint256 amount,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (bool) {
        // Struct Hash 계산
        bytes32 structHash = keccak256(abi.encode(
            MESSAGE_TYPEHASH,
            from,
            to,
            amount,
            nonce
        ));

        // Digest 계산
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        // 서명 검증
        address signer = ecrecover(digest, v, r, s);
        return signer == from && signer != address(0);
    }
}
```

---

## 3. 사용 방법 (How to Use)

### Frontend (ethers.js v6)

```javascript
import { ethers } from 'ethers';

// 1. Provider와 Signer 준비
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// 2. Domain 정의
const domain = {
    name: 'MyDApp',
    version: '1',
    chainId: (await provider.getNetwork()).chainId,
    verifyingContract: contractAddress
};

// 3. Types 정의
const types = {
    Message: [
        { name: 'from', type: 'address' },
        { name: 'to', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'nonce', type: 'uint256' }
    ]
};

// 4. Value (서명할 데이터)
const value = {
    from: await signer.getAddress(),
    to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
    amount: ethers.parseUnits('1.0', 18),
    nonce: 0
};

// 5. 서명 생성
const signature = await signer.signTypedData(domain, types, value);

// 6. 서명 분리 (v, r, s)
const sig = ethers.Signature.from(signature);

console.log('Signature:', signature);
console.log('v:', sig.v);
console.log('r:', sig.r);
console.log('s:', sig.s);

// 7. 컨트랙트 호출
const contract = new ethers.Contract(contractAddress, ABI, signer);
const isValid = await contract.verifySignature(
    value.from,
    value.to,
    value.amount,
    value.nonce,
    sig.v,
    sig.r,
    sig.s
);

console.log('서명 유효:', isValid);
```

---

## 4. 주요 사용 사례 (Key Use Cases)

### A. 가스 없는 승인 (Gasless Approval)

```solidity
contract TokenWithPermit {
    // Permit 구조
    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => uint256) public nonces;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Expired");

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            nonces[owner]++,  // Nonce 증가
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        address signer = ecrecover(digest, v, r, s);
        require(signer == owner, "Invalid signature");

        allowances[owner][spender] = value;
    }
}
```

### B. 메타 트랜잭션 (Meta-Transaction)

```solidity
contract MetaTx {
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    function execute(
        ForwardRequest calldata req,
        bytes calldata signature
    ) external {
        // 서명 검증
        require(verify(req, signature), "Invalid signature");

        // 실행
        (bool success,) = req.to.call{value: req.value, gas: req.gas}(req.data);
        require(success, "Call failed");
    }
}
```

### C. 오프체인 투표 (Off-chain Voting)

```solidity
contract DAO {
    struct Vote {
        uint256 proposalId;
        bool support;
        address voter;
        uint256 weight;
    }

    function castVoteBySig(
        uint256 proposalId,
        bool support,
        uint256 weight,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        bytes32 structHash = keccak256(abi.encode(
            VOTE_TYPEHASH,
            proposalId,
            support,
            msg.sender,
            weight
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        address voter = ecrecover(digest, v, r, s);
        require(voter != address(0), "Invalid signature");

        _castVote(proposalId, voter, support, weight);
    }
}
```

---

## 5. OpenZeppelin 사용 (With OpenZeppelin)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MyContract is EIP712 {
    using ECDSA for bytes32;

    struct Message {
        address from;
        address to;
        uint256 amount;
        uint256 nonce;
    }

    bytes32 private constant MESSAGE_TYPEHASH = keccak256(
        "Message(address from,address to,uint256 amount,uint256 nonce)"
    );

    constructor() EIP712("MyDApp", "1") {}

    function verifyMessage(
        Message calldata message,
        bytes calldata signature
    ) external view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            MESSAGE_TYPEHASH,
            message.from,
            message.to,
            message.amount,
            message.nonce
        ));

        // _hashTypedDataV4는 OpenZeppelin이 제공
        bytes32 digest = _hashTypedDataV4(structHash);

        address signer = digest.recover(signature);
        return signer == message.from;
    }
}
```

---

## 6. DApp 통합 예제 (DApp Integration)

### 완전한 예제

```javascript
// Frontend: 서명 생성
async function createSignature() {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const userAddress = await signer.getAddress();

    // 1. Domain
    const domain = {
        name: 'MyDApp',
        version: '1',
        chainId: await provider.getNetwork().then(n => n.chainId),
        verifyingContract: '0x...'
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
        owner: userAddress,
        spender: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
        value: ethers.parseUnits('100', 18),
        nonce: 0,
        deadline: Math.floor(Date.now() / 1000) + 3600  // 1시간 후
    };

    // 4. 서명
    const signature = await signer.signTypedData(domain, types, value);
    return { value, signature };
}

// Backend: 서명 검증 (Node.js)
function verifySignature(value, signature) {
    const domain = {
        name: 'MyDApp',
        version: '1',
        chainId: 1,
        verifyingContract: '0x...'
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

    const recoveredAddress = ethers.verifyTypedData(
        domain,
        types,
        value,
        signature
    );

    return recoveredAddress.toLowerCase() === value.owner.toLowerCase();
}
```

---

## 7. 흔한 실수 (Common Mistakes)

### ❌ 실수들

```solidity
// 1. Domain Separator를 한 번만 계산 (chainId 변경 시 문제)
bytes32 public immutable DOMAIN_SEPARATOR;  // ❌ 하드포크 시 문제

// 2. Nonce 없음 (재사용 공격 가능)
struct Message {
    address from;
    address to;
    uint256 amount;
    // nonce 없음! ❌
}

// 3. Deadline 없음 (영구 유효)
struct Permit {
    address owner;
    address spender;
    uint256 value;
    // deadline 없음! ❌
}

// 4. chainId 확인 안 함
// Domain에 chainId가 없으면 재사용 공격 가능! ❌
```

### ✅ 올바른 구현

```solidity
// 1. Domain Separator를 동적으로 계산
function _domainSeparatorV4() internal view returns (bytes32) {
    return keccak256(abi.encode(
        TYPE_HASH,
        NAME_HASH,
        VERSION_HASH,
        block.chainid,  // 현재 chainId 사용
        address(this)
    ));
}

// 2. Nonce 포함
struct Message {
    address from;
    address to;
    uint256 amount;
    uint256 nonce;  // ✅
}

mapping(address => uint256) public nonces;

// 3. Deadline 포함
struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;  // ✅
}

function permit(...) external {
    require(block.timestamp <= deadline, "Expired");
    // ...
}

// 4. chainId 검증
require(block.chainid == expectedChainId, "Wrong chain");
```

---

## 8. 테스트 (Testing)

### Hardhat + ethers.js

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EIP-712 Contract", function () {
    let contract, owner, spender;

    beforeEach(async function () {
        [owner, spender] = await ethers.getSigners();
        
        const Contract = await ethers.getContractFactory("SimpleEIP712");
        contract = await Contract.deploy();
    });

    it("서명 검증 성공", async function () {
        // Domain
        const domain = {
            name: 'MyDApp',
            version: '1',
            chainId: (await ethers.provider.getNetwork()).chainId,
            verifyingContract: await contract.getAddress()
        };

        // Types
        const types = {
            Message: [
                { name: 'from', type: 'address' },
                { name: 'to', type: 'address' },
                { name: 'amount', type: 'uint256' },
                { name: 'nonce', type: 'uint256' }
            ]
        };

        // Value
        const value = {
            from: owner.address,
            to: spender.address,
            amount: ethers.parseEther('1.0'),
            nonce: 0
        };

        // 서명
        const signature = await owner.signTypedData(domain, types, value);
        const sig = ethers.Signature.from(signature);

        // 검증
        const isValid = await contract.verifySignature(
            value.from,
            value.to,
            value.amount,
            value.nonce,
            sig.v,
            sig.r,
            sig.s
        );

        expect(isValid).to.be.true;
    });

    it("잘못된 서명은 실패", async function () {
        const value = {
            from: owner.address,
            to: spender.address,
            amount: ethers.parseEther('1.0'),
            nonce: 0
        };

        // 다른 사용자가 서명
        const fakeSignature = await spender.signTypedData(domain, types, value);
        const sig = ethers.Signature.from(fakeSignature);

        const isValid = await contract.verifySignature(
            value.from,
            value.to,
            value.amount,
            value.nonce,
            sig.v,
            sig.r,
            sig.s
        );

        expect(isValid).to.be.false;
    });
});
```

---

## 9. 체크리스트 (Checklist)

배포 전 확인사항:

- [ ] Domain Separator에 `name`, `version`, `chainId`, `verifyingContract` 모두 포함?
- [ ] Type Hash가 정확히 계산됨?
- [ ] Nonce 시스템 구현됨?
- [ ] Deadline 검증 추가됨?
- [ ] chainId 하드코딩 안 함? (동적 계산)
- [ ] `ecrecover` 반환값이 `address(0)`인지 확인?
- [ ] 서명 재사용 방지됨?
- [ ] Frontend와 Backend의 domain/types가 일치?
- [ ] 테스트 작성됨?
- [ ] 보안 감사 받음?

---

## 10. 다음 단계 (Next Steps)

1. **기본 예제**: `contracts/EIP712Example.sol` 실행해보기
2. **OpenZeppelin**: `contracts/EIP712WithOpenZeppelin.sol` 확인
3. **고급 예제**: EIP-2612 (Permit) 구현해보기
4. **프론트엔드**: ethers.js로 서명 생성 테스트
5. **테스트**: Hardhat으로 전체 플로우 테스트
6. **보안**: 재사용 공격, 체인 간 공격 방어 확인

---

## 11. 유용한 리소스 (Useful Resources)

### 공식 문서
- [EIP-712 명세서](https://eips.ethereum.org/EIPS/eip-712)
- [Ethers.js EIP-712](https://docs.ethers.org/v6/api/hashing/#TypedDataEncoder)
- [OpenZeppelin EIP712](https://docs.openzeppelin.com/contracts/5.x/api/utils#EIP712)

### 실제 구현
- [Uniswap V2 Permit](https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2ERC20.sol)
- [DAI Permit](https://github.com/makerdao/dss/blob/master/src/dai.sol)
- [OpenZeppelin ERC20Permit](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Permit.sol)

### 도구
- [EIP-712 Visualizer](https://eip712-visualizer.vercel.app/)
- [Eth-SigUtil](https://github.com/MetaMask/eth-sig-util)

---

## 12. FAQ

**Q: Domain Separator는 언제 계산하나요?**
- 배포 시 한 번만 계산하고 저장하면 됩니다.
- 단, chainId가 변경될 수 있으므로 동적으로 계산하는 것이 안전합니다.

**Q: Nonce는 왜 필요한가요?**
- 같은 서명을 여러 번 사용하는 **재사용 공격**을 방지합니다.

**Q: Deadline은 필수인가요?**
- 선택사항이지만, **강력히 권장**합니다.
- 서명이 영구적으로 유효하면 보안 위험이 있습니다.

**Q: `"\x19\x01"`은 무엇인가요?**
- EIP-191의 prefix입니다.
- 일반 서명과 구조화된 데이터 서명을 구분합니다.

**Q: MetaMask에서 서명이 안 보이면?**
- MetaMask가 EIP-712를 지원하는지 확인하세요.
- `eth_signTypedData_v4` 메서드를 사용하세요.

**Q: 서명을 오프체인에서 검증할 수 있나요?**
- 네! `ethers.verifyTypedData()`를 사용하면 됩니다.

---

**마지막 업데이트**: 2025-11-05  
**버전**: 1.0.0

**시작하기**: `contracts/EIP712Example.sol`부터 시작하세요! 🚀

