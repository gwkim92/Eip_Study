# EIP-1153 Cheat Sheet

> **빠른 참조** - Transient Storage Opcodes

## 🎯 핵심 (5초)

```
문제: SSTORE/SLOAD가 너무 비쌈 (20,000 gas) 💸
해결: 트랜잭션 내에서만 유효한 임시 저장소 ⚡

→ TSTORE: 100 gas (200배 저렴!)
→ TLOAD: 100 gas (21배 저렴!)
→ 트랜잭션 종료 시 자동 초기화
```

## 📝 TSTORE & TLOAD Opcodes

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;  // 0.8.24 이상 필수!

contract TransientBasics {
    // 쓰기
    function set(uint256 slot, uint256 value) external {
        assembly {
            tstore(slot, value)  // TSTORE opcode (0x5d)
        }
    }

    // 읽기
    function get(uint256 slot) external view returns (uint256 value) {
        assembly {
            value := tload(slot)  // TLOAD opcode (0x5c)
        }
    }

    // 복합 사용
    function increment(uint256 slot) external returns (uint256 newValue) {
        assembly {
            let current := tload(slot)
            newValue := add(current, 1)
            tstore(slot, newValue)
        }
    }
}
```

## 💻 재진입 방어 (Reentrancy Guard)

### Before: SSTORE/SLOAD (비쌈 💸)

```solidity
contract OldReentrancyGuard {
    bool private locked;  // 영구 저장소

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;           // SSTORE: ~20,000 gas
        _;
        locked = false;          // SSTORE: ~2,900 gas
    }  // 총: ~22,900 gas

    function withdraw(uint256 amount) external nonReentrant {
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
    }
}
```

### After: TSTORE/TLOAD (저렴 ⚡)

```solidity
contract NewReentrancyGuard {
    uint256 private constant GUARD_SLOT = 0;

    modifier nonReentrant() {
        assembly {
            if tload(GUARD_SLOT) { revert(0, 0) }
            tstore(GUARD_SLOT, 1)  // TSTORE: ~100 gas
        }
        _;
        assembly {
            tstore(GUARD_SLOT, 0)  // TSTORE: ~100 gas
        }
    }  // 총: ~200 gas (99% 절감!)

    function withdraw(uint256 amount) external nonReentrant {
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
    }
}
```

## 🔥 플래시 론 (Flash Loan)

```solidity
interface IFlashLoanReceiver {
    function executeOperation(uint256 amount, bytes calldata data) external;
}

contract FlashLoanTransient {
    uint256 private constant LOAN_SLOT = 0;
    uint256 private constant BORROWER_SLOT = 1;

    error FlashLoanInProgress();
    error FlashLoanNotRepaid();

    function flashLoan(uint256 amount, bytes calldata data) external {
        uint256 loanAmount;
        assembly {
            loanAmount := tload(LOAN_SLOT)
        }

        if (loanAmount != 0) {
            revert FlashLoanInProgress();
        }

        uint256 balanceBefore = address(this).balance;

        // 플래시 론 상태 저장
        assembly {
            tstore(LOAN_SLOT, amount)
            tstore(BORROWER_SLOT, caller())
        }

        // 빌려주기
        IFlashLoanReceiver(msg.sender).executeOperation(amount, data);

        // 상환 확인
        if (address(this).balance < balanceBefore + amount) {
            revert FlashLoanNotRepaid();
        }

        // 트랜잭션 종료 시 자동 초기화됨 (선택사항)
        assembly {
            tstore(LOAN_SLOT, 0)
            tstore(BORROWER_SLOT, 0)
        }
    }

    receive() external payable {}
}
```

## 🔢 트랜잭션 카운터

```solidity
contract TransientCounter {
    uint256 private constant COUNTER_SLOT = 0;

    event CallRecorded(uint256 count);

    function increment() external returns (uint256) {
        uint256 count;
        assembly {
            count := tload(COUNTER_SLOT)
            count := add(count, 1)
            tstore(COUNTER_SLOT, count)
        }

        emit CallRecorded(count);
        return count;
    }

    function multipleOperations() external returns (uint256[] memory) {
        uint256[] memory counts = new uint256[](3);

        counts[0] = this.increment();  // 1
        counts[1] = this.increment();  // 2
        counts[2] = this.increment();  // 3

        return counts;
        // 트랜잭션 종료 시 카운터 → 0으로 자동 초기화
    }
}
```

**사용 예**:

```javascript
// 첫 번째 트랜잭션
await counter.multipleOperations();  // [1, 2, 3]

