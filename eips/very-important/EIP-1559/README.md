# EIP-1559: Fee Market Change (가스비 시장 개선)

> **한 줄 요약**: 이더리움 거래 수수료를 예측 가능하고 공정하게 만들어주는 새로운 가스비 메커니즘

📌 **[치트시트 보기](./CHEATSHEET.md)** - 빠른 참고용 코드 모음

## 핵심만 빠르게

```solidity
// ❌ Before EIP-1559: 가스비 추측 게임
transaction = {
    gasPrice: 150 gwei,  // 이게 맞을까? 너무 높은가? 낮은가?
    gasLimit: 21000
}

// ✅ After EIP-1559: 명확하고 예측 가능
transaction = {
    maxFeePerGas: 100 gwei,           // 최대 지불 의사
    maxPriorityFeePerGas: 2 gwei,    // 채굴자 팁
    gasLimit: 21000
}
// 실제 지불 = baseFee + priorityFee (초과분은 자동 환불!)
```

### 3줄 요약
1. **문제**: 기존 가스비는 예측 불가능하고 불공정한 경매 방식
2. **해결**: Base Fee(자동 조정) + Priority Fee(팁) 이중 구조 도입
3. **효과**: 예측 가능한 수수료 + ETH 디플레이션 + 더 나은 UX

### 실무에서 왜 중요한가?
- ✅ **거래소**: 출금 수수료를 정확하게 예측 가능
- ✅ **NFT 민팅**: 가스비 폭등 시 자동 대응
- ✅ **DeFi 프로토콜**: 차익거래 봇의 gas war 완화
- ✅ **지갑 개발**: 사용자 친화적인 수수료 UI 구현

---

