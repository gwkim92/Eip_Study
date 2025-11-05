# EIP-3529: Reduction in Refunds

> **가스 환불 메커니즘 축소로 네트워크 안정성 향상** ⛽🔒

## 📚 목차

- [개요](#개요)
- [핵심 변경사항](#핵심-변경사항)
- [기존 문제점](#기존-문제점)
- [변경 내용](#변경-내용)
- [영향 받는 패턴](#영향-받는-패턴)
- [마이그레이션 가이드](#마이그레이션-가이드)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

### EIP-3529란?

EIP-3529는 **가스 환불(Gas Refund) 메커니즘을 대폭 축소**하여, 블록 크기 예측을 개선하고 GasToken과 같은 악용 사례를 방지하는 EIP입니다.

```
┌─────────────────────────────────────────────┐
│       EIP-3529: Gas Refund Reduction        │
├─────────────────────────────────────────────┤
│                                             │
│  변경 1: SSTORE 환불 감소                    │
│  - 15,000 gas → 4,800 gas (68% 감소)        │
│                                             │
│  변경 2: SELFDESTRUCT 환불 제거              │
│  - 24,000 gas → 0 gas (100% 제거)           │
│                                             │
│  목표:                                      │
│  ⚠️ GasToken 악용 차단                      │
│  📊 블록 크기 예측 가능                      │
│  🔒 네트워크 안정성 향상                     │
│                                             │
└─────────────────────────────────────────────┘
```

### 왜 필요한가?

기존 가스 환불 메커니즘은 **GasToken**과 같은 악용 사례를 만들어냈습니다:

```solidity
// ❌ 문제: GasToken 패턴 (EIP-3529 이전)

// 1. 가스 가격이 낮을 때: 스토리지 채우기
contract GasToken {
    mapping(uint256 => uint256) public data;

    function mint(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            data[totalSupply + i] = 1;  // SSTORE: 0→1 (20,000 gas)
        }
        // 가스 가격 1 gwei일 때: 20,000 × 1 = 20,000 gwei 지불
    }

    function burn(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            delete data[i];  // SSTORE: 1→0 (2,900 gas - 15,000 refund)
        }
        // 가스 가격 100 gwei일 때:
        // 지불: 2,900 × 100 = 290,000 gwei
        // 환불: 15,000 × 100 = 1,500,000 gwei
        // 순이익: 1,210,000 gwei! 💰
    }
}

// 문제점:
// - 가스 가격이 낮을 때 "저장"하고 높을 때 "사용"
// - 블록 가스 한도를 초과하는 환불 발생
// - 블록 크기 예측 불가
```

### 주요 특징

| 특징 | 설명 |
|-----|------|
| **SSTORE 환불 감소** | 15,000 gas → 4,800 gas (68% 감소) |
| **SELFDESTRUCT 환불 제거** | 24,000 gas → 0 gas (100% 제거) |
| **GasToken 차단** | 경제적 이익 제거 |
| **블록 크기 예측** | 환불로 인한 블록 크기 변동 감소 |

### 활성화 시기

- **하드포크**: London (2021년 8월 5일)
- **블록 번호**: 12,965,000 (Mainnet)
- **EIP-1559와 함께 도입**: Fee Market 개선

---

## 핵심 변경사항

### 변경 사항 요약

| 항목 | Before (EIP-3529 이전) | After (EIP-3529 이후) | 변화 |
|------|------------------------|----------------------|------|
| **SSTORE 환불** (non-zero → 0) | 15,000 gas | **4,800 gas** | -68% |
| **SELFDESTRUCT 환불** | 24,000 gas | **0 gas** | -100% |
| **최대 환불** | Gas Used / 2 | **Gas Used / 5** | -60% |

### 1. SSTORE 환불 감소

```solidity
contract StorageRefund {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
        // SSTORE: 0 → non-zero
        // 비용: 20,000 gas
        // 환불: 0 gas
    }

    function deleteValue() external {
        delete value;
        // SSTORE: non-zero → 0

        // Before EIP-3529:
        // 비용: 2,900 gas
        // 환불: 15,000 gas
        // 순비용: -12,100 gas (이득!)

        // After EIP-3529:
        // 비용: 2,900 gas
        // 환불: 4,800 gas
        // 순비용: -1,900 gas (여전히 이득이지만 68% 감소)
    }
}
```

### 2. SELFDESTRUCT 환불 제거

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

        // 참고: EIP-6780 (Cancun, 2024)에서
        // selfdestruct는 더욱 제한됨
    }
}
```

### 3. 최대 환불 한도 감소

```
Before EIP-3529:
- 최대 환불: Gas Used / 2

예시: 100,000 gas 사용
- 최대 환불: 50,000 gas
- 실제 지불: 100,000 - 50,000 = 50,000 gas

After EIP-3529:
- 최대 환불: Gas Used / 5

예시: 100,000 gas 사용
- 최대 환불: 20,000 gas
- 실제 지불: 100,000 - 20,000 = 80,000 gas
```

---

## 기존 문제점

### 문제 1: GasToken 악용

**GasToken**은 가스 환불 메커니즘을 악용하여 가스 가격 차익을 얻는 토큰입니다:

```solidity
// GasToken 패턴 (EIP-3529 이전)
contract GasToken {
    mapping(uint256 => uint256) public tokens;
    uint256 public totalSupply;

    // 가스 가격이 낮을 때: "mint"
    function mint(uint256 count) external {
        uint256 startId = totalSupply;

        for (uint256 i = 0; i < count; i++) {
            tokens[startId + i] = 1;
            // SSTORE (0→1): 20,000 gas
        }

        totalSupply += count;

        // 예: 100개 mint
        // 비용: 20,000 × 100 = 2,000,000 gas
        // 가스 가격 1 gwei: 2,000,000 gwei = 0.002 ETH
    }

    // 가스 가격이 높을 때: "burn"
    function burn(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            delete tokens[i];
            // SSTORE (1→0): 2,900 gas - 15,000 refund
        }

        // 예: 100개 burn
        // 비용: 2,900 × 100 = 290,000 gas
        // 환불: 15,000 × 100 = 1,500,000 gas
        // 순환불: 1,210,000 gas

        // 가스 가격 100 gwei:
        // 지불: 290,000 × 100 = 29,000,000 gwei = 0.029 ETH
        // 환불: 1,210,000 × 100 = 121,000,000 gwei = 0.121 ETH
        // 순이익: 0.092 ETH (최초 투자 0.002 ETH에서 46배!)
    }
}
```

**문제점**:
- 가스 환불을 "저장"하고 나중에 "인출"
- 네트워크 혼잡도를 악화시킴
- 블록 가스 한도를 초과하는 환불 발생

### 문제 2: 블록 크기 예측 불가

```
시나리오: 블록 가스 한도 = 15,000,000 gas

트랜잭션 1: 10,000,000 gas 사용
트랜잭션 2: 8,000,000 gas 사용 (예상)

Before EIP-3529:
- 트랜잭션 2 환불: 4,000,000 gas
- 실제 블록 사용: 10,000,000 + (8,000,000 - 4,000,000) = 14,000,000 gas
- 예상보다 작음!

After EIP-3529:
- 트랜잭션 2 환불: 1,600,000 gas (8,000,000 / 5)
- 실제 블록 사용: 10,000,000 + (8,000,000 - 1,600,000) = 16,400,000 gas
- 예측 가능성 향상
```

### 문제 3: 무한 블록 크기 공격

환불이 너무 크면 **무한 블록 크기 공격**이 가능합니다:

```
공격 시나리오:
1. 100,000,000 gas 사용하는 트랜잭션 제출
2. 환불: 50,000,000 gas (Gas Used / 2)
3. 실제 비용: 50,000,000 gas

블록 가스 한도가 15,000,000 gas인데
실제로는 100,000,000 gas 작업 수행!

→ 블록 크기 폭발
→ 노드 동기화 실패
→ 네트워크 불안정
```

---

## 변경 내용

### Before vs After 비교

#### SSTORE 환불

```solidity
contract StorageRefund {
    uint256 public value = 100;  // 초기값

    function deleteValue() external {
        delete value;  // 100 → 0

        // Before EIP-3529:
        // SSTORE 비용: 2,900 gas
        // 환불: 15,000 gas
        // 순비용: 2,900 - 15,000 = -12,100 gas (이득)

        // After EIP-3529:
        // SSTORE 비용: 2,900 gas
        // 환불: 4,800 gas
        // 순비용: 2,900 - 4,800 = -1,900 gas (이득이지만 작음)
    }

    function resetValue() external {
        value = 100;

        // Before EIP-3529:
        // SSTORE 비용: 2,900 gas (warm)
        // 환불: 0 gas

        // After EIP-3529:
        // SSTORE 비용: 2,900 gas (warm)
        // 환불: 0 gas

        // 변화 없음 (0→non-zero가 아니므로)
    }
}
```

#### SELFDESTRUCT 환불

```solidity
contract FactoryPattern {
    // Before EIP-3529: SELFDESTRUCT를 이용한 "임시" 컨트랙트
    function createAndDestroy() external {
        TempContract temp = new TempContract();
        temp.doWork();
        temp.destroy();  // 24,000 gas 환불!

        // 순비용: 배포 비용 - 24,000 gas
        // → 매우 저렴한 임시 컨트랙트
    }

    // After EIP-3529: SELFDESTRUCT 환불 없음
    function createAndDestroy() external {
        TempContract temp = new TempContract();
        temp.doWork();
        temp.destroy();  // 0 gas 환불

        // 순비용: 배포 비용
        // → 환불 없으므로 비용 증가
    }
}

contract TempContract {
    function doWork() external {
        // 작업 수행
    }

    function destroy() external {
        selfdestruct(payable(msg.sender));
    }
}
```

---

## 영향 받는 패턴

### 1. Storage 정리 패턴

```solidity
// ❌ Before: 환불을 기대한 패턴
contract OldPattern {
    mapping(address => uint256) public balances;

    function batchClear(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; i++) {
            delete balances[users[i]];
            // Before: 각각 15,000 gas 환불 기대
            // After: 각각 4,800 gas 환불 (68% 감소)
        }
    }
}

// ✅ After: 환불이 줄어든 것을 고려
contract NewPattern {
    mapping(address => uint256) public balances;

    function batchClear(address[] calldata users) external {
        // 환불이 줄어들었으므로 가스 비용 재계산 필요
        // 대안: 필요한 경우에만 delete 사용

        for (uint256 i = 0; i < users.length; i++) {
            if (balances[users[i]] > 0) {
                delete balances[users[i]];
            }
        }
    }
}
```

### 2. Factory + SELFDESTRUCT 패턴

```solidity
// ❌ Before: SELFDESTRUCT 환불을 기대한 패턴
contract OldFactory {
    function createTempContract() external {
        TempContract temp = new TempContract();
        temp.execute();
        temp.destroy();  // 24,000 gas 환불 기대
    }
}

// ✅ After: SELFDESTRUCT 사용 최소화
contract NewFactory {
    // 대안 1: 재사용 가능한 컨트랙트
    TempContract public reusableContract;

    function useReusableContract() external {
        if (address(reusableContract) == address(0)) {
            reusableContract = new TempContract();
        }
        reusableContract.execute();
        // destroy 호출 안 함 → 재사용
    }

    // 대안 2: CREATE2로 결정적 주소
    function useDeterministicContract(bytes32 salt) external {
        address predicted = predictAddress(salt);

        if (predicted.code.length == 0) {
            TempContract temp = new TempContract{salt: salt}();
        }

        TempContract(predicted).execute();
    }
}
```

### 3. GasToken 패턴 (완전히 차단됨)

```solidity
// ❌ Before: GasToken (EIP-3529으로 차단됨)
contract GasToken {
    mapping(uint256 => uint256) public tokens;

    function mint(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            tokens[i] = 1;
            // 20,000 gas 비용
        }
    }

    function burn(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            delete tokens[i];
            // Before: 15,000 gas 환불 (경제적 이익)
            // After: 4,800 gas 환불 (경제적 이익 거의 없음)
        }

        // Before EIP-3529:
        // 100개 burn: 2,900 × 100 - 15,000 × 100 = -1,210,000 gas
        // 가스 가격 차이로 이익

        // After EIP-3529:
        // 100개 burn: 2,900 × 100 - 4,800 × 100 = -190,000 gas
        // 이익이 84% 감소 → 경제적으로 의미 없음
    }
}

