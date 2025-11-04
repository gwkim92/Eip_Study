# EIP-1559 치트시트 (Cheat Sheet)

> 빠른 참고용 요약본 - EIP-1559 Fee Market Change

## 핵심 코드 스니펫

### EIP-1559 거래 전송 (ethers.js)

```javascript
// 기본 EIP-1559 거래
const tx = await wallet.sendTransaction({
    to: recipient,
    value: ethers.parseEther("1.0"),
    maxFeePerGas: ethers.parseUnits("100", "gwei"),
    maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
    type: 2  // EIP-1559
});
```

### Fee Data 조회

```javascript
// Provider에서 현재 가스 정보 가져오기
const feeData = await provider.getFeeData();
const block = await provider.getBlock("latest");

console.log({
    baseFee: ethers.formatUnits(block.baseFeePerGas, "gwei"),
    maxFee: ethers.formatUnits(feeData.maxFeePerGas, "gwei"),
    priorityFee: ethers.formatUnits(feeData.maxPriorityFeePerGas, "gwei")
});
```

### Base Fee 확인 (Solidity)

```solidity
// Solidity 0.8.7 이상 필요
function getCurrentBaseFee() public view returns (uint256) {
    return block.basefee;  // BASEFEE opcode (0x48)
}
```

### Base Fee 제한

```solidity
modifier maxBaseFee(uint256 maxFee) {
    require(block.basefee <= maxFee, "Base fee too high");
    _;
}

function expensiveOperation() public maxBaseFee(50 gwei) {
    // Base Fee가 50 gwei 이하일 때만 실행
}
```

---

## 주요 개념 정리

### Fee 구조

```
총 가스비 = Base Fee + Priority Fee

Base Fee:
  - 프로토콜이 자동 계산
  - 소각됨 (Burn 🔥)
  - 매 블록마다 최대 12.5% 변동

Priority Fee:
  - 사용자가 설정
  - 채굴자에게 지급
  - 일반적으로 1-3 gwei

Max Fee Per Gas:
  - 최대 지불 의사
  - 초과분은 환불
  - 권장: baseFee × 2
```

### Fee 계산 공식

```solidity
// Effective Gas Price 계산
effectiveGasPrice = baseFee + min(
    maxPriorityFeePerGas,
    maxFeePerGas - baseFee
);

// 총 비용
totalCost = effectiveGasPrice × gasUsed;

// 환불액
refund = (maxFeePerGas - effectiveGasPrice) × gasUsed;
```

### Base Fee 조정 알고리즘

```solidity
// 다음 블록의 Base Fee 계산
if (parentGasUsed > target) {
    // 혼잡: 증가 (최대 12.5%)
    baseFee += baseFee × (parentGasUsed - target) / target / 8;
} else if (parentGasUsed < target) {
    // 여유: 감소 (최대 12.5%)
    baseFee -= baseFee × (target - parentGasUsed) / target / 8;
}
// else: 유지
```

---

## 속도별 Fee 전략

| 속도 | Priority Fee | Max Fee | 예상 시간 |
|------|--------------|---------|-----------|
| 🐢 Slow | 0.5-1 gwei | baseFee × 1.2 | ~3-5분 |
| 🚶 Standard | 1-2 gwei | baseFee × 1.5 | ~1분 |
| 🏃 Fast | 2-3 gwei | baseFee × 2 | ~15초 |
| 🚀 Urgent | 3-5 gwei | baseFee × 2.5 | ~5초 |

### 구현 예제

```javascript
async function getCustomFees(provider, speed = "standard") {
    const block = await provider.getBlock("latest");
    const baseFee = block.baseFeePerGas;

    const strategies = {
        slow: {
            maxFeePerGas: baseFee * 12n / 10n,
            maxPriorityFeePerGas: ethers.parseUnits("1", "gwei")
        },
        standard: {
            maxFeePerGas: baseFee * 15n / 10n,
            maxPriorityFeePerGas: ethers.parseUnits("2", "gwei")
        },
        fast: {
            maxFeePerGas: baseFee * 2n,
            maxPriorityFeePerGas: ethers.parseUnits("3", "gwei")
        }
    };

    return strategies[speed];
}
```

---

## Base Fee 시뮬레이션 표

### 혼잡 시나리오 (블록 100% 사용)