// 두 번째 트랜잭션 (새로운 트랜잭션)
await counter.getCounter();  // 0 (자동 초기화됨)
await counter.multipleOperations();  // [1, 2, 3] (다시 1부터)
```

## 🗝️ 임시 화이트리스트

```solidity
contract TransientWhitelist {
    uint256 private constant WHITELIST_BASE = 1000;

    function addToWhitelist(address account) external {
        uint256 slot = WHITELIST_BASE + uint256(uint160(account));
        assembly {
            tstore(slot, 1)
        }
    }

    function isWhitelisted(address account) public view returns (bool) {
        uint256 slot = WHITELIST_BASE + uint256(uint160(account));
        uint256 status;
        assembly {
            status := tload(slot)
        }
        return status == 1;
    }

    modifier onlyWhitelisted() {
        require(isWhitelisted(msg.sender), "Not whitelisted");
        _;
    }

    function protectedFunction() external onlyWhitelisted returns (string memory) {
        return "Access granted";
    }

    // 배치 작업
    function batchOperation(address[] calldata users) external {
        // 임시로 화이트리스트에 추가
        for (uint256 i = 0; i < users.length; i++) {
            addToWhitelist(users[i]);
        }

        // 작업 수행
        // ...

        // 트랜잭션 종료 시 자동으로 화이트리스트 초기화됨
    }
}
```

## 📚 Transient Storage 헬퍼 라이브러리

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library TransientStorage {
    // uint256
    function setUint256(uint256 slot, uint256 value) internal {
        assembly { tstore(slot, value) }
    }

    function getUint256(uint256 slot) internal view returns (uint256 value) {
        assembly { value := tload(slot) }
    }

    // address
    function setAddress(uint256 slot, address value) internal {
        assembly { tstore(slot, value) }
    }

    function getAddress(uint256 slot) internal view returns (address value) {
        assembly { value := tload(slot) }
    }

    // bool
    function setBool(uint256 slot, bool value) internal {
        assembly { tstore(slot, value) }
    }

    function getBool(uint256 slot) internal view returns (bool value) {
        assembly { value := tload(slot) }
    }

    // bytes32
    function setBytes32(uint256 slot, bytes32 value) internal {
        assembly { tstore(slot, value) }
    }

    function getBytes32(uint256 slot) internal view returns (bytes32 value) {
        assembly { value := tload(slot) }
    }
}

// 사용 예
contract MyContract {
    using TransientStorage for uint256;

    uint256 private constant MY_SLOT = 0;

    function setMyValue(uint256 value) external {
        MY_SLOT.setUint256(value);
    }

    function getMyValue() external view returns (uint256) {
        return MY_SLOT.getUint256();
    }
}
```

## 📊 가스 비용 비교

| 작업 | SSTORE/SLOAD | TSTORE/TLOAD | 절감 |
|------|--------------|--------------|------|
| **첫 쓰기** (0 → 1) | 20,000 gas | 100 gas | **99.5%** |
| **두 번째 쓰기** | 2,900 gas | 100 gas | **96.6%** |
| **읽기** | 2,100 gas | 100 gas | **95.2%** |
| **초기화** (1 → 0) | 2,900 gas | 자동 (0 gas) | **100%** |

### 재진입 방어 비교