// ✅ After: GasToken 사용 불가
// 대안: 없음 (GasToken은 악용 사례였으므로 차단이 목적)
```

---

## 마이그레이션 가이드

### 1. Storage 삭제를 사용하는 컨트랙트

**Before**:
```solidity
contract OldContract {
    mapping(address => uint256) public data;

    function cleanup(address user) external {
        delete data[user];
        // 15,000 gas 환불 기대
    }
}
```

**After**:
```solidity
contract NewContract {
    mapping(address => uint256) public data;

    function cleanup(address user) external {
        delete data[user];
        // 4,800 gas 환불 (68% 감소)
        // → 필요한 경우에만 cleanup 호출
    }

    // 대안: Lazy deletion (삭제하지 않고 무효화)
    mapping(address => bool) public isValid;

    function invalidate(address user) external {
        isValid[user] = false;
        // delete보다 가스 효율적일 수 있음
    }

    function getData(address user) external view returns (uint256) {
        if (!isValid[user]) return 0;
        return data[user];
    }
}
```

### 2. SELFDESTRUCT를 사용하는 컨트랙트

**Before**:
```solidity
contract OldFactory {
    function useTempContract() external {
        TempContract temp = new TempContract();
        temp.doWork();
        temp.destroy();  // 24,000 gas 환불
    }
}
```

**After**:
```solidity
contract NewFactory {
    // 대안 1: Pool 패턴
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
    }

    // 대안 2: Singleton 패턴
    TempContract public singleton;

    function useSingleton() external {
        if (address(singleton) == address(0)) {
            singleton = new TempContract();
        }
        singleton.doWork();
        // destroy 호출 안 함
    }
}
```

### 3. Gas 최적화 패턴 재평가

**Before**:
```solidity
contract OldOptimization {
    uint256[] public data;

    // 환불을 고려한 최적화
    function clearAll() external {
        for (uint256 i = 0; i < data.length; i++) {
            delete data[i];  // 각각 15,000 gas 환불
        }
        delete data;  // 배열 자체도 삭제
    }
}
```

**After**:
```solidity
contract NewOptimization {
    uint256[] public data;

    // 환불이 줄었으므로 다른 접근
    function clearAll() external {
        // 옵션 1: 새 배열로 교체 (환불 의존 안 함)
        delete data;  // 배열만 삭제
    }

    // 옵션 2: Lazy deletion
    mapping(uint256 => bool) public isDeleted;

    function markDeleted(uint256 index) external {
        isDeleted[index] = true;
        // 실제 삭제는 하지 않음
    }

    function getData(uint256 index) external view returns (uint256) {
        if (isDeleted[index]) return 0;
        return data[index];
    }
}
```

---

## FAQ

### Q1: EIP-3529는 어떤 컨트랙트에 영향을 주나요?

**A:**

영향 받는 컨트랙트:
- ✅ **SSTORE delete**를 많이 사용하는 컨트랙트
- ✅ **SELFDESTRUCT**를 사용하는 컨트랙트
- ✅ **GasToken** 패턴을 사용하는 컨트랙트

영향 없는 컨트랙트:
- ❌ Storage 읽기만 하는 컨트랙트
- ❌ Storage를 설정만 하고 삭제하지 않는 컨트랙트
- ❌ SELFDESTRUCT를 사용하지 않는 컨트랙트

### Q2: GasToken은 완전히 사용 불가능한가요?

**A:** **거의 불가능**합니다:

```
Before EIP-3529:
- Mint 100개: 2,000,000 gas (1 gwei = 0.002 ETH)
- Burn 100개: -1,210,000 gas 환불 (100 gwei = 0.121 ETH)
- 순이익: 0.119 ETH (5950% 이익!)

