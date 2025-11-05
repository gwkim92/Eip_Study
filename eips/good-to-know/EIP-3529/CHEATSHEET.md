# EIP-3529 Cheat Sheet

> **빠른 참조** - 가스 환불 메커니즘 축소

## 🎯 핵심 (5초)

```
문제: GasToken 악용 + 블록 크기 예측 불가
해결: 가스 환불 대폭 축소

→ SSTORE 환불: 15,000 → 4,800 gas (68% 감소)
→ SELFDESTRUCT 환불: 24,000 → 0 gas (100% 제거)
→ 최대 환불: Gas Used / 2 → Gas Used / 5
```

## 📝 주요 변경사항

| 항목 | Before | After | 변화 |
|------|--------|-------|------|
| **SSTORE 환불** | 15,000 gas | 4,800 gas | -68% |
| **SELFDESTRUCT 환불** | 24,000 gas | 0 gas | -100% |
| **최대 환불 한도** | Gas Used / 2 | Gas Used / 5 | -60% |

## 💻 SSTORE 환불 비교

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StorageRefund {
    uint256 public value = 100;

    function deleteValue() external {
        delete value;  // 100 → 0

        // Before EIP-3529:
        // 비용: 5,000 gas (SSTORE)
        // 환불: 15,000 gas
        // 순비용: -10,000 gas (이득!)

        // After EIP-3529:
        // 비용: 5,000 gas (SSTORE)
        // 환불: 4,800 gas
        // 순비용: +200 gas (실제 비용)
    }

    function setValue(uint256 newValue) external {
        value = newValue;
        // 0 → non-zero: 20,000 gas (환불 없음)
        // non-zero → non-zero: 2,900 gas (환불 없음)
    }
}
```

## 🚫 SELFDESTRUCT 환불 제거

```solidity
contract SelfDestructExample {
    function destroy() external {
        selfdestruct(payable(msg.sender));

        // Before EIP-3529:
        // 비용: 5,000 gas
        // 환불: 24,000 gas
        // 순비용: -19,000 gas (큰 이득!)

        // After EIP-3529:
        // 비용: 5,000 gas
        // 환불: 0 gas
        // 순비용: 5,000 gas (환불 없음)
    }
}

// ⚠️ 주의: EIP-6780 (Cancun 2024)에서 SELFDESTRUCT는 더욱 제한됨
// → 같은 트랜잭션 내에서만 삭제 가능
```

## 💰 GasToken 차단

```solidity
// ❌ GasToken 패턴 (EIP-3529으로 차단됨)
contract GasToken {
    mapping(uint256 => uint256) public tokens;

    // 가스 가격 낮을 때: mint
    function mint(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            tokens[i] = 1;  // 20,000 gas
        }
    }

    // 가스 가격 높을 때: burn
    function burn(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            delete tokens[i];
            // Before: 15,000 gas 환불 → 이익!
            // After: 4,800 gas 환불 → 이익 거의 없음
        }
    }
}

// Before EIP-3529:
// 100개 burn: -1,210,000 gas 환불 → 가스 차익 가능
//
// After EIP-3529:
// 100개 burn: -190,000 gas 환불 → 이익 84% 감소
// → 경제적으로 의미 없음 (차단 성공!)
```

## 🔄 마이그레이션 패턴

### ❌ Before: 환불 의존 패턴

```solidity
contract OldPattern {
    mapping(address => uint256) public balances;

    function batchClear(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; i++) {
            delete balances[users[i]];
            // 15,000 gas 환불 기대
        }
    }

    function useTempContract() external {
        TempContract temp = new TempContract();
        temp.doWork();
        temp.destroy();  // 24,000 gas 환불 기대
    }
}
```

### ✅ After: 환불 비의존 패턴

```solidity
contract NewPattern {
    mapping(address => uint256) public balances;
    mapping(address => bool) public isActive;

    // 옵션 1: Lazy Deletion (플래그 사용)
    function deactivate(address user) external {
        isActive[user] = false;
        // delete보다 저렴할 수 있음
    }

    function getBalance(address user) external view returns (uint256) {
        if (!isActive[user]) return 0;
        return balances[user];
    }

    // 옵션 2: Pool 패턴 (재사용)
    TempContract[] public pool;

    function useTempContract() external {
        TempContract temp;

        if (pool.length > 0) {
            temp = pool[pool.length - 1];
            pool.pop();
        } else {
            temp = new TempContract();
        }

        temp.doWork();
        pool.push(temp);  // 재사용을 위해 반환
        // destroy 호출 안 함!
    }
}
```

## 📊 최대 환불 한도

```javascript
// 트랜잭션 예시

// Before EIP-3529:
// Gas Used: 100,000 gas
// Total Refund: 30,000 gas
// Max Refund: 100,000 / 2 = 50,000 gas
// Actual Refund: 30,000 gas
// Final Cost: 70,000 gas

// After EIP-3529:
// Gas Used: 100,000 gas
// Total Refund: 30,000 gas
// Max Refund: 100,000 / 5 = 20,000 gas
// Actual Refund: 20,000 gas (한도 적용!)
// Final Cost: 80,000 gas

