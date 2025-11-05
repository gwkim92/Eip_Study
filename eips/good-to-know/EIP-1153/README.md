# EIP-1153: Transient Storage Opcodes

> **트랜잭션 내에서만 살아있는 초저비용 임시 저장소** 🔄⚡

## 📚 목차

- [개요](#개요)
- [핵심 개념](#핵심-개념)
- [작동 원리](#작동-원리)
- [TSTORE & TLOAD Opcodes](#tstore--tload-opcodes)
- [사용 사례](#사용-사례)
- [가스 비용 비교](#가스-비용-비교)
- [구현 예제](#구현-예제)
- [보안 고려사항](#보안-고려사항)
- [제한사항](#제한사항)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

### EIP-1153이란?

EIP-1153은 **TSTORE**와 **TLOAD**라는 2개의 새로운 opcodes를 도입하여, **트랜잭션이 실행되는 동안에만 유효한 임시 저장소(Transient Storage)**를 제공합니다.

```
┌─────────────────────────────────────────────┐
│         EIP-1153: Transient Storage         │
├─────────────────────────────────────────────┤
│                                             │
│  트랜잭션 시작  →  TSTORE/TLOAD  →  트랜잭션 종료  │
│       ↓              ↓               ↓      │
│     초기화        사용 가능        자동 삭제    │
│                                             │
│  ⚡ SSTORE보다 99.5% 저렴!                   │
│  🔄 트랜잭션 종료 시 자동 초기화                │
│  🛡️ 재진입 공격 방어에 최적                   │
│                                             │
└─────────────────────────────────────────────┘
```

### 왜 필요한가?

기존의 **SSTORE/SLOAD**는 영구 저장소에 데이터를 쓰기 때문에 **가스 비용이 매우 높습니다**. 하지만 많은 경우 데이터를 영구적으로 보관할 필요가 없습니다:

```solidity
// ❌ 문제: 재진입 방어를 위한 영구 저장소 사용
contract BeforeEIP1153 {
    bool private locked;  // 영구 저장소

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;           // SSTORE: ~20,000 gas
        _;
        locked = false;          // SSTORE: ~2,900 gas
    }

    function withdraw() external nonReentrant {
        // 인출 로직
    }
    // 트랜잭션 종료 후에도 'locked = false' 상태가 저장됨 (불필요!)
}

// ✅ 해결: Transient Storage로 가스 99% 절감
contract AfterEIP1153 {
    modifier nonReentrantTransient() {
        assembly {
            if tload(0) { revert(0, 0) }
            tstore(0, 1)         // TSTORE: ~100 gas (200배 저렴!)
        }
        _;
        assembly {
            tstore(0, 0)         // TSTORE: ~100 gas
        }
    }

    function withdraw() external nonReentrantTransient {
        // 인출 로직
    }
    // 트랜잭션 종료 시 자동으로 초기화됨 (가스 환불 불필요!)
}
```

### 주요 특징

| 특징 | 설명 |
|-----|------|
| **임시성** | 트랜잭션 내에서만 유효, 종료 시 자동 초기화 |
| **저비용** | SSTORE 대비 99.5% 저렴 (~100 gas) |
| **격리성** | 각 컨트랙트의 transient storage는 독립적 |
| **재진입 방어** | 락 메커니즘 구현에 최적화 |
| **자동 초기화** | 가스 환불(refund) 메커니즘 불필요 |

### 활성화 시기

- **하드포크**: Cancun (2024년 3월 13일)
- **블록 번호**: 19,426,587 (Mainnet)
- **Solidity 버전**: 0.8.24+ (assembly 지원)
- **EVM 버전**: cancun

---

## 핵심 개념

### 1. Transient Storage란?

Transient Storage는 **트랜잭션의 생명주기 동안에만 존재하는 임시 메모리**입니다:

```
┌──────────────────────────────────────────────────┐
│             Storage 비교                         │
├─────────────┬─────────────┬─────────────────────┤
│   Memory    │   Storage   │ Transient Storage   │
├─────────────┼─────────────┼─────────────────────┤
│ 함수 호출    │  영구적     │  트랜잭션 동안만      │
│ 동안만 유지  │  블록체인   │  유효               │
│             │  상태에 기록 │                     │
├─────────────┼─────────────┼─────────────────────┤
│ Gas: 저렴   │ Gas: 비쌈   │ Gas: 매우 저렴       │
│ (~3 gas)    │ (~20k gas)  │ (~100 gas)          │
└─────────────┴─────────────┴─────────────────────┘

생명주기:

Memory:           [함수 A 호출]────────[종료] (삭제)
                           ↓
Transient:   [트랜잭션 시작]──[함수 A]──[함수 B]──[트랜잭션 종료] (삭제)
                           ↓
Storage:     [블록체인 생성]─────────────────────→ [영원히 유지]
```

### 2. TSTORE vs SSTORE

```solidity
contract StorageComparison {
    uint256 public permanentValue;  // 영구 저장소

    // 영구 저장소 사용
    function usePermanentStorage(uint256 value) external {
        permanentValue = value;       // SSTORE: 첫 번째 ~20,000 gas
        uint256 read = permanentValue; // SLOAD: ~2,100 gas
        // 트랜잭션 종료 후에도 값이 유지됨
    }

    // 임시 저장소 사용
    function useTransientStorage(uint256 value) external {
        assembly {
            tstore(0, value)           // TSTORE: ~100 gas (200배 저렴!)
            let read := tload(0)       // TLOAD: ~100 gas (21배 저렴!)
        }
        // 트랜잭션 종료 시 자동으로 값이 0으로 초기화됨
    }
}
```

### 3. 격리성 (Isolation)

각 컨트랙트의 transient storage는 **독립적으로 관리**됩니다:

```
트랜잭션 실행 흐름:

User
  ↓
  → Contract A (transient storage slot 0 = 100)
      ↓
      → Contract B (transient storage slot 0 = 200)  ← 독립적!
          ↓
          ← Contract B에서 tload(0) → 200 반환
      ↓
      ← Contract A에서 tload(0) → 100 반환 (B의 값과 무관)
  ↓
트랜잭션 종료 → 모든 transient storage 초기화
```

```solidity
contract ContractA {
    function setAndRead() external returns (uint256) {
        assembly {
            tstore(0, 100)         // ContractA의 slot 0 = 100
        }

        ContractB b = new ContractB();
        b.setAndRead();            // ContractB의 slot 0 = 200 (독립적!)

        uint256 value;
        assembly {
            value := tload(0)      // ContractA의 slot 0 → 100 (변하지 않음)
        }

        return value;              // 100 반환
    }
}

contract ContractB {
    function setAndRead() external returns (uint256) {
        assembly {
            tstore(0, 200)         // ContractB의 slot 0 = 200
        }

        uint256 value;
        assembly {
            value := tload(0)      // ContractB의 slot 0 → 200
        }

        return value;              // 200 반환
    }
}
```

---

## 작동 원리

### 트랜잭션 생명주기

```
1. 트랜잭션 시작
   ↓
   [모든 transient storage 슬롯 = 0으로 초기화]

2. 실행 중
   ↓
   Contract A: tstore(0, 100)    → slot 0 = 100
   Contract A: tstore(1, 200)    → slot 1 = 200
   Contract B: tstore(0, 300)    → slot 0 = 300 (독립적!)

   Contract A: tload(0)          → 100 반환
   Contract A: tload(1)          → 200 반환
   Contract B: tload(0)          → 300 반환

3. 트랜잭션 종료 (성공 or 실패)
   ↓
   [모든 transient storage 슬롯 자동으로 0으로 초기화]

4. 다음 트랜잭션 시작
   ↓
   Contract A: tload(0)          → 0 반환 (초기화됨)
```

### Revert 시 동작

Transient storage는 **revert에도 영향을 받습니다**:

```solidity
contract RevertBehavior {
    function demonstrateRevert() external {
        assembly {
            tstore(0, 100)         // slot 0 = 100
        }

        // 첫 번째 읽기
        uint256 value1;
        assembly {
            value1 := tload(0)     // 100 반환
        }

        // 서브 호출 (실패)
        try this.failingFunction() {
            // 성공 (실행 안 됨)
        } catch {
            // revert 발생 후
        }

        // revert로 인해 failingFunction 내의 tstore는 롤백됨
        uint256 value2;
        assembly {
            value2 := tload(0)     // 여전히 100
        }
    }

    function failingFunction() external {
        assembly {
            tstore(0, 999)         // 임시로 999로 변경
        }
        revert("Intentional failure");  // revert → 위의 tstore 롤백
    }
}
```

### Delegatecall과의 상호작용

**delegatecall**을 사용하면 호출된 컨트랙트 코드가 **호출자의 컨텍스트에서 실행**되므로, transient storage도 호출자의 것을 사용합니다:

```solidity
contract Caller {
    function callDelegate(address impl) external returns (uint256) {
        assembly {
            tstore(0, 777)         // Caller의 slot 0 = 777
        }

        // delegatecall: 'impl'의 코드를 Caller의 컨텍스트에서 실행
        (bool success, bytes memory result) = impl.delegatecall(
            abi.encodeWithSignature("readTransient()")
        );
        require(success);

        return abi.decode(result, (uint256));  // 777 반환
    }
}

contract Implementation {
    function readTransient() external view returns (uint256) {
        uint256 value;
        assembly {
            value := tload(0)      // delegatecall이므로 Caller의 slot 0 읽기 → 777
        }
        return value;
    }
}
```

---

## TSTORE & TLOAD Opcodes

### Opcode 스펙

| Opcode | 값 | Stack Input | Stack Output | Gas | 설명 |
|--------|---|-------------|--------------|-----|------|
| **TSTORE** | 0x5d | `key`, `value` | - | 100 | Transient storage에 저장 |
| **TLOAD** | 0x5c | `key` | `value` | 100 | Transient storage에서 읽기 |

### Solidity에서 사용하기

Solidity 0.8.24+에서는 **assembly 블록**에서 `tstore`/`tload`를 직접 사용할 수 있습니다:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;  // 0.8.24 이상 필수!

contract TransientExample {
    // ✅ 쓰기
    function setTransient(uint256 slot, uint256 value) external {
        assembly {
            tstore(slot, value)
        }
    }

    // ✅ 읽기
    function getTransient(uint256 slot) external view returns (uint256 value) {
        assembly {
            value := tload(slot)
        }
    }

    // ✅ 복합 사용
    function incrementTransient(uint256 slot) external returns (uint256 newValue) {
        assembly {
            let current := tload(slot)
            newValue := add(current, 1)
            tstore(slot, newValue)
        }
    }
}
```

### Yul 문법

```solidity
// Yul assembly 기본 문법
assembly {
    // 1. tstore(key, value)
    tstore(0, 123)                    // slot 0에 123 저장
    tstore(0x20, 456)                 // slot 32에 456 저장

    // 2. tload(key) → value
    let val := tload(0)               // slot 0에서 읽기 → val = 123

    // 3. 계산과 함께 사용
    let current := tload(0)
    let incremented := add(current, 1)
    tstore(0, incremented)

    // 4. 조건문
    if tload(0) {
        // slot 0이 0이 아니면 실행
    }

    // 5. caller(), timestamp() 등과 조합
    tstore(1, caller())               // 호출자 주소 저장
    tstore(2, timestamp())            // 현재 타임스탬프 저장
}
```

---

## 사용 사례

### 1. 재진입 방어 (Reentrancy Guard)

가장 일반적이고 효과적인 사용 사례입니다:

```solidity
contract ReentrancyGuardTransient {
    uint256 private constant REENTRANCY_GUARD_SLOT = 0;

    error ReentrancyDetected();

    modifier nonReentrant() {
        uint256 status;
        assembly {
            status := tload(REENTRANCY_GUARD_SLOT)
        }

        if (status == 1) {
            revert ReentrancyDetected();
        }

        assembly {
            tstore(REENTRANCY_GUARD_SLOT, 1)
        }

        _;

        assembly {
            tstore(REENTRANCY_GUARD_SLOT, 0)
        }
    }

    function withdraw(uint256 amount) external nonReentrant {
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
```

**가스 절감**:
```
기존 SSTORE/SLOAD 재진입 방어:
- 첫 번째 SSTORE (0→1): ~20,000 gas
- 마지막 SSTORE (1→0): ~2,900 gas
- 총: ~22,900 gas

Transient Storage 재진입 방어:
- 첫 번째 TSTORE (0→1): ~100 gas
- 마지막 TSTORE (1→0): ~100 gas
- 총: ~200 gas

절감: ~22,700 gas (99% 절감!)
```

### 2. 플래시 론 (Flash Loan)

플래시 론은 트랜잭션 내에서 대출과 상환이 모두 이루어지므로 transient storage와 완벽하게 맞습니다:

```solidity
interface IFlashLoanReceiver {
    function executeOperation(uint256 amount, bytes calldata data) external;
}

contract FlashLoanWithTransient {
    uint256 private constant FLASH_LOAN_SLOT = 0;
    uint256 private constant BORROWER_SLOT = 1;

    error FlashLoanInProgress();
    error FlashLoanNotRepaid();

    event FlashLoanExecuted(address indexed borrower, uint256 amount);

    function flashLoan(uint256 amount, bytes calldata data) external {
        uint256 loanAmount;
        assembly {
            loanAmount := tload(FLASH_LOAN_SLOT)
        }

        if (loanAmount != 0) {
            revert FlashLoanInProgress();
        }

        uint256 balanceBefore = address(this).balance;

        // 플래시 론 상태 기록
        assembly {
            tstore(FLASH_LOAN_SLOT, amount)
            tstore(BORROWER_SLOT, caller())
        }

        // 빌려주기
        IFlashLoanReceiver(msg.sender).executeOperation(amount, data);

        // 상환 확인
        uint256 balanceAfter = address(this).balance;
        if (balanceAfter < balanceBefore + amount) {
            revert FlashLoanNotRepaid();
        }

        // 상태 초기화 (선택사항 - 트랜잭션 종료 시 자동 초기화됨)
        assembly {
            tstore(FLASH_LOAN_SLOT, 0)
            tstore(BORROWER_SLOT, 0)
        }

        emit FlashLoanExecuted(msg.sender, amount);
    }

    function getFlashLoanInfo() external view returns (uint256 amount, address borrower) {
        assembly {
            amount := tload(FLASH_LOAN_SLOT)
            borrower := tload(BORROWER_SLOT)
        }
    }

    receive() external payable {}
}
```

### 3. 트랜잭션 컨텍스트 추적

트랜잭션 내에서 발생하는 이벤트나 상태를 추적:

```solidity
contract TransientContext {
    uint256 private constant INITIATOR_SLOT = 0;
    uint256 private constant START_TIME_SLOT = 1;
    uint256 private constant CALL_COUNT_SLOT = 2;

    // 트랜잭션 시작 시 컨텍스트 초기화
    function initializeContext() external {
        assembly {
            tstore(INITIATOR_SLOT, caller())
            tstore(START_TIME_SLOT, timestamp())
            tstore(CALL_COUNT_SLOT, 0)
        }
    }

    // 호출 횟수 증가
    function incrementCallCount() external returns (uint256) {
        uint256 count;
        assembly {
            count := tload(CALL_COUNT_SLOT)
            count := add(count, 1)
            tstore(CALL_COUNT_SLOT, count)
        }
        return count;
    }

    // 컨텍스트 조회
    function getContext() external view returns (
        address initiator,
        uint256 startTime,
        uint256 callCount,
        uint256 elapsed
    ) {
        assembly {
            initiator := tload(INITIATOR_SLOT)
            startTime := tload(START_TIME_SLOT)
            callCount := tload(CALL_COUNT_SLOT)
            elapsed := sub(timestamp(), startTime)
        }
    }
}
```

### 4. 임시 화이트리스트

트랜잭션 내에서만 유효한 접근 제어:

```solidity
contract TransientWhitelist {
    uint256 private constant WHITELIST_BASE_SLOT = 1000;

    event AddressWhitelisted(address indexed account);

    function addToWhitelist(address account) external {
        uint256 slot = WHITELIST_BASE_SLOT + uint256(uint160(account));
        assembly {
            tstore(slot, 1)
        }
        emit AddressWhitelisted(account);
    }

    function isWhitelisted(address account) public view returns (bool) {
        uint256 slot = WHITELIST_BASE_SLOT + uint256(uint160(account));
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

    // 사용 예: 배치 작업
    function batchOperationWithWhitelist(address[] calldata users) external {
        // 임시로 여러 사용자를 화이트리스트에 추가
        for (uint256 i = 0; i < users.length; i++) {
            addToWhitelist(users[i]);
        }

        // 화이트리스트 사용자들이 작업 수행
        for (uint256 i = 0; i < users.length; i++) {
            // ...작업...
        }

        // 트랜잭션 종료 시 자동으로 화이트리스트 초기화됨
    }
}
```

### 5. 락 메커니즘

```solidity
contract TransientLock {
    uint256 private constant LOCK_SLOT = 0;

    error AlreadyLocked();
    error NotLockOwner();

    function acquireLock() external {
        uint256 lockStatus;
        assembly {
            lockStatus := tload(LOCK_SLOT)
        }

        if (lockStatus != 0) {
            revert AlreadyLocked();
        }

        assembly {
            tstore(LOCK_SLOT, caller())
        }
    }

    function releaseLock() external {
        address currentLocker;
        assembly {
            currentLocker := tload(LOCK_SLOT)
        }

        if (currentLocker != msg.sender) {
            revert NotLockOwner();
        }

        assembly {
            tstore(LOCK_SLOT, 0)
        }
    }

    function lockedOperation() external view returns (string memory) {
        address locker;
        assembly {
            locker := tload(LOCK_SLOT)
        }

        require(locker == msg.sender, "Must acquire lock first");
        return "Operation executed";
    }
}
```

---

## 가스 비용 비교

### 상세 비용 분석

| 작업 | SSTORE/SLOAD | TSTORE/TLOAD | 절감액 | 절감률 |
|------|--------------|--------------|--------|--------|
| **첫 번째 쓰기** (0 → non-zero) | 20,000 gas | 100 gas | 19,900 gas | **99.5%** |
| **두 번째 쓰기** (non-zero → non-zero) | 2,900 gas | 100 gas | 2,800 gas | **96.6%** |
| **읽기** | 2,100 gas | 100 gas | 2,000 gas | **95.2%** |
| **초기화** (non-zero → 0) | 2,900 gas (-15,000 refund) | 100 gas | 자동 (0 gas) | **100%** |

### 실제 예제 비교

```solidity
contract GasComparisonTransient {
    uint256 public regularStorage;

    event GasMeasured(string operation, uint256 gasUsed);

    // 일반 Storage 사용
    function useRegularStorage(uint256 value) external returns (uint256 gasUsed) {
        uint256 gasBefore = gasleft();

        regularStorage = value;            // SSTORE
        uint256 retrieved = regularStorage; // SLOAD

        gasUsed = gasBefore - gasleft();
        emit GasMeasured("Regular Storage", gasUsed);

        return gasUsed;
    }

    // Transient Storage 사용
    function useTransientStorage(uint256 value) external returns (uint256 gasUsed) {
        uint256 gasBefore = gasleft();

        assembly {
            tstore(0, value)                // TSTORE
        }

        uint256 retrieved;
        assembly {
            retrieved := tload(0)           // TLOAD
        }

        gasUsed = gasBefore - gasleft();
        emit GasMeasured("Transient Storage", gasUsed);

        return gasUsed;
    }

    // 비교 실행
    function compareGas(uint256 value) external returns (
        uint256 regularGas,
        uint256 transientGas,
        uint256 savings
    ) {
        regularGas = this.useRegularStorage(value);
        transientGas = this.useTransientStorage(value);
        savings = regularGas - transientGas;

        return (regularGas, transientGas, savings);
    }
}
```

**실제 측정 결과** (대략적인 값):

```
regularGas:    ~22,300 gas  (SSTORE + SLOAD)
transientGas:  ~200 gas     (TSTORE + TLOAD)
savings:       ~22,100 gas  (99% 절감!)
```

### 재진입 방어 비용 비교

```solidity
// OpenZeppelin ReentrancyGuard (SSTORE/SLOAD 사용)
contract OldReentrancyGuard {
    uint256 private _status;

    modifier nonReentrant() {
        require(_status != 1, "Reentrant call");
        _status = 1;      // SSTORE: ~20,000 gas
        _;
        _status = 0;      // SSTORE: ~2,900 gas (+ refund)
    }

    function withdraw() external nonReentrant {
        // ... 작업 ...
    }
}
// 총 가스: ~22,900 gas (refund 전)

// Transient Storage 재진입 방어
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
    }

    function withdraw() external nonReentrant {
        // ... 작업 ...
    }
}
// 총 가스: ~200 gas

// 절감: ~22,700 gas (99.1% 절감!)
```

---

## 구현 예제

### 예제 1: 기본 사용법

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BasicTransientStorage {
    /**
     * @dev Transient storage에 값 저장 및 읽기
     */
    function demonstrateTransientStorage(uint256 value) external returns (uint256) {
        // 저장
        assembly {
            tstore(0, value)
        }

        // 읽기
        uint256 retrieved;
        assembly {
            retrieved := tload(0)
        }

        return retrieved;  // value와 동일
    }

    /**
     * @dev 새 트랜잭션에서는 항상 0 반환
     */
    function checkTransientAfterTransaction() external view returns (uint256) {
        uint256 value;
        assembly {
            value := tload(0)  // 항상 0 (새 트랜잭션)
        }
        return value;
    }

    /**
     * @dev 여러 슬롯 사용
     */
    function useMultipleSlots() external returns (uint256, uint256, uint256) {
        assembly {
            tstore(0, 100)
            tstore(1, 200)
            tstore(2, 300)
        }

        uint256 a;
        uint256 b;
        uint256 c;

        assembly {
            a := tload(0)  // 100
            b := tload(1)  // 200
            c := tload(2)  // 300
        }

        return (a, b, c);
    }
}
```

### 예제 2: 트랜잭션 호출 카운터

```solidity
contract TransientCounter {
    uint256 private constant COUNTER_SLOT = 0;

    event CallRecorded(uint256 callNumber);

    function incrementCounter() external returns (uint256) {
        uint256 count;
        assembly {
            count := tload(COUNTER_SLOT)
            count := add(count, 1)
            tstore(COUNTER_SLOT, count)
        }

        emit CallRecorded(count);
        return count;
    }

    function getCounter() external view returns (uint256) {
        uint256 count;
        assembly {
            count := tload(COUNTER_SLOT)
        }
        return count;
    }

    function multipleOperations() external returns (uint256[] memory) {
        uint256[] memory counts = new uint256[](3);

        counts[0] = this.incrementCounter();  // 1
        counts[1] = this.incrementCounter();  // 2
        counts[2] = this.incrementCounter();  // 3

        return counts;
    }
}
```

**사용 예**:

```javascript
// JavaScript (ethers.js)
const counter = await TransientCounter.deploy();

// 첫 번째 트랜잭션
const tx1 = await counter.multipleOperations();
await tx1.wait();
console.log(tx1);  // [1, 2, 3]

// 두 번째 트랜잭션 (새로운 트랜잭션 → 카운터 0으로 초기화됨)
const count = await counter.getCounter();
console.log(count);  // 0

const tx2 = await counter.multipleOperations();
await tx2.wait();
console.log(tx2);  // [1, 2, 3] (다시 1부터 시작)
```

### 예제 3: 고급 재진입 방어 (상태 추적)

```solidity
contract AdvancedReentrancyGuard {
    uint256 private constant GUARD_SLOT = 0;
    uint256 private constant CALLER_SLOT = 1;
    uint256 private constant DEPTH_SLOT = 2;

    error ReentrancyDetected(address caller, uint256 depth);

    modifier nonReentrant() {
        uint256 status;
        assembly {
            status := tload(GUARD_SLOT)
        }

        if (status == 1) {
            address originalCaller;
            uint256 depth;
            assembly {
                originalCaller := tload(CALLER_SLOT)
                depth := tload(DEPTH_SLOT)
            }
            revert ReentrancyDetected(originalCaller, depth);
        }

        assembly {
            tstore(GUARD_SLOT, 1)
            tstore(CALLER_SLOT, caller())
            tstore(DEPTH_SLOT, 1)
        }

        _;

        assembly {
            tstore(GUARD_SLOT, 0)
            tstore(CALLER_SLOT, 0)
            tstore(DEPTH_SLOT, 0)
        }
    }

    function getGuardStatus() external view returns (
        bool locked,
        address caller,
        uint256 depth
    ) {
        assembly {
            locked := tload(GUARD_SLOT)
            caller := tload(CALLER_SLOT)
            depth := tload(DEPTH_SLOT)
        }
    }

    function withdraw(uint256 amount) external nonReentrant {
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
```

### 예제 4: Transient Storage 헬퍼 라이브러리

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title TransientStorage
 * @dev Transient storage를 쉽게 사용하기 위한 라이브러리
 */
library TransientStorage {
    /**
     * @dev uint256 값 저장
     */
    function setUint256(uint256 slot, uint256 value) internal {
        assembly {
            tstore(slot, value)
        }
    }

    /**
     * @dev uint256 값 읽기
     */
    function getUint256(uint256 slot) internal view returns (uint256 value) {
        assembly {
            value := tload(slot)
        }
    }

    /**
     * @dev address 값 저장
     */
    function setAddress(uint256 slot, address value) internal {
        assembly {
            tstore(slot, value)
        }
    }

    /**
     * @dev address 값 읽기
     */
    function getAddress(uint256 slot) internal view returns (address value) {
        assembly {
            value := tload(slot)
        }
    }

    /**
     * @dev bool 값 저장
     */
    function setBool(uint256 slot, bool value) internal {
        assembly {
            tstore(slot, value)
        }
    }

    /**
     * @dev bool 값 읽기
     */
    function getBool(uint256 slot) internal view returns (bool value) {
        assembly {
            value := tload(slot)
        }
    }

    /**
     * @dev bytes32 값 저장
     */
    function setBytes32(uint256 slot, bytes32 value) internal {
        assembly {
            tstore(slot, value)
        }
    }

    /**
     * @dev bytes32 값 읽기
     */
    function getBytes32(uint256 slot) internal view returns (bytes32 value) {
        assembly {
            value := tload(slot)
        }
    }
}

// 사용 예
contract UsingTransientLibrary {
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

---

## 보안 고려사항

### ✅ 안전한 사용 패턴

#### 1. 재진입 방어

```solidity
contract SafeReentrancyGuard {
    uint256 private constant GUARD_SLOT = 0;

    modifier nonReentrant() {
        // ✅ 재진입 체크
        assembly {
            if tload(GUARD_SLOT) { revert(0, 0) }
            tstore(GUARD_SLOT, 1)
        }

        _;

        // ✅ 정리 (선택사항, 트랜잭션 종료 시 자동 초기화됨)
        assembly {
            tstore(GUARD_SLOT, 0)
        }
    }

    function sensitiveOperation() external nonReentrant {
        // 안전한 작업
    }
}
```

#### 2. 슬롯 충돌 방지

```solidity
contract SafeSlotManagement {
    // ✅ 명확한 슬롯 정의
    uint256 private constant LOCK_SLOT = 0;
    uint256 private constant COUNTER_SLOT = 1;
    uint256 private constant CONTEXT_SLOT = 2;

    // ✅ 또는 keccak256 해시 사용 (더 안전)
    uint256 private constant LOCK_SLOT_HASH = uint256(keccak256("my.lock.slot"));
    uint256 private constant COUNTER_SLOT_HASH = uint256(keccak256("my.counter.slot"));

    function useLock() external {
        assembly {
            tstore(LOCK_SLOT_HASH, 1)  // 슬롯 충돌 방지
        }
    }
}
```

#### 3. 타입 안전성

```solidity
library TypeSafeTransient {
    // ✅ 타입별 래퍼 함수 제공
    function setAddress(uint256 slot, address value) internal {
        assembly {
            tstore(slot, value)
        }
    }

    function getAddress(uint256 slot) internal view returns (address value) {
        assembly {
            value := tload(slot)
        }
    }

    // ✅ 검증 로직 추가
    function setNonZeroAddress(uint256 slot, address value) internal {
        require(value != address(0), "Zero address");
        assembly {
            tstore(slot, value)
        }
    }
}
```

### ❌ 위험한 패턴

#### 1. 영구 데이터를 Transient Storage에 저장

```solidity
// ❌ 위험: 사용자 잔액을 transient storage에 저장
contract DangerousBalance {
    uint256 private constant BALANCE_SLOT = 0;

    function deposit() external payable {
        uint256 currentBalance;
        assembly {
            currentBalance := tload(BALANCE_SLOT)
            currentBalance := add(currentBalance, callvalue())
            tstore(BALANCE_SLOT, currentBalance)
        }
        // ❌ 트랜잭션 종료 시 잔액 손실!
    }

    function withdraw() external {
        uint256 balance;
        assembly {
            balance := tload(BALANCE_SLOT)  // ❌ 항상 0 (새 트랜잭션)
        }
        // 출금 불가능!
    }
}

// ✅ 올바른 방법: 영구 저장소 사용
contract SafeBalance {
    mapping(address => uint256) public balances;  // Storage 사용

    function deposit() external payable {
        balances[msg.sender] += msg.value;  // ✅ 영구 저장
    }

    function withdraw() external {
        uint256 balance = balances[msg.sender];  // ✅ 읽을 수 있음
        // 출금 가능
    }
}
```

#### 2. 외부 호출에서의 상태 가정

```solidity
// ❌ 위험: 외부 컨트랙트의 transient storage 가정
contract DangerousExternalCall {
    function checkExternalTransient(address target) external view returns (uint256) {
        // ❌ 'target' 컨트랙트의 transient storage는 독립적
        (bool success, bytes memory result) = target.staticcall(
            abi.encodeWithSignature("getTransient()")
        );
        // 'target'의 transient storage는 이 컨트랙트와 무관
    }
}

// ✅ 올바른 방법: 명시적 데이터 전달
contract SafeExternalCall {
    function passDataExplicitly(address target, uint256 data) external {
        // ✅ 필요한 데이터를 명시적으로 전달
        (bool success, ) = target.call(
            abi.encodeWithSignature("processData(uint256)", data)
        );
    }
}
```

#### 3. View 함수에서의 Transient Storage 의존

```solidity
// ❌ 주의: View 함수에서 transient storage 읽기
contract ProblematicView {
    uint256 private constant DATA_SLOT = 0;

    function getData() external view returns (uint256) {
        uint256 data;
        assembly {
            data := tload(DATA_SLOT)
        }
        return data;  // ❌ 외부에서 호출 시 항상 0 (새 트랜잭션)
    }
}

// ✅ 올바른 방법: 트랜잭션 내에서만 사용
contract SafeView {
    uint256 private constant DATA_SLOT = 0;

    function processAndRead() external returns (uint256) {
        assembly {
            tstore(DATA_SLOT, 123)
        }

        // ✅ 같은 트랜잭션 내에서 읽기
        return _readData();
    }

    function _readData() internal view returns (uint256) {
        uint256 data;
        assembly {
            data := tload(DATA_SLOT)
        }
        return data;  // ✅ 같은 트랜잭션 내이므로 123 반환
    }
}
```

---

## 제한사항

### 1. Solidity 버전 요구사항

```solidity
// ❌ 컴파일 오류
pragma solidity ^0.8.23;  // 0.8.24 미만

contract Old {
    function useTransient() external {
        assembly {
            tstore(0, 100)  // 오류: Unknown opcode
        }
    }
}

// ✅ 올바른 버전
pragma solidity ^0.8.24;  // 0.8.24 이상

contract New {
    function useTransient() external {
        assembly {
            tstore(0, 100)  // 정상 작동
        }
    }
}
```

### 2. Assembly 블록 필수

Solidity는 아직 transient storage를 위한 네이티브 문법을 제공하지 않습니다:

```solidity
// ❌ 불가능: 직접 문법 없음
contract NoDirectSyntax {
    transient uint256 public myValue;  // 문법 오류

    function set(uint256 value) external {
        myValue = value;  // 불가능
    }
}

// ✅ Assembly 블록 사용 필수
contract MustUseAssembly {
    uint256 private constant MY_SLOT = 0;

    function set(uint256 value) external {
        assembly {
            tstore(MY_SLOT, value)  // 유일한 방법
        }
    }
}
```

### 3. 외부 읽기 불가능

Transient storage는 **트랜잭션 내에서만 유효**하므로, 외부에서 직접 읽을 수 없습니다:

```javascript
// JavaScript (ethers.js)

// ❌ 불가능: 외부에서 transient storage 읽기
const value = await provider.getStorageAt(contractAddress, 0);  // 항상 0 (새 트랜잭션)

// ✅ 가능: 같은 트랜잭션 내에서 읽기
const tx = await contract.setAndRead(123);
// setAndRead 함수 내부에서 tstore → tload 가능
```

### 4. 이벤트/로그와 조합

Transient storage 자체는 **블록체인에 기록되지 않으므로**, 영구적인 추적이 필요하면 이벤트를 함께 사용해야 합니다:

```solidity
contract TransientWithEvents {
    uint256 private constant COUNTER_SLOT = 0;

    event CounterIncremented(uint256 newValue);

    function increment() external {
        uint256 count;
        assembly {
            count := tload(COUNTER_SLOT)
            count := add(count, 1)
            tstore(COUNTER_SLOT, count)
        }

        // ✅ 이벤트로 영구 기록
        emit CounterIncremented(count);
    }
}
```

### 5. Delegatecall 컨텍스트

Delegatecall을 사용할 때는 **호출자의 transient storage**를 사용합니다:

```solidity
contract Library {
    function setTransient(uint256 value) external {
        assembly {
            tstore(0, value)
        }
    }
}

contract Caller {
    Library public lib;

    function callLib() external {
        // ✅ delegatecall: Library 코드가 Caller의 transient storage 사용
        (bool success, ) = address(lib).delegatecall(
            abi.encodeWithSignature("setTransient(uint256)", 123)
        );

        uint256 value;
        assembly {
            value := tload(0)  // 123 반환 (Caller의 slot 0)
        }
    }
}
```

---

## FAQ

### Q1: Transient Storage는 언제 사용해야 하나요?

**A:** 다음 경우에 사용하세요:

✅ **사용해야 할 때**:
- 재진입 방어 락
- 플래시 론 상태 추적
- 트랜잭션 내 임시 플래그/카운터
- 배치 작업 중 임시 화이트리스트
- 트랜잭션 컨텍스트 데이터

❌ **사용하면 안 될 때**:
- 사용자 잔액, 소유권 등 영구 데이터
- 트랜잭션 간 데이터 공유
- 외부에서 조회 가능해야 하는 상태

### Q2: Transient Storage vs Memory 차이점은?

**A:**

| 특성 | Memory | Transient Storage |
|------|--------|-------------------|
| **범위** | 함수 호출 내에서만 | 트랜잭션 전체 |
| **크로스 컨트랙트** | 불가능 | 가능 (각 컨트랙트 독립) |
| **가스** | ~3 gas/word | ~100 gas/slot |
| **사용처** | 함수 내 임시 데이터 | 트랜잭션 내 상태 추적 |

```solidity
contract Comparison {
    function useMemory() external pure returns (uint256) {
        uint256[] memory arr = new uint256[](10);  // Memory
        arr[0] = 123;
        return arr[0];
    }  // 함수 종료 시 arr 삭제

    function useTransient() external returns (uint256) {
        assembly {
            tstore(0, 123)  // Transient storage
        }

        _helperFunction();  // 다른 함수에서도 접근 가능

        uint256 value;
        assembly {
            value := tload(0)  // 여전히 123
        }
        return value;
    }  // 트랜잭션 종료 시 삭제

    function _helperFunction() internal view {
        uint256 value;
        assembly {
            value := tload(0)  // ✅ 123 반환 (같은 트랜잭션)
        }
    }
}
```

### Q3: 왜 SLOAD/SSTORE refund 대신 Transient Storage를 사용하나요?

**A:**

EIP-3529 (Gas Refund Reduction)로 인해 **SSTORE refund가 크게 줄어들었고**, Transient Storage가 훨씬 효율적입니다:

```
EIP-3529 이전:
- SSTORE (0 → 1): 20,000 gas
- SSTORE (1 → 0): 2,900 gas - 15,000 refund = -12,100 gas
- 순비용: ~7,900 gas

EIP-3529 이후:
- SSTORE (0 → 1): 20,000 gas
- SSTORE (1 → 0): 2,900 gas - 0 refund = 2,900 gas
- 순비용: ~22,900 gas

EIP-1153 Transient Storage:
- TSTORE (0 → 1): 100 gas
- TSTORE (1 → 0): 100 gas
- 순비용: ~200 gas

절감: ~22,700 gas (99% 절감!)
```

### Q4: 다른 컨트랙트의 Transient Storage를 읽을 수 있나요?

**A:** **아니요**, 각 컨트랙트의 transient storage는 **독립적으로 격리**되어 있습니다:

```solidity
contract A {
    function setA() external {
        assembly {
            tstore(0, 100)  // A의 slot 0 = 100
        }
    }

    function readA() external view returns (uint256) {
        uint256 value;
        assembly {
            value := tload(0)  // A의 slot 0 → 100
        }
        return value;
    }
}

contract B {
    A public contractA;

    constructor(A _a) {
        contractA = _a;
    }

    function tryReadA() external {
        contractA.setA();  // A의 slot 0 = 100

        // ❌ B는 A의 transient storage를 직접 읽을 수 없음
        uint256 valueB;
        assembly {
            valueB := tload(0)  // B의 slot 0 → 0 (A와 독립적)
        }

        // ✅ A의 함수를 호출해야 함
        uint256 valueA = contractA.readA();  // 100 반환
    }
}
```

### Q5: Revert 시 Transient Storage는 어떻게 되나요?

**A:** **Revert되면 해당 호출에서의 모든 변경사항이 롤백**됩니다:

```solidity
contract RevertBehavior {
    function demonstrateRevert() external returns (uint256) {
        assembly {
            tstore(0, 100)  // slot 0 = 100
        }

        try this.failingFunction() {
            // 성공 (실행 안 됨)
        } catch {
            // revert 발생
        }

        uint256 value;
        assembly {
            value := tload(0)  // 100 (failingFunction의 변경 롤백됨)
        }

        return value;
    }

    function failingFunction() external {
        assembly {
            tstore(0, 999)  // 임시로 999로 변경
        }
        revert("Intentional failure");  // ← 여기서 revert → 위의 tstore 롤백
    }
}
```

### Q6: OpenZeppelin 라이브러리에서 지원하나요?

**A:** **아직 공식 지원은 제한적**이지만, 곧 추가될 예정입니다:

```solidity
// 현재 (2024): 직접 구현 필요
contract CurrentApproach {
    uint256 private constant GUARD_SLOT = 0;

    modifier nonReentrant() {
        assembly {
            if tload(GUARD_SLOT) { revert(0, 0) }
            tstore(GUARD_SLOT, 1)
        }
        _;
        assembly {
            tstore(GUARD_SLOT, 0)
        }
    }
}

// 향후 예상: OpenZeppelin 통합
// import "@openzeppelin/contracts/security/ReentrancyGuardTransient.sol";
//
// contract FutureApproach is ReentrancyGuardTransient {
//     function withdraw() external nonReentrant {
//         // ...
//     }
// }
```

### Q7: EVM 체인에서 모두 사용할 수 있나요?

**A:** **Cancun 하드포크 이후의 체인에서만 사용 가능**합니다:

| 체인 | 지원 여부 | 활성화 날짜 |
|------|----------|------------|
| **Ethereum Mainnet** | ✅ 지원 | 2024년 3월 13일 |
| **Arbitrum** | ✅ 지원 | 2024년 3월 |
| **Optimism** | ✅ 지원 | 2024년 3월 |
| **Polygon (PoS)** | ✅ 지원 | 2024년 3월 |
| **Base** | ✅ 지원 | 2024년 3월 |
| **BSC** | ✅ 지원 | 2024년 6월 |
| **Avalanche C-Chain** | ✅ 지원 | 2024년 |

### Q8: 가스 최적화 팁은?

**A:**

```solidity
contract GasOptimizationTips {
    uint256 private constant SLOT = 0;

    // ✅ Tip 1: 불필요한 tstore(0, 0) 제거
    function optimized1() external {
        assembly {
            tstore(SLOT, 1)
        }
        // 작업 수행
        // 트랜잭션 종료 시 자동 초기화되므로 tstore(SLOT, 0) 불필요
    }

    // ✅ Tip 2: 단일 tload로 여러 번 사용
    function optimized2() external view returns (uint256, uint256) {
        uint256 value;
        assembly {
            value := tload(SLOT)  // 한 번만 읽기
        }

        uint256 a = value * 2;
        uint256 b = value * 3;

        return (a, b);
    }

    // ❌ Tip 3: 불필요한 반복 tload 피하기
    function notOptimized() external view returns (uint256, uint256) {
        uint256 a;
        uint256 b;

        assembly {
            a := tload(SLOT)  // 읽기 1
            b := tload(SLOT)  // 읽기 2 (불필요한 중복)
        }

        return (a, b);
    }
}
```

### Q9: 테스트는 어떻게 하나요?

**A:**

```javascript
// Hardhat 설정
// hardhat.config.js
module.exports = {
    solidity: {
        version: "0.8.24",
        settings: {
            evmVersion: "cancun"  // 중요!
        }
    }
};

// 테스트 (JavaScript/Mocha)
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Transient Storage", function () {
    it("should store and read transient value in same transaction", async function () {
        const Contract = await ethers.getContractFactory("BasicTransientStorage");
        const contract = await Contract.deploy();

        // 같은 트랜잭션 내에서 저장 및 읽기
        const tx = await contract.demonstrateTransientStorage(123);
        await tx.wait();

        // ✅ 함수 내부에서 읽은 값 확인
        // (반환값으로 확인)
    });

    it("should reset transient storage in new transaction", async function () {
        const Contract = await ethers.getContractFactory("BasicTransientStorage");
        const contract = await Contract.deploy();

        // 첫 번째 트랜잭션
        await contract.demonstrateTransientStorage(123);

        // 두 번째 트랜잭션 (새로운 트랜잭션 → 초기화됨)
        const value = await contract.checkTransientAfterTransaction();

        // ✅ 0이어야 함
        expect(value).to.equal(0);
    });
});
```

### Q10: 실제 프로젝트에서 사용 사례는?

**A:** 실제로 사용되는 예시:

1. **Uniswap V4**: 플래시 론 및 재진입 방어에 transient storage 사용
2. **Compound V3**: 대출/상환 상태 추적
3. **OpenZeppelin (향후)**: ReentrancyGuardTransient 제공 예정
4. **Multicall 패턴**: 배치 트랜잭션 중 임시 상태 관리

```solidity
// Uniswap V4 스타일 플래시 론
contract UniswapStyleFlashLoan {
    uint256 private constant FLASH_LOAN_SLOT = 0;

    function flashLoan(uint256 amount, address recipient, bytes calldata data) external {
        assembly {
            tstore(FLASH_LOAN_SLOT, amount)  // 플래시 론 활성화
        }

        // 빌려주기
        IFlashLoanReceiver(recipient).onFlashLoan(msg.sender, amount, data);

        // 상환 확인
        uint256 currentLoan;
        assembly {
            currentLoan := tload(FLASH_LOAN_SLOT)
        }
        require(currentLoan == 0, "Flash loan not repaid");
    }

    function repay() external payable {
        uint256 loanAmount;
        assembly {
            loanAmount := tload(FLASH_LOAN_SLOT)
        }

        require(msg.value >= loanAmount, "Insufficient repayment");

        assembly {
            tstore(FLASH_LOAN_SLOT, 0)  // 상환 완료
        }
    }
}
```

---

## 참고 자료

### 공식 문서

- [EIP-1153 Specification](https://eips.ethereum.org/EIPS/eip-1153)
- [Solidity 0.8.24 Release Notes](https://blog.soliditylang.org/2024/01/26/solidity-0.8.24-release-announcement/)
- [Ethereum Cancun Upgrade](https://ethereum.org/en/roadmap/cancun/)

### 관련 EIP

- [EIP-3529: Gas Refund Reduction](https://eips.ethereum.org/EIPS/eip-3529) - SSTORE refund 감소
- [EIP-2929: Gas Cost Increases](https://eips.ethereum.org/EIPS/eip-2929) - SLOAD/SSTORE 가스 증가
- [EIP-1884: Repricing for trie-size-dependent opcodes](https://eips.ethereum.org/EIPS/eip-1884)

### 코드 예제

- [contracts/TransientStorageExample.sol](./contracts/TransientStorageExample.sol) - 8가지 구현 패턴
- [Solidity Documentation - Yul](https://docs.soliditylang.org/en/latest/yul.html)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) (향후 통합 예정)

### 커뮤니티 리소스

- [Vitalik's EIP-1153 Proposal](https://ethereum-magicians.org/t/eip-1153-transient-storage-opcodes/553)
- [AllCoreDevs Discussion](https://github.com/ethereum/pm/issues/638)
- [Solidity Forum](https://forum.soliditylang.org/)

---

## 요약

### 핵심 포인트

```
┌─────────────────────────────────────────────┐
│       EIP-1153 한눈에 보기                   │
├─────────────────────────────────────────────┤
│                                             │
│  📦 TSTORE/TLOAD opcodes                    │
│  ⚡ SSTORE 대비 99.5% 가스 절감               │
│  🔄 트랜잭션 종료 시 자동 초기화                │
│  🛡️ 재진입 방어에 최적                        │
│  🔒 각 컨트랙트마다 독립적 격리                │
│  📅 Cancun 하드포크 (2024년 3월)             │
│  💻 Solidity 0.8.24+ 필요                   │
│                                             │
└─────────────────────────────────────────────┘

사용처:
✅ 재진입 방어 (~99% 가스 절감)
✅ 플래시 론 상태 추적
✅ 트랜잭션 내 임시 플래그
✅ 배치 작업 임시 화이트리스트
✅ 트랜잭션 컨텍스트 데이터

주의사항:
❌ 영구 데이터 저장 불가
❌ 트랜잭션 간 데이터 공유 불가
❌ 외부에서 직접 읽기 불가
❌ Assembly 블록 필수
```

**EIP-1153은 가스 최적화의 새로운 패러다임을 제시하며, 특히 재진입 방어와 플래시 론에서 혁신적인 개선을 제공합니다!** 🚀

**마지막 업데이트: 2025**