After EIP-3529:
- Mint 100개: 2,000,000 gas (1 gwei = 0.002 ETH)
- Burn 100개: -190,000 gas 환불 (100 gwei = 0.019 ETH)
- 순이익: 0.017 ETH (850% 이익)

하지만:
- 가스 가격 변동성 필요
- 트랜잭션 비용 고려 시 이익 거의 없음
- 경제적으로 의미 없음
```

### Q3: 기존 컨트랙트는 어떻게 되나요?

**A:** **이미 배포된 컨트랙트는 변경 없이 작동**하지만, 가스 비용이 증가합니다:

```solidity
// 이미 배포된 컨트랙트
contract ExistingContract {
    mapping(address => uint256) public balances;

    function withdraw() external {
        uint256 balance = balances[msg.sender];
        delete balances[msg.sender];  // 환불 감소

        // Before: -12,100 gas (환불)
        // After: -1,900 gas (환불)
        // 차이: 10,200 gas 더 비쌈

        payable(msg.sender).transfer(balance);
    }
}

// → 컨트랙트는 정상 작동하지만 사용자는 더 많은 가스 지불
```

### Q4: EIP-3529와 EIP-1559의 관계는?

**A:** **함께 도입**되어 **가스 시스템을 전반적으로 개선**합니다:

```
EIP-1559 (Fee Market):
- Base fee + Priority fee
- 가스 가격 예측 가능
- 블록 크기 탄력적 조정