// 차이: 10,000 gas (14% 증가)
```

## 🎯 최적화 팁

```solidity
// Tip 1: 불필요한 delete 피하기
contract Optimized {
    mapping(address => uint256) public data;
    mapping(address => bool) public isValid;

    // ❌ 비효율적
    function removeOld() external {
        delete data[msg.sender];  // 환불 감소로 비효율적
    }

    // ✅ 효율적
    function deactivate() external {
        isValid[msg.sender] = false;  // 플래그만 변경
    }
}

// Tip 2: 컨트랙트 재사용
contract Reusable {
    TempContract public instance;

    // ❌ 비효율적
    function createAndDestroy() external {
        TempContract temp = new TempContract();
        temp.work();
        temp.destroy();  // 환불 없음
    }

    // ✅ 효율적
    function reuseInstance() external {
        if (address(instance) == address(0)) {
            instance = new TempContract();
        }
        instance.work();  // 재사용
    }
}

// Tip 3: Lazy Deletion
contract LazyDeletion {
    uint256[] public data;
    uint256 public validLength;

    // ❌ 비효율적
    function hardDelete(uint256 index) external {
        delete data[index];  // 환불 적음
    }

    // ✅ 효율적
    function softDelete() external {
        validLength = 0;  // 논리적 삭제
    }
}
```

## ⚠️ 주의사항

```solidity
// 1. delete는 여전히 유용 (보안상 필요)
contract SafeWithdraw {
    mapping(address => uint256) public balances;

    // ✅ 좋은 사용: 재진입 방어
    function withdraw() external {
        uint256 balance = balances[msg.sender];
        delete balances[msg.sender];  // 재진입 방어!

        payable(msg.sender).transfer(balance);
    }
}

// 2. 기존 컨트랙트는 정상 작동하지만 가스 증가
contract ExistingContract {
    function cleanup() external {
        // 이미 배포된 컨트랙트
        // → 정상 작동하지만 가스 비용 증가
        delete data;
    }
}

// 3. SELFDESTRUCT 사용 최소화
contract ModernContract {
    // ❌ SELFDESTRUCT 사용 지양
    function destroy() external {
        selfdestruct(payable(msg.sender));
    }

    // ✅ 대안: disable 패턴
    bool public disabled;

    function disable() external {
        disabled = true;
    }

    modifier whenEnabled() {
        require(!disabled, "Contract disabled");
        _;
    }
}
```

## 📅 타임라인

```
London 하드포크 (2021년 8월 5일)
├── EIP-1559: Fee Market
└── EIP-3529: Refund Reduction

Cancun 하드포크 (2024년 3월)
└── EIP-6780: SELFDESTRUCT 더욱 제한
```

## 💡 핵심 요약

```
┌─────────────────────────────────────┐
│   EIP-3529 한눈에 보기               │
├─────────────────────────────────────┤
│                                     │
│  📉 SSTORE 환불: -68%               │
│  🚫 SELFDESTRUCT 환불: -100%        │
│  📊 최대 환불 한도: -60%             │
│                                     │
│  🎯 목표:                           │
│  • GasToken 차단 ✅                 │
│  • 블록 크기 예측 ✅                │
│  • 네트워크 안정성 ✅               │
│                                     │
│  ⚡ 영향:                           │
│  • Storage 삭제 비용 증가           │
│  • SELFDESTRUCT 환불 없음           │
│  • GasToken 경제성 상실             │
│                                     │
└─────────────────────────────────────┘

권장 사항:
✅ 환불에 의존하지 않는 설계
✅ SELFDESTRUCT 사용 최소화
✅ Lazy deletion 패턴 사용
✅ 컨트랙트 재사용
✅ 플래그 기반 무효화

주의:
❌ delete 환불 기대 금지
❌ SELFDESTRUCT 남용 금지
❌ GasToken 패턴 사용 불가
```

## 📚 참고 자료

**공식 문서**
- [EIP-3529 Specification](https://eips.ethereum.org/EIPS/eip-3529)
- [London Upgrade](https://ethereum.org/en/history/#london)
- [EIP-1559: Fee Market](https://eips.ethereum.org/EIPS/eip-1559)

**관련 EIP**
- [EIP-2929: Gas Cost Increases](https://eips.ethereum.org/EIPS/eip-2929)
- [EIP-6780: SELFDESTRUCT Changes](https://eips.ethereum.org/EIPS/eip-6780)
- [EIP-2930: Access Lists](https://eips.ethereum.org/EIPS/eip-2930)

## 🔑 핵심 기억할 것

```solidity
// 1. SSTORE 환불 감소
delete value;  // Before: -12,100 gas → After: -1,900 gas

// 2. SELFDESTRUCT 환불 제거
selfdestruct(addr);  // Before: -19,000 gas → After: 0 gas

// 3. 최대 환불 한도 감소
// Before: Gas Used / 2
// After: Gas Used / 5

// 4. GasToken 차단
// 경제적 이익이 84% 감소 → 사용 불가능

// 5. 마이그레이션
// - Lazy deletion 패턴
// - Pool/Singleton 패턴
// - 플래그 기반 무효화
```

**EIP-3529는 가스 환불을 축소하여 네트워크 안정성과 예측 가능성을 크게 향상시켰습니다!** 🚀

---

**마지막 업데이트: 2025-11-05**