| 블록 | Base Fee | 변화율 |
|------|----------|--------|
| 0 | 100 gwei | - |
| 1 | 112.5 gwei | +12.5% |
| 2 | 126.6 gwei | +12.5% |
| 3 | 142.4 gwei | +12.5% |
| 4 | 160.2 gwei | +12.5% |
| 8 | ~200 gwei | 약 2배 |

### 여유 시나리오 (블록 0% 사용)

| 블록 | Base Fee | 변화율 |
|------|----------|--------|
| 0 | 100 gwei | - |
| 1 | 87.5 gwei | -12.5% |
| 2 | 76.6 gwei | -12.5% |
| 3 | 67.0 gwei | -12.5% |
| 4 | 58.6 gwei | -12.5% |
| 8 | ~50 gwei | 약 절반 |

---

## 자주 하는 실수와 해결

### ❌ 실수 1: Fee 매개변수 순서 헷갈림

```javascript
// 틀림
{
    maxFeePerGas: ethers.parseUnits("2", "gwei"),         // ❌ 너무 낮음
    maxPriorityFeePerGas: ethers.parseUnits("100", "gwei") // ❌ 너무 높음
}

// 올바름
{
    maxFeePerGas: ethers.parseUnits("100", "gwei"),       // ✅
    maxPriorityFeePerGas: ethers.parseUnits("2", "gwei")  // ✅
}
```

### ❌ 실수 2: MaxFee를 너무 낮게 설정

```javascript
// 위험
const baseFee = block.baseFeePerGas;
const tx = {
    maxFeePerGas: baseFee + ethers.parseUnits("1", "gwei"), // ❌ 위험!
    // Base Fee가 조금만 올라도 거래 포함 안됨
}

// 안전
const tx = {
    maxFeePerGas: baseFee * 2n, // ✅ 충분한 여유
}
```

### ❌ 실수 3: type 명시 안함

```javascript
// Legacy 거래로 전송됨
const tx = await wallet.sendTransaction({
    to: recipient,
    value: amount,
    maxFeePerGas: ...,
    maxPriorityFeePerGas: ...,
    // type: 2 누락! ❌
});

// 올바름
const tx = await wallet.sendTransaction({
    to: recipient,
    value: amount,
    maxFeePerGas: ...,
    maxPriorityFeePerGas: ...,
    type: 2  // ✅ EIP-1559
});
```

### ❌ 실수 4: Solidity 버전 미확인

```solidity
// 컴파일 에러
pragma solidity ^0.8.0;  // ❌ block.basefee 지원 안함

contract Test {
    function getBaseFee() public view returns (uint256) {
        return block.basefee;  // Error!
    }
}

// 올바름
pragma solidity ^0.8.7;  // ✅ 0.8.7 이상 필요

contract Test {
    function getBaseFee() public view returns (uint256) {
        return block.basefee;  // OK
    }
}
```

### ❌ 실수 5: Gas Limit 추정 안함

```javascript
// 위험: 임의로 설정
const tx = await contract.someFunction({
    gasLimit: 100000,  // ❌ 추측
});

// 안전: 추정 후 여유 추가
const estimated = await contract.someFunction.estimateGas();
const tx = await contract.someFunction({
    gasLimit: estimated * 12n / 10n,  // ✅ 20% 여유
});
```

---

## 빠른 디버깅

### Pending 거래 확인

```javascript
async function checkPending(txHash) {
    const tx = await provider.getTransaction(txHash);
    const block = await provider.getBlock("latest");

    const maxFee = ethers.formatUnits(tx.maxFeePerGas, "gwei");
    const baseFee = ethers.formatUnits(block.baseFeePerGas, "gwei");

    console.log(`Max Fee: ${maxFee} gwei`);
    console.log(`Base Fee: ${baseFee} gwei`);

    if (tx.maxFeePerGas < block.baseFeePerGas) {
        console.log("❌ Max Fee too low! Increase it.");
    } else {
        console.log("✅ Fee is acceptable");
    }
}
```

### 거래 비용 분석