EIP-3529 (Refund Reduction):
- 환불 감소로 블록 크기 예측 개선
- GasToken 차단
- EIP-1559와 시너지

London 하드포크 (2021-08-05):
→ EIP-1559 + EIP-3529 동시 활성화
→ 가스 시스템 전반 개선
```

### Q5: 왜 SELFDESTRUCT 환불을 완전히 제거했나요?

**A:**

1. **악용 방지**:
```solidity
// 악용 사례: 임시 컨트랙트로 가스 절감
for (uint256 i = 0; i < 100; i++) {
    TempContract temp = new TempContract();
    temp.doWork();
    temp.destroy();  // 24,000 gas × 100 = 2,400,000 gas 환불!
}
// → 실질적으로 거의 무료로 100개 컨트랙트 사용
```

2. **보안 향상**:
```
SELFDESTRUCT는 위험한 opcode:
- 컨트랙트 완전 삭제
- 재진입 공격 가능
- 예측 불가능한 동작

EIP-6780 (Cancun, 2024):
→ SELFDESTRUCT를 더욱 제한
→ 같은 트랜잭션 내에서만 삭제 가능
```

### Q6: delete를 사용하지 말아야 하나요?

**A:** **아니요**, delete는 여전히 유용하지만 **환불을 기대하지 마세요**:

```solidity
contract BestPractice {
    mapping(address => uint256) public balances;

    // ✅ 좋은 사용: 보안상 필요
    function withdraw() external {
        uint256 balance = balances[msg.sender];
        delete balances[msg.sender];  // 재진입 방어

        payable(msg.sender).transfer(balance);
    }

    // ❌ 나쁜 사용: 환불만을 위한 삭제
    function unnecessaryCleanup() external {
        // 환불이 줄었으므로 불필요한 삭제는 비효율적
        for (uint256 i = 0; i < 1000; i++) {
            delete oldData[i];  // 환불보다 비용이 더 클 수 있음
        }
    }
}
```

### Q7: EIP-3529 이후 가스 최적화 팁은?

**A:**

```solidity
// Tip 1: 불필요한 delete 피하기
contract Optimized {
    mapping(address => uint256) public data;
    mapping(address => bool) public isActive;

    // ❌ 비효율적
    function removeOld() external {
        delete data[msg.sender];  // 2,900 gas - 4,800 refund
    }

    // ✅ 효율적
    function deactivate() external {
        isActive[msg.sender] = false;  // 단순 플래그 (저렴)
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
        instance.work();
        // destroy 안 함 → 재사용
    }
}