## 목차
1. [EIP-1559가 왜 필요한가?](#왜-필요한가)
2. [동작 원리 (한눈에 보기)](#동작-원리-한눈에-보기)
3. [핵심 개념](#핵심-개념)
4. [Base Fee 알고리즘](#base-fee-알고리즘)
5. [Before vs After 비교](#before-vs-after-비교)
6. [실전 구현 패턴](#실전-구현-패턴)
7. [ethers.js 통합](#ethersjs-통합)
8. [실무 활용 예제](#실무-활용-예제)
9. [가스 최적화 전략](#가스-최적화-전략)
10. [주의사항과 베스트 프랙티스](#주의사항)

---

## 왜 필요한가?

### 문제 상황: Legacy 가스비 시스템의 한계

```solidity
// Before EIP-1559: First-Price Auction (최고가 입찰)
// 문제 1: 가스비 예측 불가능
{
    gasPrice: ???  // 50 gwei? 100 gwei? 200 gwei?
}

// 문제 2: 과다 지불 또는 실패
if (gasPrice < networkCongestion) {
    // 거래 실패 또는 무한 대기
} else if (gasPrice > needed) {
    // 필요 이상 지불 (환불 없음!)
}

// 문제 3: 채굴자와의 불공정한 게임
// 채굴자가 일부러 블록을 비워두고 높은 가스비를 유도할 수 있음
```

**실제 사례 (2021년 5월):**
```
ETH 가격: $4000
일반 이체 가스비: 평균 $50-100
NFT 민팅: $300-500
유니스왑 거래: $100-200

문제: 사람들이 "적정 가스비"를 알 수 없어서
      너무 높게 설정하거나, 낮게 설정해서 실패함
```

### EIP-1559의 해결책

```
┌─────────────────────────────────────────────────────────────┐
│                  EIP-1559 핵심 아이디어                       │
│                                                               │
│  거래 수수료 = Base Fee (자동 조정) + Priority Fee (팁)      │
│                    │                           │              │
│                    │                           └─ 채굴자에게  │
│                    └─ 소각 (Burn) 🔥                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 동작 원리 (한눈에 보기)

### 전체 흐름도

```
1. 사용자가 거래 제출
┌──────────────────────────────────────────┐
│  Transaction (Type 2 - EIP-1559)         │
│  ─────────────────────────────────       │
│  maxFeePerGas: 100 gwei                  │
│  maxPriorityFeePerGas: 2 gwei            │
│  gasLimit: 50000                         │
└────────────────┬─────────────────────────┘
                 │
                 ▼
2. 현재 블록의 Base Fee 확인
┌──────────────────────────────────────────┐
│  Block #15537394                         │
│  ─────────────────────────────────       │
│  baseFeePerGas: 30 gwei                  │
│  gasUsed: 15.2M / 30M (50.6%)            │
│  timestamp: 2022-09-15 06:42:47 UTC      │
└────────────────┬─────────────────────────┘
                 │
                 ▼
3. Effective Gas Price 계산
┌──────────────────────────────────────────┐
│  Calculation:                            │
│  ─────────────────────────────────       │
│  priorityFee = min(                      │
│    maxPriorityFeePerGas,                 │
│    maxFeePerGas - baseFee                │
│  ) = min(2, 100-30) = 2 gwei             │
│                                          │
│  effectiveGasPrice = baseFee +           │
│    priorityFee = 30 + 2 = 32 gwei        │
└────────────────┬─────────────────────────┘
                 │
                 ▼
4. 실제 비용 및 환불 계산
┌──────────────────────────────────────────┐
│  Gas Accounting:                         │
│  ─────────────────────────────────       │
│  gasUsed: 21000                          │
│  totalCost = 32 gwei × 21000             │
│           = 672,000 gwei                 │
│           = 0.000672 ETH                 │
│                                          │
│  Refund:                                 │
│  refund = (100 - 32) × 21000             │
│        = 1,428,000 gwei                  │
│        = 0.001428 ETH                    │
│                                          │
│  Base Fee Burned: 30 × 21000 = 630k gwei│
│  Miner Tip: 2 × 21000 = 42k gwei         │
└──────────────────────────────────────────┘
```

### Base Fee 자동 조정 메커니즘

```
블록 상태에 따라 Base Fee 자동 조정 (매 블록마다)

┌─────────────────────────────────────────────────────────┐
│  이전 블록 가스 사용량 > 타겟 (15M gas)                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                │
│  네트워크 혼잡! → Base Fee 증가 (최대 12.5%)             │
│                                                           │
│  30 gwei → 33.75 gwei (+12.5%)                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  이전 블록 가스 사용량 = 타겟 (15M gas)                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                │
│  완벽한 균형! → Base Fee 유지                            │
│                                                           │
│  30 gwei → 30 gwei (변화 없음)                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  이전 블록 가스 사용량 < 타겟 (15M gas)                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                │
│  네트워크 여유! → Base Fee 감소 (최대 12.5%)             │
│                                                           │
│  30 gwei → 26.25 gwei (-12.5%)                           │
└─────────────────────────────────────────────────────────┘
```

---

## 핵심 개념

### 1. Base Fee (기본 수수료)

```solidity
// Solidity에서 Base Fee 접근
uint256 currentBaseFee = block.basefee;  // BASEFEE opcode (0x48)
```

**특징:**
- 프로토콜이 **자동으로 계산** (사용자가 설정 ❌)
- 네트워크 혼잡도에 따라 **매 블록마다 조정**
- **소각됨 (Burn)**: 채굴자에게 가지 않고 영구 제거
- 이더리움을 **디플레이션 자산**으로 변환

**Base Fee 범위 (2023년 기준):**
```
한산한 시간: 10-20 gwei
보통: 20-50 gwei
혼잡: 50-100 gwei
극심한 혼잡 (NFT 드롭 등): 100-500 gwei
역대 최고: 1000+ gwei (2021년 NFT 광풍)
```

### 2. Priority Fee (우선순위 수수료 / 팁)

```solidity
// 실제 Priority Fee 계산
uint256 priorityFee = min(
    maxPriorityFeePerGas,
    maxFeePerGas - block.basefee
);

// 채굴자 수입
uint256 minerTip = priorityFee * gasUsed;
```

**특징:**
- 사용자가 **자유롭게 설정**
- 채굴자에게 직접 지급 (인센티브)
- 높을수록 빠른 포함 (하지만 Base Fee만큼 중요하지 않음)
- 일반적으로 **1-3 gwei** 수준

**Priority Fee 전략:**
```
급한 거래 (Fast): 3-5 gwei
보통 (Standard): 1-2 gwei
천천히 (Slow): 0.5-1 gwei
```

### 3. Max Fee Per Gas (최대 가스비)

```solidity
// 안전 장치: 이 이상은 절대 지불하지 않겠다
maxFeePerGas >= block.basefee + maxPriorityFeePerGas

// 실제 사용 예
{
    maxFeePerGas: 100 gwei,           // 최대 지불 의사
    maxPriorityFeePerGas: 2 gwei,    // 채굴자 팁

    // 현재 Base Fee가 30 gwei라면
    // → 실제 지불: 32 gwei (30 + 2)
    // → 환불: 68 gwei (100 - 32)
}
```

**설정 팁:**
```javascript
// 권장: Base Fee의 2배 + Priority Fee
const baseFee = await block.baseFeePerGas;
const maxFee = baseFee * 2 + priorityFee;
```

### 4. Effective Gas Price (실제 가스비)

```solidity
// 사용자가 실제로 지불하는 가격
uint256 effectiveGasPrice = block.basefee + min(
    maxPriorityFeePerGas,
    maxFeePerGas - block.basefee
);

// 총 비용
uint256 totalFee = effectiveGasPrice * gasUsed;

// 환불액
uint256 refund = (maxFeePerGas - effectiveGasPrice) * gasUsed;
```

**예제:**
```
설정:
  maxFeePerGas: 100 gwei
  maxPriorityFeePerGas: 2 gwei
  gasUsed: 21000

시나리오 1: Base Fee = 30 gwei
  effectiveGasPrice = 30 + min(2, 100-30) = 32 gwei
  총 비용 = 32 × 21000 = 672,000 gwei
  환불 = (100-32) × 21000 = 1,428,000 gwei

시나리오 2: Base Fee = 95 gwei
  effectiveGasPrice = 95 + min(2, 100-95) = 100 gwei
  총 비용 = 100 × 21000 = 2,100,000 gwei
  환불 = 0 gwei (maxFee 전액 사용)
```

---

## Base Fee 알고리즘

### 블록 크기와 타겟

```solidity
// EIP-1559 이전
uint256 constant BLOCK_GAS_LIMIT = 15_000_000;  // 고정

// EIP-1559 이후
uint256 constant BLOCK_GAS_TARGET = 15_000_000;  // 목표치
uint256 constant BLOCK_GAS_LIMIT = 30_000_000;   // 최대치 (2x)

// 탄력성: 수요가 많을 때 블록 크기를 2배까지 늘릴 수 있음
```

**왜 2배인가?**
```
평상시: 15M gas 사용 (50% 활용)
혼잡 시: 30M gas 사용 (100% 활용)

→ 단기적으로 수요 급증에 대응
→ Base Fee 증가로 장기적으로 수요 조절
```

### Base Fee 계산 공식

```solidity
/**
 * @notice 다음 블록의 Base Fee 계산
 * @dev EIP-1559 핵심 알고리즘
 */
function calculateNextBaseFee(
    uint256 currentBaseFee,
    uint256 parentGasUsed,
    uint256 parentGasTarget  // = parentGasLimit / 2
) public pure returns (uint256) {
    // 케이스 1: 가스 사용량 = 타겟 → 유지
    if (parentGasUsed == parentGasTarget) {
        return currentBaseFee;
    }

    // 케이스 2: 가스 사용량 > 타겟 → 증가
    if (parentGasUsed > parentGasTarget) {
        uint256 gasUsedDelta = parentGasUsed - parentGasTarget;
        uint256 baseFeePerGasDelta = max(
            currentBaseFee * gasUsedDelta / parentGasTarget / 8,
            1  // 최소 1 wei 증가
        );
        return currentBaseFee + baseFeePerGasDelta;
    }

    // 케이스 3: 가스 사용량 < 타겟 → 감소
    else {
        uint256 gasUsedDelta = parentGasTarget - parentGasUsed;
        uint256 baseFeePerGasDelta =
            currentBaseFee * gasUsedDelta / parentGasTarget / 8;
        return currentBaseFee - baseFeePerGasDelta;
    }
}

function max(uint256 a, uint256 b) private pure returns (uint256) {
    return a > b ? a : b;
}
```

**공식 해설:**
```
변화량 = currentBaseFee × (사용량 - 타겟) / 타겟 / 8

분모의 8 = 12.5% 조정
  → 블록이 100% 찬 경우: 12.5% 증가
  → 블록이 0% 찬 경우: 12.5% 감소
```

### Base Fee 변화 시뮬레이션

```
초기 Base Fee: 100 gwei
타겟: 15M gas

┌─────┬──────────┬─────────┬─────────────────────────┐
│블록 │ 가스사용 │BaseFee  │ 계산                     │
├─────┼──────────┼─────────┼─────────────────────────┤
│  0  │ 30M 100% │ 100 gwei│ 초기값                   │
│  1  │ 30M 100% │ 112.5   │ 100 + 100×15M/15M/8      │
│  2  │ 30M 100% │ 126.6   │ 112.5 + 112.5×15M/15M/8  │
│  3  │ 30M 100% │ 142.4   │ 126.6 × 1.125            │
│  4  │ 30M 100% │ 160.2   │ 142.4 × 1.125            │
│  5  │ 30M 100% │ 180.2   │ 160.2 × 1.125            │
└─────┴──────────┴─────────┴─────────────────────────┘

┌─────┬──────────┬─────────┬─────────────────────────┐
│블록 │ 가스사용 │BaseFee  │ 계산                     │
├─────┼──────────┼─────────┼─────────────────────────┤
│  0  │  0M   0% │ 100 gwei│ 초기값                   │
│  1  │  0M   0% │  87.5   │ 100 - 100×15M/15M/8      │
│  2  │  0M   0% │  76.6   │  87.5 × 0.875            │
│  3  │  0M   0% │  67.0   │  76.6 × 0.875            │
│  4  │  0M   0% │  58.6   │  67.0 × 0.875            │
│  5  │  0M   0% │  51.3   │  58.6 × 0.875            │
└─────┴──────────┴─────────┴─────────────────────────┘
```

**핵심 인사이트:**
- 블록이 지속적으로 가득 차면 8블록마다 **2배** 증가
- 블록이 지속적으로 비면 8블록마다 **절반** 감소
- **자동 조절**: 가격이 오르면 수요 감소 → 가격 하락 → 균형

---

## Before vs After 비교

### Legacy Transaction (Type 0)

```javascript
// Before EIP-1559
const tx = {
    to: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    value: ethers.parseEther("1.0"),
    gasPrice: ethers.parseUnits("100", "gwei"),  // 추측!
    gasLimit: 21000,
    nonce: 5,
    chainId: 1
}

// 문제점:
// 1. gasPrice를 얼마로 해야 할지 모름
// 2. 100 gwei로 설정했는데 실제 필요는 50 gwei였다면?
//    → 50 gwei 손해 (환불 없음)
// 3. 100 gwei로 설정했는데 네트워크가 혼잡해서 150 gwei 필요?
//    → 거래 실패 또는 무한 대기
```

### EIP-1559 Transaction (Type 2)

```javascript
// After EIP-1559
const tx = {
    to: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    value: ethers.parseEther("1.0"),
    maxFeePerGas: ethers.parseUnits("100", "gwei"),         // 최대 의사
    maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),  // 팁
    gasLimit: 21000,
    nonce: 5,
    chainId: 1,
    type: 2  // EIP-1559
}

// 장점:
// 1. Base Fee는 프로토콜이 자동 계산 → 예측 가능
// 2. 초과 지불분은 자동 환불
// 3. maxFee만 적절히 설정하면 됨 (baseFee × 2 정도)
```

### 비용 비교 예제

```
상황: ETH를 전송하고 싶은데, 현재 Base Fee = 30 gwei

┌────────────────────────────────────────────────────────────┐
│                  Legacy (Type 0)                            │
├────────────────────────────────────────────────────────────┤
│  설정: gasPrice = 100 gwei (안전하게 높게 잡음)            │
│  실제 필요: 30 gwei                                        │
│  지불: 100 × 21000 = 2,100,000 gwei (0.0021 ETH)           │
│  손실: 70 × 21000 = 1,470,000 gwei (0.00147 ETH) ❌        │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                  EIP-1559 (Type 2)                          │
├────────────────────────────────────────────────────────────┤
│  설정:                                                     │
│    maxFeePerGas = 100 gwei                                 │
│    maxPriorityFeePerGas = 2 gwei                           │
│  실제 지불:                                                │
│    effectivePrice = 30 + 2 = 32 gwei                       │
│  지불: 32 × 21000 = 672,000 gwei (0.000672 ETH)            │
│  환불: 68 × 21000 = 1,428,000 gwei (0.001428 ETH) ✅       │
└────────────────────────────────────────────────────────────┘

절약: 0.00147 ETH
ETH 가격 $2000 기준: $2.94 절약
```

---

## 실전 구현 패턴

### 패턴 1: Base Fee 확인 및 제한

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BaseFeeChecker {
    /**
     * @notice 현재 Base Fee 조회
     * @dev Solidity 0.8.7+ 필요
     */
    function getCurrentBaseFee() public view returns (uint256) {
        return block.basefee;  // BASEFEE opcode (0x48)
    }

    /**
     * @notice Base Fee가 허용 범위인지 확인
     */
    function isBaseFeeAcceptable(uint256 maxAcceptable)
        public
        view
        returns (bool)
    {
        return block.basefee <= maxAcceptable;
    }

    /**
     * @notice Base Fee 제한 modifier
     * @dev 가스비가 높을 때 실행 방지
     */
    modifier maxBaseFee(uint256 maxFee) {
        require(block.basefee <= maxFee, "Base fee too high");
        _;
    }

    /**
     * @notice 가스비가 낮을 때만 실행되는 함수
     */
    function expensiveOperation()
        public
        maxBaseFee(50 gwei)
    {
        // Base Fee가 50 gwei 이하일 때만 실행
        // 비싼 작업 수행...
    }

    /**
     * @notice Base Fee에 따라 다른 로직 실행
     */
    function adaptiveOperation() public {
        uint256 baseFee = block.basefee;

        if (baseFee < 20 gwei) {
            // 가스비 저렴: 복잡한 작업 수행
            complexLogic();
        } else if (baseFee < 50 gwei) {
            // 가스비 보통: 간단한 작업만
            simpleLogic();
        } else {
            // 가스비 비쌈: 최소한의 작업
            revert("Gas too expensive, try later");
        }
    }

    function complexLogic() private {
        // 많은 가스를 소비하는 로직
    }

    function simpleLogic() private {
        // 적은 가스를 소비하는 로직
    }
}
```

**사용 사례:**
```
✅ NFT 민팅: 가스비 높을 때 일시 중지
✅ 배치 작업: 가스비 낮을 때만 실행
✅ 토큰 스왑: 가격에 따라 슬리피지 조정
```

### 패턴 2: Gas Price 분석

```solidity
contract GasPriceAnalyzer {
    /**
     * @notice 현재 거래의 가스 정보 분석
     * @return gasPrice 실제 지불하는 가스 가격 (effectiveGasPrice)
     * @return baseFee 현재 블록의 Base Fee
     * @return priorityFee 채굴자에게 가는 팁
     */
    function analyzeGas() public view returns (
        uint256 gasPrice,
        uint256 baseFee,
        uint256 priorityFee
    ) {
        gasPrice = tx.gasprice;          // effectiveGasPrice
        baseFee = block.basefee;         // Base Fee
        priorityFee = gasPrice - baseFee; // Priority Fee

        return (gasPrice, baseFee, priorityFee);
    }

    /**
     * @notice 거래 타입 확인
     */
    function isEIP1559Transaction() public view returns (bool) {
        // Legacy 거래에서도 block.basefee는 사용 가능
        // 하지만 tx.gasprice가 사용자 설정 gasPrice와 같음
        return tx.gasprice >= block.basefee;
    }

    /**
     * @notice 가스 효율성 점수 계산
     * @dev Priority Fee 비율로 효율성 측정
     */
    function calculateEfficiency() public view returns (uint256) {
        uint256 baseFee = block.basefee;
        uint256 priorityFee = tx.gasprice - baseFee;

        // Priority Fee가 Base Fee의 10% 이하면 효율적
        return (priorityFee * 100) / baseFee;
    }

    /**
     * @notice 거래 비용 추정
     */
    function estimateCost(uint256 estimatedGas) public view returns (
        uint256 minCost,
        uint256 maxCost,
        uint256 likelyCost
    ) {
        uint256 baseFee = block.basefee;
        uint256 priorityFee = tx.gasprice - baseFee;

        // 최소: Base Fee만 (Priority Fee = 0)
        minCost = baseFee * estimatedGas;

        // 최대: Base Fee 2배 + Priority Fee (급격한 혼잡)
        maxCost = (baseFee * 2 + priorityFee) * estimatedGas;

        // 예상: Base Fee 1.2배 + Priority Fee (소폭 증가)
        likelyCost = (baseFee * 12 / 10 + priorityFee) * estimatedGas;

        return (minCost, maxCost, likelyCost);
    }
}
```

### 패턴 3: 조건부 실행

```solidity
contract ConditionalExecutor {
    // 가스비 임계값 저장
    mapping(bytes32 => uint256) public gasPriceThresholds;

    // 대기 중인 작업
    struct PendingTask {
        address caller;
        bytes data;
        uint256 maxBaseFee;
        uint256 createdAt;
    }

    mapping(bytes32 => PendingTask) public pendingTasks;

    event TaskScheduled(bytes32 indexed taskId, uint256 maxBaseFee);
    event TaskExecuted(bytes32 indexed taskId, uint256 actualBaseFee);
    event TaskCancelled(bytes32 indexed taskId);

    /**
     * @notice 가스비가 낮을 때 실행될 작업 예약
     */
    function scheduleTask(
        bytes32 taskId,
        bytes calldata taskData,
        uint256 maxBaseFee
    ) external {
        pendingTasks[taskId] = PendingTask({
            caller: msg.sender,
            data: taskData,
            maxBaseFee: maxBaseFee,
            createdAt: block.timestamp
        });

        emit TaskScheduled(taskId, maxBaseFee);
    }

    /**
     * @notice 가스비가 적절하면 작업 실행
     */
    function executeTask(bytes32 taskId) external {
        PendingTask memory task = pendingTasks[taskId];
        require(task.caller != address(0), "Task not found");
        require(block.basefee <= task.maxBaseFee, "Base fee too high");

        // 작업 실행
        (bool success, ) = address(this).call(task.data);
        require(success, "Task execution failed");

        // 정리
        delete pendingTasks[taskId];
        emit TaskExecuted(taskId, block.basefee);
    }

    /**
     * @notice 작업 취소
     */
    function cancelTask(bytes32 taskId) external {
        require(pendingTasks[taskId].caller == msg.sender, "Not authorized");
        delete pendingTasks[taskId];
        emit TaskCancelled(taskId);
    }

    /**
     * @notice 현재 실행 가능한 작업인지 확인
     */
    function canExecute(bytes32 taskId) external view returns (bool) {
        PendingTask memory task = pendingTasks[taskId];
        return task.caller != address(0) && block.basefee <= task.maxBaseFee;
    }
}
```

---

## ethers.js 통합

### 기본 사용법

```javascript
import { ethers } from "ethers";

// 1. Provider 설정
const provider = new ethers.JsonRpcProvider(
    "https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY"
);

// 2. Fee Data 조회 (가장 중요!)
const feeData = await provider.getFeeData();
console.log({
    // Legacy 거래용 (Type 0)
    gasPrice: ethers.formatUnits(feeData.gasPrice, "gwei"),

    // EIP-1559 거래용 (Type 2)
    maxFeePerGas: ethers.formatUnits(feeData.maxFeePerGas, "gwei"),
    maxPriorityFeePerGas: ethers.formatUnits(
        feeData.maxPriorityFeePerGas,
        "gwei"
    )
});

// 3. 현재 Base Fee 조회
const block = await provider.getBlock("latest");
const baseFee = block.baseFeePerGas;
console.log("Current Base Fee:", ethers.formatUnits(baseFee, "gwei"), "gwei");

// 4. 거래 전송 (EIP-1559)
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const tx = await wallet.sendTransaction({
    to: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    value: ethers.parseEther("0.1"),
    maxFeePerGas: feeData.maxFeePerGas,
    maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
    type: 2  // EIP-1559 거래
});

console.log("Transaction hash:", tx.hash);
const receipt = await tx.wait();
console.log("Confirmed in block:", receipt.blockNumber);
```

### 커스텀 Fee 전략

```javascript
/**
 * Fast: 빠른 포함 (15초 이내)
 * Standard: 보통 속도 (1분 이내)
 * Slow: 느린 포함 (3-5분)
 */
async function getCustomFees(provider, speed = "standard") {
    const feeData = await provider.getFeeData();
    const block = await provider.getBlock("latest");
    const baseFee = block.baseFeePerGas;

    const strategies = {
        fast: {
            maxFeePerGas: baseFee * 2n,  // Base Fee의 2배
            maxPriorityFeePerGas: ethers.parseUnits("3", "gwei"),
            expectedTime: "~15 seconds"
        },
        standard: {
            maxFeePerGas: baseFee * 15n / 10n,  // Base Fee의 1.5배
            maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
            expectedTime: "~1 minute"
        },
        slow: {
            maxFeePerGas: baseFee * 12n / 10n,  // Base Fee의 1.2배
            maxPriorityFeePerGas: ethers.parseUnits("1", "gwei"),
            expectedTime: "~3 minutes"
        }
    };

    return strategies[speed];
}

// 사용 예
const fees = await getCustomFees(provider, "fast");
const tx = await wallet.sendTransaction({
    to: recipient,
    value: amount,
    ...fees,
    type: 2
});
```

### Base Fee 예측

```javascript
/**
 * Base Fee 히스토리 기반 예측
 */
class BaseFeePredictor {
    constructor(provider) {
        this.provider = provider;
    }

    /**
     * 과거 N개 블록의 Base Fee 조회
     */
    async getBaseFeeHistory(blockCount = 10) {
        const latestBlock = await this.provider.getBlockNumber();
        const history = [];

        for (let i = 0; i < blockCount; i++) {
            const block = await this.provider.getBlock(latestBlock - i);
            history.push({
                blockNumber: block.number,
                baseFee: block.baseFeePerGas,
                gasUsed: block.gasUsed,
                gasLimit: block.gasLimit,
                utilization: Number(block.gasUsed * 100n / block.gasLimit)
            });
        }

        return history.reverse(); // 오래된 것부터
    }

    /**
     * N블록 후 Base Fee 예측
     */
    predictBaseFee(currentBaseFee, currentUtilization, blocksAhead = 1) {
        let baseFee = currentBaseFee;

        // 현재 이용률 기반 변화 예측
        for (let i = 0; i < blocksAhead; i++) {
            if (currentUtilization > 50) {
                // 타겟(50%) 초과: 증가
                const delta = baseFee * BigInt(
                    Math.floor((currentUtilization - 50) / 50 * 125)
                ) / 1000n;
                baseFee = baseFee + delta;
            } else if (currentUtilization < 50) {
                // 타겟 미만: 감소
                const delta = baseFee * BigInt(
                    Math.floor((50 - currentUtilization) / 50 * 125)
                ) / 1000n;
                baseFee = baseFee - delta;
            }
        }

        return baseFee;
    }

    /**
     * 최적의 maxFeePerGas 추천
     */
    async recommendMaxFee(blocksToWait = 3) {
        const history = await this.getBaseFeeHistory(5);
        const latest = history[history.length - 1];

        // 3블록 후 Base Fee 예측
        const predictedBaseFee = this.predictBaseFee(
            latest.baseFee,
            latest.utilization,
            blocksToWait
        );

        // 안전 마진 50% 추가
        const recommendedMaxFee = predictedBaseFee * 15n / 10n;

        return {
            currentBaseFee: latest.baseFee,
            predictedBaseFee: predictedBaseFee,
            recommendedMaxFee: recommendedMaxFee,
            currentUtilization: latest.utilization
        };
    }
}

// 사용 예
const predictor = new BaseFeePredictor(provider);
const recommendation = await predictor.recommendMaxFee(3);

console.log("Current Base Fee:",
    ethers.formatUnits(recommendation.currentBaseFee, "gwei"), "gwei");
console.log("Predicted (3 blocks):",
    ethers.formatUnits(recommendation.predictedBaseFee, "gwei"), "gwei");
console.log("Recommended Max Fee:",
    ethers.formatUnits(recommendation.recommendedMaxFee, "gwei"), "gwei");
```

### 가스비 모니터링 Hook (React)

```javascript
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

/**
 * 실시간 가스비 모니터링 React Hook
 */
function useGasPrice(updateInterval = 12000) {
    const [gasData, setGasData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        const provider = new ethers.JsonRpcProvider(
            process.env.REACT_APP_RPC_URL
        );

        async function updateGasData() {
            try {
                const [feeData, block] = await Promise.all([
                    provider.getFeeData(),
                    provider.getBlock('latest')
                ]);

                setGasData({
                    baseFee: block.baseFeePerGas,
                    maxFee: feeData.maxFeePerGas,
                    priorityFee: feeData.maxPriorityFeePerGas,
                    blockNumber: block.number,
                    gasUsed: block.gasUsed,
                    gasLimit: block.gasLimit,
                    utilization: Number(block.gasUsed * 100n / block.gasLimit),
                    timestamp: block.timestamp
                });

                setLoading(false);
            } catch (err) {
                setError(err.message);
                setLoading(false);
            }
        }

        updateGasData();
        const interval = setInterval(updateGasData, updateInterval);

        return () => clearInterval(interval);
    }, [updateInterval]);

    return { gasData, loading, error };
}

// 사용 예
function GasPriceDisplay() {
    const { gasData, loading, error } = useGasPrice();

    if (loading) return <div>Loading gas prices...</div>;
    if (error) return <div>Error: {error}</div>;

    return (
        <div>
            <h3>Current Gas Prices</h3>
            <p>Block: #{gasData.blockNumber}</p>
            <p>Base Fee: {ethers.formatUnits(gasData.baseFee, 'gwei')} gwei</p>
            <p>Max Fee: {ethers.formatUnits(gasData.maxFee, 'gwei')} gwei</p>
            <p>Priority Fee: {ethers.formatUnits(gasData.priorityFee, 'gwei')} gwei</p>
            <p>Network Utilization: {gasData.utilization.toFixed(1)}%</p>
        </div>
    );
}
```

---

## 실무 활용 예제

### 예제 1: NFT 민팅 (가스비 제한)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GasAwareNFT {
    uint256 public constant MAX_BASE_FEE = 50 gwei;
    uint256 public tokenIdCounter;
    mapping(uint256 => address) public owners;

    event Minted(uint256 indexed tokenId, address indexed owner, uint256 baseFee);

    /**
     * @notice 가스비가 적정할 때만 민팅 가능
     */
    function mint() external returns (uint256) {
        require(
            block.basefee <= MAX_BASE_FEE,
            "Gas too high, please try later"
        );

        uint256 tokenId = tokenIdCounter++;
        owners[tokenId] = msg.sender;

        emit Minted(tokenId, msg.sender, block.basefee);
        return tokenId;
    }

    /**
     * @notice 현재 민팅 가능 여부 확인
     */
    function canMint() external view returns (bool, uint256) {
        bool allowed = block.basefee <= MAX_BASE_FEE;
        return (allowed, block.basefee);
    }

    /**
     * @notice 예상 대기 시간 (블록 수)
     */
    function estimatedWaitTime() external view returns (uint256 blocks) {
        if (block.basefee <= MAX_BASE_FEE) {
            return 0;
        }

        // 간단한 추정: 12.5% 감소 가정
        uint256 currentFee = block.basefee;
        blocks = 0;

        while (currentFee > MAX_BASE_FEE && blocks < 100) {
            currentFee = currentFee * 875 / 1000;  // -12.5%
            blocks++;
        }

        return blocks;
    }
}
```

**프론트엔드 연동:**
```javascript
async function mintNFT() {
    const contract = new ethers.Contract(NFT_ADDRESS, ABI, signer);

    // 1. 민팅 가능 여부 확인
    const [canMint, currentBaseFee] = await contract.canMint();

    if (!canMint) {
        const waitBlocks = await contract.estimatedWaitTime();
        const waitMinutes = Math.ceil(waitBlocks * 12 / 60);
        alert(`Gas too high. Please wait ~${waitMinutes} minutes`);
        return;
    }

    // 2. 적절한 Fee 설정
    const feeData = await provider.getFeeData();

    // 3. 민팅 실행
    const tx = await contract.mint({
        maxFeePerGas: currentBaseFee * 2n,  // 여유있게 설정
        maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
        type: 2
    });

    console.log("Minting...", tx.hash);
    const receipt = await tx.wait();
    console.log("Minted! Token ID:", receipt.logs[0].topics[1]);
}
```

### 예제 2: DEX 거래 (가격 영향 최소화)

```solidity
contract GasAwareDEX {
    /**
     * @notice 가스비에 따라 슬리피지 자동 조정
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        // Base Fee에 따라 슬리피지 조정
        uint256 adjustedMinAmountOut = adjustSlippage(
            minAmountOut,
            block.basefee
        );

        // 스왑 로직...
        amountOut = _executeSwap(tokenIn, tokenOut, amountIn);

        require(
            amountOut >= adjustedMinAmountOut,
            "Insufficient output amount"
        );

        return amountOut;
    }

    /**
     * @notice 가스비 높을 때 슬리피지 완화
     * @dev 가스비 높음 = 네트워크 혼잡 = 가격 변동성 높음
     */
    function adjustSlippage(uint256 minAmount, uint256 baseFee)
        private
        pure
        returns (uint256)
    {
        if (baseFee < 20 gwei) {
            return minAmount;  // 슬리피지 유지
        } else if (baseFee < 50 gwei) {
            return minAmount * 98 / 100;  // 2% 완화
        } else {
            return minAmount * 95 / 100;  // 5% 완화
        }
    }

    function _executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private returns (uint256) {
        // 실제 스왑 로직
        return amountIn;  // 예시
    }
}
```

### 예제 3: 배치 처리 시스템

```javascript
/**
 * 가스비가 저렴할 때 자동으로 배치 작업 실행
 */
class BatchProcessor {
    constructor(provider, contract, maxBaseFee) {
        this.provider = provider;
        this.contract = contract;
        this.maxBaseFee = maxBaseFee;
        this.queue = [];
    }

    /**
     * 작업 추가
     */
    addTask(task) {
        this.queue.push(task);
        console.log(`Task added. Queue size: ${this.queue.length}`);
    }

    /**
     * 가스비 모니터링 시작
     */
    async startMonitoring() {
        console.log(`Monitoring gas prices. Target: ${this.maxBaseFee} gwei`);

        setInterval(async () => {
            if (this.queue.length === 0) return;

            const block = await this.provider.getBlock('latest');
            const baseFee = block.baseFeePerGas;
            const baseFeeGwei = Number(ethers.formatUnits(baseFee, 'gwei'));

            console.log(`Current base fee: ${baseFeeGwei.toFixed(2)} gwei`);

            if (baseFee <= ethers.parseUnits(this.maxBaseFee.toString(), 'gwei')) {
                await this.processBatch();
            }
        }, 12000);  // 12초마다 확인
    }

    /**
     * 배치 실행
     */
    async processBatch() {
        console.log(`Processing ${this.queue.length} tasks...`);

        const batch = this.queue.splice(0, 10);  // 최대 10개씩
        const feeData = await this.provider.getFeeData();

        for (const task of batch) {
            try {
                const tx = await this.contract[task.method](...task.params, {
                    maxFeePerGas: feeData.maxFeePerGas,
                    maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
                    type: 2
                });

                console.log(`Task executed: ${tx.hash}`);
                await tx.wait();
            } catch (error) {
                console.error(`Task failed:`, error);
                this.queue.push(task);  // 실패 시 재시도
            }
        }
    }
}

// 사용 예
const processor = new BatchProcessor(
    provider,
    contract,
    30  // 30 gwei 이하일 때만 실행
);

processor.addTask({
    method: 'transfer',
    params: [recipient1, amount1]
});
processor.addTask({
    method: 'transfer',
    params: [recipient2, amount2]
});

processor.startMonitoring();
```

---

## 가스 최적화 전략

### 1. 스토리지 최적화 (EIP-1559 이후 더 중요)

```solidity
contract StorageOptimized {
    // ❌ 나쁜 예: 여러 변수 분산
    uint256 public value1;  // Slot 0
    uint256 public value2;  // Slot 1
    uint256 public value3;  // Slot 2
    // 3번의 SSTORE: ~60,000 gas

    // ✅ 좋은 예: 구조체로 패킹
    struct Data {
        uint128 value1;
        uint128 value2;
        uint256 value3;
    }
    Data public data;  // Slot 0-1만 사용
    // 2번의 SSTORE: ~40,000 gas

    // ✅ 더 좋은 예: 비트 패킹
    uint256 private _packed;
    // value1: 0-127 bit
    // value2: 128-255 bit

    function setValues(uint128 v1, uint128 v2) external {
        _packed = uint256(v1) | (uint256(v2) << 128);
        // 1번의 SSTORE: ~20,000 gas
    }

    function getValue1() external view returns (uint128) {
        return uint128(_packed);
    }

    function getValue2() external view returns (uint128) {
        return uint128(_packed >> 128);
    }
}
```

### 2. 조건부 실행 패턴

```solidity
contract ConditionalExecution {
    uint256 public constant LOW_GAS_THRESHOLD = 30 gwei;
    uint256 public constant HIGH_GAS_THRESHOLD = 100 gwei;

    /**
     * @notice 가스비에 따라 실행 전략 변경
     */
    function adaptiveProcess(uint256[] calldata data) external {
        uint256 baseFee = block.basefee;

        if (baseFee < LOW_GAS_THRESHOLD) {
            // 가스비 저렴: 풀 프로세싱
            fullProcess(data);
        } else if (baseFee < HIGH_GAS_THRESHOLD) {
            // 가스비 보통: 부분 프로세싱
            partialProcess(data);
        } else {
            // 가스비 비쌈: 최소 프로세싱
            revert("Gas too high");
        }
    }

    function fullProcess(uint256[] calldata data) private {
        // 모든 데이터 처리
        for (uint256 i = 0; i < data.length; i++) {
            // 복잡한 로직...
        }
    }

    function partialProcess(uint256[] calldata data) private {
        // 중요한 것만 처리
        uint256 limit = data.length / 2;
        for (uint256 i = 0; i < limit; i++) {
            // 간단한 로직...
        }
    }
}
```

### 3. 배치 처리 최적화

```solidity
contract BatchOptimized {
    /**
     * @notice 동적 배치 크기 조정
     */
    function dynamicBatch(address[] calldata recipients, uint256[] calldata amounts)
        external
    {
        uint256 baseFee = block.basefee;
        uint256 batchSize;

        // 가스비에 따라 배치 크기 조정
        if (baseFee < 20 gwei) {
            batchSize = 100;  // 많이 처리
        } else if (baseFee < 50 gwei) {
            batchSize = 50;   // 적당히
        } else {
            batchSize = 10;   // 최소한만
        }

        uint256 count = recipients.length < batchSize ? recipients.length : batchSize;

        for (uint256 i = 0; i < count; i++) {
            // 전송 로직...
        }
    }
}
```

### 4. Calldata vs Memory 최적화

```solidity
contract DataLocationOptimized {
    // ✅ 좋은 예: calldata 사용 (읽기만 할 경우)
    function processData(uint256[] calldata data) external pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < data.length; i++) {
            sum += data[i];
        }
        return sum;
        // calldata: ~3 gas per word
    }

    // ❌ 나쁜 예: memory 사용 (불필요한 복사)
    function processDataBad(uint256[] memory data) external pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < data.length; i++) {
            sum += data[i];
        }
        return sum;
        // memory: ~3 gas per word + copy cost
    }
}
```

---

## 주의사항

### ⚠️ Legacy 거래와의 호환성

```javascript
// EIP-1559 이후에도 Legacy 거래 가능
const legacyTx = {
    to: recipient,
    value: amount,
    gasPrice: ethers.parseUnits("50", "gwei"),  // Legacy 방식
    gasLimit: 21000,
    type: 0  // Legacy
};

// 하지만 권장하지 않음:
// 1. 과다 지불 위험
// 2. 환불 없음
// 3. Base Fee 소각 혜택 없음
```

### 🔒 MaxFeePerGas 설정 주의

```javascript
// ❌ 위험: 너무 낮게 설정
{
    maxFeePerGas: baseFee + 1,  // 위험!
    // Base Fee가 조금만 올라도 거래 실패
}

// ✅ 안전: 충분한 여유
{
    maxFeePerGas: baseFee * 2,  // 안전
    // Base Fee가 2배 올라도 OK
}

// ✅ 더 안전: 예측 기반
{
    maxFeePerGas: predictedBaseFee * 1.5,
    // 예측값에 50% 마진
}
```

### ❌ 흔한 실수들

#### 실수 1: Base Fee를 Priority Fee로 착각

```javascript
// ❌ 틀림
{
    maxFeePerGas: ethers.parseUnits("2", "gwei"),        // 너무 낮음!
    maxPriorityFeePerGas: ethers.parseUnits("100", "gwei")  // 너무 높음!
}

// ✅ 올바름
{
    maxFeePerGas: ethers.parseUnits("100", "gwei"),      // Base Fee 여유
    maxPriorityFeePerGas: ethers.parseUnits("2", "gwei")   // 적절한 팁
}
```

#### 실수 2: Gas Limit 과소 설정

```javascript
// ❌ 위험
const tx = await contract.complexFunction({
    gasLimit: 50000,  // 추측
    // 실제 필요: 80000 → 거래 실패!
});

// ✅ 안전
const estimatedGas = await contract.complexFunction.estimateGas();
const tx = await contract.complexFunction({
    gasLimit: estimatedGas * 12n / 10n,  // 20% 여유
});
```

#### 실수 3: Solidity 버전 확인 안함

```solidity
// ❌ 컴파일 에러 (Solidity < 0.8.7)
pragma solidity ^0.8.0;
contract Test {
    function getBaseFee() public view returns (uint256) {
        return block.basefee;  // Error: Unknown identifier
    }
}

// ✅ 올바름
pragma solidity ^0.8.7;  // 0.8.7 이상 필요
contract Test {
    function getBaseFee() public view returns (uint256) {
        return block.basefee;  // OK
    }
}
```

---

## 실전 체크리스트

EIP-1559 거래를 보낼 때 확인하세요:

### 스마트 컨트랙트 개발
- [ ] Solidity 0.8.7 이상 사용 (`block.basefee` 지원)
- [ ] Base Fee 체크 로직 구현 (필요 시)
- [ ] 가스 최적화 적용 (스토리지 패킹, calldata 등)
- [ ] 조건부 실행 패턴 고려
- [ ] 테스트넷에서 충분히 테스트

### 프론트엔드 개발
- [ ] `getFeeData()` 사용하여 Fee 조회
- [ ] `maxFeePerGas` 적절히 설정 (baseFee × 1.5~2)
- [ ] `maxPriorityFeePerGas` 설정 (1-3 gwei)
- [ ] `type: 2` 명시
- [ ] Gas Limit 추정 후 20% 여유
- [ ] 거래 실패 시 재시도 로직
- [ ] 사용자에게 예상 비용 표시

### 운영
- [ ] 가스비 모니터링 시스템 구축
- [ ] 높은 가스비 알림 설정
- [ ] 배치 작업 스케줄링
- [ ] Base Fee 트렌드 분석
- [ ] 비용 최적화 지표 추적

---

## 자주 묻는 질문 (FAQ)

### Q1: EIP-1559 이후 가스비가 싸졌나요?

**A:** 아니요, EIP-1559는 가스비를 낮추는 것이 목적이 아닙니다.

```
목적:
✅ 예측 가능성 향상
✅ 사용자 경험 개선
✅ 수수료 투명성
✅ ETH 디플레이션

목적이 아닌 것:
❌ 가스비 절감
❌ 네트워크 확장
```

실제로는 **Base Fee 소각**으로 인해 ETH가 디플레이션 자산이 되어 장기적으로 ETH 가치 상승에 기여할 수 있습니다.

### Q2: 왜 maxFeePerGas를 baseFee보다 높게 설정해야 하나요?

**A:** Base Fee는 매 블록마다 변하기 때문입니다.

```
블록 N:   baseFee = 30 gwei
블록 N+1: baseFee = 33.75 gwei (12.5% 증가)
블록 N+2: baseFee = 38 gwei

maxFeePerGas = 32 gwei로 설정했다면?
→ 블록 N+1부터 거래 포함 불가!
```

**권장:** `maxFeePerGas = currentBaseFee × 2`

### Q3: Priority Fee는 얼마로 설정해야 하나요?

**A:** 일반적으로 **1-3 gwei**면 충분합니다.

```
속도별 권장:
Slow:     0.5-1 gwei
Standard: 1-2 gwei
Fast:     2-3 gwei
Urgent:   3-5 gwei

주의: Priority Fee는 Base Fee만큼 중요하지 않음
     Base Fee가 포함의 최소 조건
```

### Q4: Legacy 거래(Type 0)를 계속 사용해도 되나요?

**A:** 가능하지만 권장하지 않습니다.

```
Legacy 거래의 문제:
1. 과다 지불 위험 (환불 없음)
2. 예측 불가능
3. Base Fee 소각 혜택 없음
4. 미래 호환성 불확실

EIP-1559 거래의 장점:
1. 자동 환불
2. 예측 가능
3. ETH 디플레이션 기여
4. 표준 방식
```

### Q5: Base Fee 소각이 정확히 뭔가요?

**A:** Base Fee로 지불한 ETH가 영구적으로 제거됩니다.

```
Before EIP-1559:
  수수료 → 채굴자 → 순환

After EIP-1559:
  Base Fee → 🔥 소각 (영구 제거)
  Priority Fee → 채굴자

결과:
  ETH 총 공급량 감소 = 디플레이션

실제 데이터 (2023년):
  일일 소각: ~2000-3000 ETH
  연간 소각률: ~0.5-1%
```

### Q6: 컨트랙트에서 사용자가 지불한 가스비를 알 수 있나요?

**A:** 직접적으로는 불가능하지만 추정할 수 있습니다.

```solidity
contract GasTracker {
    // ❌ 직접 조회 불가
    // uint256 actualPaid = msg.value;  // 이건 전송된 ETH

    // ✅ 추정 가능
    function estimateGasCost() public view returns (uint256) {
        uint256 gasPrice = tx.gasprice;  // effectiveGasPrice
        uint256 estimatedGas = 50000;
        return gasPrice * estimatedGas;
    }

    // ✅ 실제 사용량은 receipt에서 확인 (off-chain)
}
```

**프론트엔드에서:**
```javascript
const receipt = await tx.wait();
const gasUsed = receipt.gasUsed;
const effectiveGasPrice = receipt.gasPrice;
const totalCost = gasUsed * effectiveGasPrice;
console.log("Total cost:", ethers.formatEther(totalCost), "ETH");
```

### Q7: Base Fee는 무한정 올라갈 수 있나요?

**A:** 이론적으로는 가능하지만 실제로는 자동 조절됩니다.

```
블록당 최대 변화: 12.5%

Base Fee 급등 시나리오:
100 gwei → 112.5 → 126.6 → 142.4 → 160.2 → 180.2

하지만:
  가격 상승 → 수요 감소 → 블록 여유 생김 → 가격 하락

자동 균형:
  공급(블록 크기)과 수요(거래)가 균형을 이룸
```

---

## 디버깅 팁

### Base Fee 확인

```javascript
// 현재 Base Fee 조회
const block = await provider.getBlock('latest');
console.log("Base Fee:", ethers.formatUnits(block.baseFeePerGas, 'gwei'), "gwei");

// 과거 블록의 Base Fee
const oldBlock = await provider.getBlock(blockNumber);
console.log("Block", blockNumber, "Base Fee:",
    ethers.formatUnits(oldBlock.baseFeePerGas, 'gwei'), "gwei");
```

### 거래가 pending 상태일 때

```javascript
async function checkPendingTransaction(txHash) {
    const tx = await provider.getTransaction(txHash);
    const block = await provider.getBlock('latest');

    console.log("Transaction maxFeePerGas:",
        ethers.formatUnits(tx.maxFeePerGas, 'gwei'), "gwei");
    console.log("Current baseFee:",
        ethers.formatUnits(block.baseFeePerGas, 'gwei'), "gwei");

    if (tx.maxFeePerGas < block.baseFeePerGas) {
        console.log("❌ maxFeePerGas too low! Transaction will not be included.");
        console.log("Suggested: Increase maxFeePerGas or wait for baseFee to drop");
    } else {
        console.log("✅ maxFeePerGas is sufficient");
    }
}
```

### 거래 비용 분석

```javascript
async function analyzeTransactionCost(txHash) {
    const receipt = await provider.getTransactionReceipt(txHash);
    const tx = await provider.getTransaction(txHash);
    const block = await provider.getBlock(receipt.blockNumber);

    const gasUsed = receipt.gasUsed;
    const effectiveGasPrice = receipt.gasPrice || receipt.effectiveGasPrice;
    const baseFee = block.baseFeePerGas;
    const priorityFee = effectiveGasPrice - baseFee;

    const totalCost = gasUsed * effectiveGasPrice;
    const baseFeeAmount = gasUsed * baseFee;
    const priorityFeeAmount = gasUsed * priorityFee;
    const refund = gasUsed * (tx.maxFeePerGas - effectiveGasPrice);

    console.log({
        gasUsed: gasUsed.toString(),
        effectiveGasPrice: ethers.formatUnits(effectiveGasPrice, 'gwei') + ' gwei',
        baseFee: ethers.formatUnits(baseFee, 'gwei') + ' gwei',
        priorityFee: ethers.formatUnits(priorityFee, 'gwei') + ' gwei',
        totalCost: ethers.formatEther(totalCost) + ' ETH',
        burned: ethers.formatEther(baseFeeAmount) + ' ETH',
        toMiner: ethers.formatEther(priorityFeeAmount) + ' ETH',
        refunded: ethers.formatEther(refund) + ' ETH'
    });
}
```

---

## 학습 로드맵

```
초급 (1시간) → 중급 (2시간) → 고급 (3시간) → 실전 (프로젝트 적용)
```

### 🟢 초급: 개념 이해 (1시간)
1. [왜 필요한가?](#왜-필요한가) 읽기 (15분)
2. [동작 원리 다이어그램](#동작-원리-한눈에-보기) 보기 (15분)
3. [핵심 개념](#핵심-개념) 학습 (20분)
4. [Before vs After 비교](#before-vs-after-비교) 이해 (10분)

**체크포인트:** Base Fee, Priority Fee, Max Fee의 차이를 설명할 수 있는가?

### 🟡 중급: 실습 (2시간)
1. [Base Fee 알고리즘](#base-fee-알고리즘) 이해 (30분)
2. [ethers.js로 EIP-1559 거래 전송](./contracts/RealWorldExamples.sol) (30분)
3. [BaseFeeMonitor.sol](./contracts/BaseFeeMonitor.sol) 배포 및 테스트 (30분)
4. Fee 예측 로직 구현 (30분)

**체크포인트:** ethers.js로 Type 2 거래를 성공적으로 전송할 수 있는가?

### 🔴 고급: 최적화 (3시간)
1. [가스 최적화 전략](#가스-최적화-전략) 학습 (1시간)
2. [ConditionalExecutor.sol](./contracts/ConditionalExecutor.sol) 분석 (1시간)
3. [실무 활용 예제](#실무-활용-예제) 구현 (1시간)

**체크포인트:** 가스비에 따라 동적으로 로직을 조정하는 컨트랙트를 작성할 수 있는가?

### 🚀 실전: 프로젝트 적용
- [ ] 기존 프로젝트에 EIP-1559 적용
- [ ] 가스비 모니터링 대시보드 구축
- [ ] 배치 처리 시스템 최적화
- [ ] 비용 절감 효과 측정
- [ ] 사용자 경험 개선 확인

---

## 관련 자료

### 공식 문서
- [EIP-1559 명세](https://eips.ethereum.org/EIPS/eip-1559)
- [Ethereum.org - Gas and Fees](https://ethereum.org/en/developers/docs/gas/)
- [ethers.js Documentation](https://docs.ethers.org/)

### 실시간 데이터
- [Etherscan Gas Tracker](https://etherscan.io/gastracker)
- [ETH Burn Dashboard](https://ultrasound.money/)
- [Blocknative Gas Estimator](https://www.blocknative.com/gas-estimator)

### 관련 EIP
- **EIP-2930**: Optional Access Lists (Type 1 거래)
- **EIP-3529**: Reduction in Gas Refunds (SSTORE 환불 제거)
- **EIP-4844**: Proto-Danksharding (Blob 거래, Type 3)

---

## 코드 예제

### 스마트 컨트랙트
- [GasOptimizedContract.sol](./contracts/GasOptimizedContract.sol) - 가스 최적화 베스트 프랙티스
- [BaseFeeMonitor.sol](./contracts/BaseFeeMonitor.sol) - Base Fee 모니터링 및 분석
- [ConditionalExecutor.sol](./contracts/ConditionalExecutor.sol) - 조건부 실행 패턴
- [RealWorldExamples.sol](./contracts/RealWorldExamples.sol) - NFT, DEX, 배치 처리 등 실전 예제

---

## 마무리

EIP-1559는 이더리움의 **가장 중요한 업그레이드** 중 하나입니다:

### 핵심 요약
1. **Base Fee**: 자동 조정되는 기본 수수료 (소각됨)
2. **Priority Fee**: 채굴자에게 주는 팁
3. **Max Fee**: 최대 지불 의사 (초과분 환불)
4. **예측 가능성**: 더 이상 가스비 추측 게임 필요 없음

### 개발자가 얻는 것
- 더 나은 사용자 경험
- 예측 가능한 비용
- 가스 최적화 기회
- ETH 디플레이션 혜택

### 다음 단계
1. [치트시트](./CHEATSHEET.md)로 빠른 참조
2. [실습 예제](./contracts/)로 직접 코딩
3. 프로젝트에 바로 적용

---

**Happy Coding!** 🚀

문의사항이나 개선 제안은 이슈로 남겨주세요.