```javascript
async function analyzeCost(txHash) {
    const receipt = await provider.getTransactionReceipt(txHash);
    const tx = await provider.getTransaction(txHash);
    const block = await provider.getBlock(receipt.blockNumber);

    const gasUsed = receipt.gasUsed;
    const effectivePrice = receipt.gasPrice;
    const baseFee = block.baseFeePerGas;
    const priorityFee = effectivePrice - baseFee;

    console.log({
        gasUsed: gasUsed.toString(),
        effectivePrice: ethers.formatUnits(effectivePrice, "gwei") + " gwei",
        baseFee: ethers.formatUnits(baseFee, "gwei") + " gwei",
        priorityFee: ethers.formatUnits(priorityFee, "gwei") + " gwei",
        totalCost: ethers.formatEther(gasUsed * effectivePrice) + " ETH",
        burned: ethers.formatEther(gasUsed * baseFee) + " ETH",
        toMiner: ethers.formatEther(gasUsed * priorityFee) + " ETH",
        refund: ethers.formatEther(gasUsed * (tx.maxFeePerGas - effectivePrice)) + " ETH"
    });
}
```

---

## 실전 코드 템플릿

### NFT 민팅 (가스비 제한)

```solidity
contract GasAwareNFT {
    uint256 constant MAX_BASE_FEE = 50 gwei;

    function mint() external returns (uint256) {
        require(block.basefee <= MAX_BASE_FEE, "Gas too high");
        // 민팅 로직...
    }

    function canMint() external view returns (bool, uint256) {
        return (block.basefee <= MAX_BASE_FEE, block.basefee);
    }
}
```

### 조건부 실행

```solidity
contract ConditionalExecutor {
    function adaptiveOperation() public {
        uint256 baseFee = block.basefee;

        if (baseFee < 20 gwei) {
            // 저렴: 복잡한 작업
            complexLogic();
        } else if (baseFee < 50 gwei) {
            // 보통: 간단한 작업
            simpleLogic();
        } else {
            // 비쌈: 거부
            revert("Gas too expensive");
        }
    }
}
```

### React 가스비 모니터

```javascript
function useGasPrice(interval = 12000) {
    const [gasData, setGasData] = useState(null);

    useEffect(() => {
        const provider = new ethers.JsonRpcProvider(RPC_URL);

        async function update() {
            const [feeData, block] = await Promise.all([
                provider.getFeeData(),
                provider.getBlock("latest")
            ]);

            setGasData({
                baseFee: block.baseFeePerGas,
                maxFee: feeData.maxFeePerGas,
                priorityFee: feeData.maxPriorityFeePerGas,
                utilization: Number(block.gasUsed * 100n / block.gasLimit)
            });
        }

        update();
        const timer = setInterval(update, interval);
        return () => clearInterval(timer);
    }, [interval]);

    return gasData;
}
```

### 배치 처리 (가스비 대기)

```javascript
class BatchProcessor {
    async waitForLowGas(maxBaseFee) {
        while (true) {
            const block = await provider.getBlock("latest");
            if (block.baseFeePerGas <= ethers.parseUnits(maxBaseFee.toString(), "gwei")) {
                return true;
            }
            await new Promise(resolve => setTimeout(resolve, 12000));
        }
    }

    async processBatch(tasks) {
        await this.waitForLowGas(30); // 30 gwei 이하 대기

        const feeData = await provider.getFeeData();
        for (const task of tasks) {
            await contract[task.method](...task.params, {
                maxFeePerGas: feeData.maxFeePerGas,
                maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
                type: 2
            });
        }
    }
}
```

---

## 가스 최적화 팁

### 1. Storage Packing

```solidity
// ❌ 비효율: 3 slots
uint256 value1;  // Slot 0
uint256 value2;  // Slot 1
uint256 value3;  // Slot 2

// ✅ 효율: 2 slots
struct Data {
    uint128 value1;
    uint128 value2;  // Slot 0
    uint256 value3;  // Slot 1
}
```

### 2. Calldata vs Memory

```solidity
// ✅ 좋음: calldata (읽기만 할 경우)
function process(uint256[] calldata data) external {
    // 가스 절약
}

// ❌ 나쁨: memory (불필요한 복사)
function process(uint256[] memory data) external {
    // 가스 낭비
}
```

### 3. Base Fee 기반 동적 처리