// Tip 3: Lazy deletion
contract LazyDeletion {
    uint256[] public data;
    uint256 public validLength;

    // ❌ 비효율적
    function hardDelete(uint256 index) external {
        delete data[index];
    }

    // ✅ 효율적
    function softDelete() external {
        validLength = 0;  // 논리적 삭제
        // 실제 delete는 하지 않음
    }
}
```

### Q8: EIP-3529는 DeFi에 어떤 영향을 주나요?

**A:**

```
영향 1: Liquidity Pool 청산
- Uniswap, Aave 등에서 포지션 청산 시 delete 사용
- 환불 감소 → 청산 가스 비용 증가
- 영향: 소폭 증가 (~10-15%)

영향 2: Token 전송
- ERC20 approve/transfer에서 allowance delete
- 환불 감소 → 전송 비용 소폭 증가
- 영향: 미미함

영향 3: GasToken 차단
- Chi, GST2 등 GasToken 사용 불가
- 긍정적 영향: 네트워크 안정성 향상

영향 4: Compound/Aave
- 대출 상환 시 storage 정리
- 환불 감소로 상환 비용 증가
- 영향: 약 5-10% 증가
```

### Q9: 최대 환불 한도(Gas Used / 5)는 어떻게 작동하나요?

**A:**

```javascript
// 트랜잭션 예시
const tx = await contract.complexOperation();