```
기존 SSTORE/SLOAD:
- 첫 SSTORE (0→1): 20,000 gas
- 끝 SSTORE (1→0): 2,900 gas
- 총: 22,900 gas

Transient Storage:
- TSTORE (0→1): 100 gas
- TSTORE (1→0): 100 gas
- 총: 200 gas

절감: 22,700 gas (99.1%)
```

## 🔒 보안 패턴

### ✅ 안전한 사용

```solidity
contract SafePatterns {
    // 1. 슬롯 충돌 방지 (keccak256 해시 사용)
    uint256 private constant LOCK_SLOT = uint256(keccak256("my.lock.slot"));
    uint256 private constant COUNT_SLOT = uint256(keccak256("my.count.slot"));

    // 2. 재진입 체크
    modifier nonReentrant() {
        assembly {
            if tload(LOCK_SLOT) { revert(0, 0) }
            tstore(LOCK_SLOT, 1)
        }
        _;
        assembly {
            tstore(LOCK_SLOT, 0)
        }
    }

    // 3. 타입 안전 래퍼
    function setAddress(uint256 slot, address value) internal {
        require(value != address(0), "Zero address");
        assembly { tstore(slot, value) }
    }
}
```

### ❌ 위험한 패턴

```solidity
// ❌ 1. 영구 데이터를 Transient Storage에 저장
contract Dangerous {
    uint256 private constant BALANCE_SLOT = 0;

    function deposit() external payable {
        uint256 balance;
        assembly {
            balance := tload(BALANCE_SLOT)
            balance := add(balance, callvalue())
            tstore(BALANCE_SLOT, balance)
        }
        // ❌ 트랜잭션 종료 시 잔액 손실!
    }
}

// ❌ 2. View 함수에서 외부 호출 시 사용
contract ProblematicView {
    function getData() external view returns (uint256) {
        uint256 data;
        assembly {
            data := tload(0)  // ❌ 외부에서 호출 시 항상 0
        }
        return data;
    }
}

// ❌ 3. 다른 컨트랙트의 transient storage 가정
// 각 컨트랙트의 transient storage는 독립적!
```

## 🎓 주요 특징 요약

### Storage 비교

| 특성 | Memory | Transient | Storage |
|------|--------|-----------|---------|
| **생명주기** | 함수 호출 | 트랜잭션 | 영구적 |
| **가스** | ~3 gas | ~100 gas | ~20k gas |
| **공유** | 불가 | 각 컨트랙트 독립 | 영구 기록 |
| **사용처** | 함수 내 | 트랜잭션 내 | 영구 저장 |

### 생명주기

```
┌──────────────────────────────────────────┐
│          트랜잭션 생명주기               │
├──────────────────────────────────────────┤
│                                          │
│  1. 트랜잭션 시작                        │
│     → 모든 slot = 0 초기화               │
│                                          │
│  2. 실행 중                              │
│     tstore(0, 100) → slot 0 = 100       │
│     tload(0) → 100 반환                  │
│                                          │
│  3. 트랜잭션 종료                        │
│     → 모든 slot 자동 초기화 (0)          │
│                                          │
│  4. 다음 트랜잭션                        │
│     tload(0) → 0 반환                    │
│                                          │
└──────────────────────────────────────────┘
```

### 격리성 (Isolation)

```
Contract A: tstore(0, 100)  → A의 slot 0 = 100
Contract B: tstore(0, 200)  → B의 slot 0 = 200 (독립적!)

Contract A: tload(0)        → 100 (B와 무관)
Contract B: tload(0)        → 200 (A와 무관)
```

### Revert 동작

```solidity
contract RevertBehavior {
    function example() external {
        assembly { tstore(0, 100) }  // slot 0 = 100

        try this.failing() {
            // 성공
        } catch {
            // revert 발생
        }

        // revert로 인해 failing() 내의 tstore는 롤백됨
        assembly {
            let value := tload(0)  // 여전히 100
        }
    }

    function failing() external {
        assembly { tstore(0, 999) }  // 임시로 999
        revert();  // ← 위의 tstore 롤백됨
    }
}
```

## 🚀 실전 사용 사례