```solidity
function dynamicBatch(address[] calldata recipients) external {
    uint256 batchSize;

    if (block.basefee < 20 gwei) {
        batchSize = 100;  // 많이 처리
    } else if (block.basefee < 50 gwei) {
        batchSize = 50;   // 보통
    } else {
        batchSize = 10;   // 최소한
    }

    for (uint256 i = 0; i < batchSize && i < recipients.length; i++) {
        // 처리...
    }
}
```

---

## 체크리스트

### 스마트 컨트랙트 개발

- [ ] Solidity 0.8.7 이상 사용
- [ ] `block.basefee` 활용 (필요시)
- [ ] 가스 최적화 패턴 적용
- [ ] Base Fee 제한 로직 (필요시)
- [ ] 테스트넷 충분히 테스트

### 프론트엔드 개발

- [ ] `provider.getFeeData()` 사용
- [ ] `maxFeePerGas` 적절히 설정 (baseFee × 1.5~2)
- [ ] `maxPriorityFeePerGas` 설정 (1-3 gwei)
- [ ] `type: 2` 명시
- [ ] Gas Limit 추정 + 20% 여유
- [ ] 거래 실패 시 재시도 로직
- [ ] 사용자에게 예상 비용 표시

### 운영

- [ ] 가스비 모니터링 설정
- [ ] 높은 가스비 알림
- [ ] 배치 작업 최적화
- [ ] Base Fee 트렌드 분석
- [ ] 비용 절감 효과 측정

---

## Quick Reference: Type 0 vs Type 2

| 항목 | Legacy (Type 0) | EIP-1559 (Type 2) |
|------|----------------|-------------------|
| 가스 가격 | `gasPrice` | `maxFeePerGas`, `maxPriorityFeePerGas` |
| 예측성 | ❌ 낮음 | ✅ 높음 |
| 환불 | ❌ 없음 | ✅ 자동 환불 |
| Base Fee 소각 | ❌ 없음 | ✅ 소각 |
| 사용 권장 | ❌ 비권장 | ✅ 권장 |

```javascript
// Legacy (Type 0)
{
    gasPrice: ethers.parseUnits("100", "gwei"),
    type: 0
}

// EIP-1559 (Type 2)
{
    maxFeePerGas: ethers.parseUnits("100", "gwei"),
    maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
    type: 2
}
```

---

## 핵심 공식 요약

```javascript
// Effective Gas Price
effectiveGasPrice = baseFee + min(maxPriorityFee, maxFee - baseFee)

// 총 비용
totalCost = effectiveGasPrice × gasUsed

// 환불
refund = (maxFee - effectiveGasPrice) × gasUsed

// Base Fee 소각
burned = baseFee × gasUsed

// 채굴자 수입
minerTip = (effectiveGasPrice - baseFee) × gasUsed

// 다음 Base Fee (블록 100% 사용 시)
nextBaseFee = currentBaseFee × 1.125  // +12.5%

// 다음 Base Fee (블록 0% 사용 시)
nextBaseFee = currentBaseFee × 0.875  // -12.5%
```

---

## FAQ 빠른 답변

**Q: EIP-1559로 가스비가 싸졌나요?**
A: ❌ 아니요. 예측 가능성과 UX 개선이 목적입니다.

**Q: Priority Fee는 얼마가 적당한가요?**
A: 1-3 gwei 정도면 충분합니다.

**Q: Legacy 거래도 가능한가요?**
A: ✅ 가능하지만 권장하지 않습니다.

**Q: Base Fee는 무한정 올라갈 수 있나요?**
A: 이론적으로는 가능하지만 자동 조절됩니다 (수요↑ → 가격↑ → 수요↓).

**Q: maxFeePerGas는 어떻게 설정하나요?**
A: `currentBaseFee × 2` 정도가 안전합니다.

---

## 유용한 링크

- [README.md](./README.md) - 전체 가이드
- [EIP-1559 명세](https://eips.ethereum.org/EIPS/eip-1559)
- [Etherscan Gas Tracker](https://etherscan.io/gastracker)
- [ETH Burn](https://ultrasound.money/)
- [ethers.js Docs](https://docs.ethers.org/)

---

## 한 줄 요약

**EIP-1559는 거래 수수료를 예측 가능하고 공정하게 만들어주는 가스비 메커니즘입니다.**

Base Fee (소각) + Priority Fee (팁) = 예측 가능한 가스비 ✨