// Before EIP-3529:
// Gas Used: 100,000 gas
// Total Refund: 30,000 gas (delete 6번)
// Max Refund: 100,000 / 2 = 50,000 gas
// Actual Refund: 30,000 gas (max보다 작음)
// Final Cost: 100,000 - 30,000 = 70,000 gas

// After EIP-3529:
// Gas Used: 100,000 gas
// Total Refund: 30,000 gas (4,800 × 6 = 28,800)
// Max Refund: 100,000 / 5 = 20,000 gas
// Actual Refund: 20,000 gas (max 한도 적용!)
// Final Cost: 100,000 - 20,000 = 80,000 gas

// 차이: 10,000 gas (14% 증가)
```

### Q10: 향후 가스 환불은 어떻게 될까요?

**A:**

```
EIP-3529 (London, 2021):
→ 환불 대폭 감소

EIP-6780 (Cancun, 2024):
→ SELFDESTRUCT 더욱 제한
→ 같은 트랜잭션 내에서만 삭제 가능

미래 전망:
→ 환불 메커니즘 더욱 축소 가능
→ SELFDESTRUCT 완전 제거 논의 중
→ Storage 비용 재조정 예정

권장 사항:
✅ 환불에 의존하지 않는 설계
✅ SELFDESTRUCT 사용 최소화
✅ 재사용 가능한 컨트랙트 설계
```

---

## 참고 자료

### 공식 문서

- [EIP-3529 Specification](https://eips.ethereum.org/EIPS/eip-3529)
- [Ethereum London Upgrade](https://ethereum.org/en/history/#london)
- [EIP-1559: Fee Market](https://eips.ethereum.org/EIPS/eip-1559)

### 관련 EIP

- [EIP-2929: Gas Cost Increases](https://eips.ethereum.org/EIPS/eip-2929) - Cold/warm access
- [EIP-6780: SELFDESTRUCT Changes](https://eips.ethereum.org/EIPS/eip-6780) - Cancun 하드포크
- [EIP-2930: Access Lists](https://eips.ethereum.org/EIPS/eip-2930)

### 커뮤니티 리소스

- [EIP-3529 Discussion](https://ethereum-magicians.org/t/eip-3529-reduction-in-refunds/6097)
- [London Upgrade FAQ](https://ethereum.org/en/history/#london)

---

## 요약

### 핵심 포인트

```
┌─────────────────────────────────────────────┐
│       EIP-3529 한눈에 보기                   │
├─────────────────────────────────────────────┤
│                                             │
│  📉 SSTORE 환불 감소                         │
│  - 15,000 gas → 4,800 gas (68% 감소)        │
│                                             │
│  🚫 SELFDESTRUCT 환불 제거                  │
│  - 24,000 gas → 0 gas (100% 제거)           │
│                                             │
│  📊 최대 환불 한도 감소                      │
│  - Gas Used / 2 → Gas Used / 5 (60% 감소)  │
│                                             │
│  🎯 목표 달성:                              │
│  ⚠️ GasToken 차단                          │
│  📈 블록 크기 예측 가능                     │
│  🔒 네트워크 안정성 향상                    │
│                                             │
│  📅 London 하드포크 (2021년 8월)            │
│                                             │
└─────────────────────────────────────────────┘

영향:
→ Storage 삭제 비용 증가
→ SELFDESTRUCT 환불 없음
→ GasToken 경제성 상실

마이그레이션:
✅ 환불에 의존하지 않는 설계
✅ SELFDESTRUCT 사용 최소화
✅ 재사용 가능한 컨트랙트
✅ Lazy deletion 패턴

주의:
❌ 기존 컨트랙트 가스 비용 증가
❌ Delete 기반 최적화 효과 감소
❌ Factory 패턴 비용 증가
```

**EIP-3529는 가스 환불 메커니즘을 개선하여 네트워크의 예측 가능성과 안정성을 크게 향상시켰습니다!** 🚀

**마지막 업데이트: 2025**