### 1. 재진입 방어
```
OpenZeppelin ReentrancyGuard → 22,900 gas
Transient Storage → 200 gas
절감: 99.1%
```

### 2. 플래시 론
```
대출 상태 추적: TSTORE
상환 확인: TLOAD
트랜잭션 종료 시 자동 초기화
```

### 3. 배치 작업 임시 플래그
```
배치 트랜잭션 중 임시 화이트리스트
배치 중 임시 권한 부여
트랜잭션 종료 시 자동 제거
```

### 4. 트랜잭션 컨텍스트
```
호출 횟수 추적
실행 시간 측정
호출자 정보 저장
```

### 5. 락 메커니즘
```
트랜잭션 내 락 획득/해제
가스 효율적
자동 초기화
```

## 🧪 Hardhat 테스트 설정

### hardhat.config.js

```javascript
module.exports = {
    solidity: {
        version: "0.8.24",  // 0.8.24 이상
        settings: {
            evmVersion: "cancun"  // Cancun 하드포크
        }
    }
};
```

### 테스트 코드

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Transient Storage", function () {
    it("should store and read in same transaction", async function () {
        const Contract = await ethers.getContractFactory("TransientExample");
        const contract = await Contract.deploy();

        const tx = await contract.setAndRead(123);
        await tx.wait();
        // ✅ 함수 내부에서 저장 후 읽기 성공
    });

    it("should reset in new transaction", async function () {
        const Contract = await ethers.getContractFactory("TransientExample");
        const contract = await Contract.deploy();

        await contract.set(0, 123);  // 첫 번째 트랜잭션

        const value = await contract.get(0);  // 두 번째 트랜잭션
        expect(value).to.equal(0);  // ✅ 초기화됨
    });
});
```

## 📌 체크리스트

### 사용 전 확인

- [ ] Solidity 0.8.24 이상 사용
- [ ] Cancun 하드포크 지원 체인 (2024년 3월 이후)
- [ ] Assembly 블록 사용 준비
- [ ] 데이터가 트랜잭션 내에서만 유효한지 확인

### 구현 시 확인

- [ ] 슬롯 충돌 방지 (keccak256 해시 사용)
- [ ] 재진입 방어 패턴 적용
- [ ] 영구 저장이 필요한 데이터는 Storage 사용
- [ ] Revert 시 롤백 동작 이해

### 배포 전 확인

- [ ] 테스트넷에서 충분히 테스트
- [ ] 가스 비용 측정 및 비교
- [ ] 이벤트 로그로 추적 가능하도록 설정
- [ ] 보안 감사 (재진입, 슬롯 충돌 등)

## 🌍 지원 체인 (Cancun+)

| 체인 | 지원 | 활성화 |
|------|------|--------|
| Ethereum | ✅ | 2024-03-13 |
| Arbitrum | ✅ | 2024-03 |
| Optimism | ✅ | 2024-03 |
| Base | ✅ | 2024-03 |
| Polygon | ✅ | 2024-03 |
| BSC | ✅ | 2024-06 |

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 가이드
- [EIP-1153 Spec](https://eips.ethereum.org/EIPS/eip-1153)
- [TransientStorageExample.sol](./contracts/TransientStorageExample.sol)
- [Solidity 0.8.24 Release](https://blog.soliditylang.org/2024/01/26/solidity-0.8.24-release-announcement/)

---

**핵심 요약:**

```
TSTORE/TLOAD:
→ SSTORE 대비 99.5% 가스 절감
→ 트랜잭션 내에서만 유효
→ 자동 초기화 (refund 불필요)

사용처:
✅ 재진입 방어 (99% 절감)
✅ 플래시 론
✅ 임시 플래그/카운터
✅ 배치 작업 화이트리스트

주의:
❌ 영구 저장 불가
❌ 트랜잭션 간 공유 불가
❌ Assembly 블록 필수
```

**Cancun 하드포크 (2024년 3월) 포함!**

**마지막 업데이트: 2025**
