# EIP-4626 Cheat Sheet

> **빠른 참조 가이드** - EIP-4626 Tokenized Vault Standard

## 📋 기본 정보

```solidity
// 표준 이름: EIP-4626 Tokenized Vault Standard
// 목적: 수익 창출 볼트(Yield-bearing Vaults)의 표준 API
// 상태: Final
// 제안일: 2021년 12월
```

## 🎯 핵심 개념 (5초 요약)

```
┌─────────────────────────────────────────┐
│  Assets (자산) → Vault → Shares (공유)   │
├─────────────────────────────────────────┤
│  USDC 예치 → 1000 vToken 받음            │
│  시간 경과 → 수익 발생 → sharePrice 상승  │
│  vToken 상환 → 1100 USDC 받음 (수익!)    │
└─────────────────────────────────────────┘
```

## 📝 필수 함수 (20개)

### 1. 메타데이터 (1개)

```solidity
function asset() external view returns (address);
```

### 2. 예치/인출 (4개)

```solidity
// 자산 기준
function deposit(uint256 assets, address receiver)
    external returns (uint256 shares);

function withdraw(uint256 assets, address receiver, address owner)
    external returns (uint256 shares);

// 공유 기준
function mint(uint256 shares, address receiver)
    external returns (uint256 assets);

function redeem(uint256 shares, address receiver, address owner)
    external returns (uint256 assets);
```

### 3. 회계 로직 (7개)

```solidity
// 기본
function totalAssets() external view returns (uint256);
function convertToShares(uint256 assets) external view returns (uint256);
function convertToAssets(uint256 shares) external view returns (uint256);

// 미리보기
function previewDeposit(uint256 assets) external view returns (uint256);
function previewMint(uint256 shares) external view returns (uint256);
function previewWithdraw(uint256 assets) external view returns (uint256);
function previewRedeem(uint256 shares) external view returns (uint256);
```

### 4. 한도 (4개)

```solidity
function maxDeposit(address receiver) external view returns (uint256);
function maxMint(address receiver) external view returns (uint256);
function maxWithdraw(address owner) external view returns (uint256);
function maxRedeem(address owner) external view returns (uint256);
```

### 5. ERC-20 (4개)

```solidity
function balanceOf(address account) external view returns (uint256);
function totalSupply() external view returns (uint256);
function transfer(address to, uint256 amount) external returns (bool);
function approve(address spender, uint256 amount) external returns (bool);
```

## 🧮 핵심 공식

### Share Price
```solidity
sharePrice = totalAssets / totalSupply
```

### Asset → Share 변환
```solidity
shares = (assets * totalSupply) / totalAssets
```

### Share → Asset 변환
```solidity
assets = (shares * totalAssets) / totalSupply
```

### 첫 예치 (supply == 0)
```solidity
shares = assets  // 1:1 비율
```

## 🔄 함수 선택 가이드

```
┌────────────────────────────────────────────┐
│ 무엇을 확정하고 싶은가?                      │
├────────────────────────────────────────────┤
│                                            │
│ 예치할 자산 수량을 확정:                     │
│   → deposit(1000 USDC)                    │
│   → 공유는 계산됨                           │
│                                            │
│ 받을 공유 수량을 확정:                       │
│   → mint(1000 shares)                     │
│   → 자산은 계산됨                           │
│                                            │
│ 인출할 자산 수량을 확정:                     │
│   → withdraw(1000 USDC)                   │
│   → 소각될 공유는 계산됨                     │
│                                            │
│ 소각할 공유 수량을 확정:                     │
│   → redeem(1000 shares)                   │
│   → 받을 자산은 계산됨                       │
│                                            │
└────────────────────────────────────────────┘

💡 일반적으로 deposit()와 redeem() 가장 많이 사용!
```

## 💻 코드 템플릿

### 기본 예치
```solidity
// 1. 자산 승인
IERC20(asset).approve(address(vault), amount);

// 2. 예치
uint256 shares = vault.deposit(amount, msg.sender);
```

### 안전한 예치 (슬리피지 보호)
```solidity
// 1. 미리보기
uint256 expectedShares = vault.previewDeposit(amount);
require(expectedShares >= minShares, "Too much slippage");

// 2. 승인 & 예치
IERC20(asset).approve(address(vault), amount);
uint256 shares = vault.deposit(amount, msg.sender);
```

### 전액 인출
```solidity
// 1. 내 공유 확인
uint256 myShares = vault.balanceOf(msg.sender);

// 2. 상환
uint256 assets = vault.redeem(myShares, msg.sender, msg.sender);
```

### 일부 인출 (자산 기준)
```solidity
// 1. 인출할 자산 지정
uint256 assetsToWithdraw = 1000e6; // 1000 USDC

// 2. 필요한 공유 계산
uint256 sharesNeeded = vault.previewWithdraw(assetsToWithdraw);

// 3. 인출
vault.withdraw(assetsToWithdraw, msg.sender, msg.sender);
```

## 📊 실전 패턴

### 패턴 1: APY 계산
```solidity
function getAPY(address vaultAddress) public view returns (uint256) {
    IERC4626 vault = IERC4626(vaultAddress);
    uint256 sharePrice = vault.convertToAssets(1e18);

    // 간단한 APY (실제로는 시간 가중 필요)
    return sharePrice > 1e18
        ? ((sharePrice - 1e18) * 10000) / 1e18
        : 0;
}
```

### 패턴 2: 최적 볼트 찾기
```solidity
function findBestVault(
    IERC4626[] calldata vaults,
    uint256 amount
) public view returns (address best) {
    uint256 maxShares = 0;

    for (uint i = 0; i < vaults.length; i++) {
        uint256 shares = vaults[i].previewDeposit(amount);
        if (shares > maxShares) {
            maxShares = shares;
            best = address(vaults[i]);
        }
    }
}
```

### 패턴 3: 볼트 마이그레이션
```solidity
function migrate(
    IERC4626 fromVault,
    IERC4626 toVault,
    uint256 shares
) external {
    // 1. 인출
    fromVault.transferFrom(msg.sender, address(this), shares);
    uint256 assets = fromVault.redeem(shares, address(this), address(this));

    // 2. 재예치
    IERC20(fromVault.asset()).approve(address(toVault), assets);
    toVault.deposit(assets, msg.sender);
}
```

### 패턴 4: 배치 예치
```solidity
function batchDeposit(
    IERC4626[] calldata vaults,
    uint256[] calldata amounts
) external {
    for (uint i = 0; i < vaults.length; i++) {
        IERC20 asset = IERC20(vaults[i].asset());
        asset.transferFrom(msg.sender, address(this), amounts[i]);
        asset.approve(address(vaults[i]), amounts[i]);
        vaults[i].deposit(amounts[i], msg.sender);
    }
}
```

## ⚠️ 반올림 방향

```solidity
┌─────────────────────────────────────────────┐
│ 함수              │ 반올림 방향 │ 이유        │
├─────────────────────────────────────────────┤
│ previewDeposit   │ DOWN       │ 볼트 보호   │
│ previewMint      │ UP         │ 볼트 보호   │
│ previewWithdraw  │ UP         │ 볼트 보호   │
│ previewRedeem    │ DOWN       │ 볼트 보호   │
└─────────────────────────────────────────────┘

원칙: 사용자에게 불리하게 = 볼트 보호 = 공격 방지
```

## 🛡️ 보안 체크리스트

### ✅ 구현 시 필수 확인사항

```solidity
// 1. Inflation Attack 방어
□ Virtual Shares/Assets 사용
□ Initial Deposit (dead address)
□ Minimum Deposit 제한

// 2. Reentrancy 방어
□ Checks-Effects-Interactions 패턴
□ ReentrancyGuard 적용
□ 상태 변경 먼저, 외부 호출 나중에

// 3. 반올림 방향
□ Deposit: 사용자 적게 받음
□ Mint: 사용자 많이 지불
□ Withdraw: 사용자 많이 소각
□ Redeem: 사용자 적게 받음

// 4. 접근 제어
□ Emergency Pause 기능
□ Fee 상한 설정
□ Blacklist/Whitelist (필요시)

// 5. Oracle 보안
□ TWAP 사용 (단일 블록 가격 X)
□ Price Deviation 체크
□ Fallback Oracle
```

## 🔍 디버깅 가이드

### 문제: 예치 후 0 shares 받음
```solidity
// 원인: Inflation Attack 당함
// 해결: Virtual Shares 추가

function _convertToShares(uint256 assets) internal view returns (uint256) {
    uint256 supply = totalSupply();
    return (assets * (supply + 1e6)) / (totalAssets() + 1);
}
```

### 문제: Share Price가 감소함
```solidity
// 원인 1: totalAssets 계산 오류
function totalAssets() public view returns (uint256) {
    // ❌ 나쁜 예: 일부 자산 누락
    return asset.balanceOf(address(this));

    // ✅ 좋은 예: 모든 자산 포함
    return asset.balanceOf(address(this))
         + externalAssets()
         + pendingRewards();
}

// 원인 2: 수수료 과다
// 해결: Fee 상한 설정
require(fee <= MAX_FEE, "Fee too high");
```

### 문제: Withdrawal 실패
```solidity
// 원인: Allowance 부족 (owner != caller)
vault.withdraw(assets, receiver, owner);

// 해결: owner가 caller에게 승인 필요
vault.approve(caller, shares);
```

## 🌐 ethers.js 빠른 시작

### 연결
```javascript
const vault = new ethers.Contract(
    VAULT_ADDRESS,
    ["function deposit(uint256,address) returns(uint256)"],
    signer
);
```

### 예치
```javascript
// 1. 승인
await asset.approve(vault.address, amount);

// 2. 예치
const tx = await vault.deposit(amount, userAddress);
await tx.wait();
```

### APY 조회
```javascript
const sharePrice = await vault.convertToAssets(ethers.parseEther("1"));
const apy = ((Number(sharePrice) / 1e18) - 1) * 100;
console.log(`APY: ${apy.toFixed(2)}%`);
```

## 📈 가스 최적화 팁

### 1. 배치 연산
```solidity
// ❌ 나쁜 예: 개별 호출
for (uint i = 0; i < users.length; i++) {
    vault.deposit(amounts[i], users[i]);
}

// ✅ 좋은 예: 배치 함수
vault.batchDeposit(users, amounts);
```

### 2. Storage vs Memory
```solidity
// ❌ 나쁜 예: SLOAD 반복
function calculate() public view returns (uint256) {
    return totalAssets() * totalSupply() / totalAssets();
    // totalAssets() 2번 호출!
}

// ✅ 좋은 예: 캐싱
function calculate() public view returns (uint256) {
    uint256 assets = totalAssets();
    return assets * totalSupply() / assets;
}
```

### 3. Unchecked 사용
```solidity
// ✅ 오버플로우 불가능한 경우
function increment() internal {
    unchecked {
        counter++;  // 가스 절약
    }
}
```

## 🎓 학습 순서

```
1주차: 기본 개념
  □ ERC-20 복습
  □ Assets vs Shares
  □ deposit() & redeem() 사용

2주차: 수학 이해
  □ Share Price 계산
  □ Conversion 공식
  □ Preview 함수

3주차: 보안
  □ Inflation Attack
  □ Rounding Direction
  □ Reentrancy

4주차: 고급 기능
  □ Multi-vault Strategy
  □ Auto-compound
  □ Fee Structure
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 설명
- [EIP4626Example.sol](./contracts/EIP4626Example.sol) - 구현 예제
- [EIP-4626 Spec](https://eips.ethereum.org/EIPS/eip-4626) - 공식 문서

## 💡 자주 사용하는 스니펫

### Solidity: 기본 볼트 구현
```solidity
contract MyVault is ERC4626 {
    constructor(IERC20 _asset)
        ERC4626(_asset)
        ERC20("My Vault", "mvToken")
    {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
```

### JavaScript: 수익 확인
```javascript
const shares = await vault.balanceOf(user);
const value = await vault.convertToAssets(shares);
const profit = value - initialInvestment;
console.log(`Profit: ${ethers.formatUnits(profit, 6)} USDC`);
```

### Solidity: 안전한 예치
```solidity
function safeDeposit(IERC4626 vault, uint256 amount, uint256 minShares)
    external
{
    require(
        vault.previewDeposit(amount) >= minShares,
        "Slippage too high"
    );

    IERC20(vault.asset()).approve(address(vault), amount);
    vault.deposit(amount, msg.sender);
}
```

---

## 🎯 핵심 요약

```
EIP-4626 = DeFi 볼트의 USB 규격

Before: 각 프로토콜마다 다른 API
After:  모든 프로토콜이 같은 API

핵심: Assets ↔ Shares 변환
목적: 수익 창출 + 표준화
결과: 프로토콜 간 상호 운용성
```

---

*마지막 업데이트: 2024*
*작성자: EIP Study Group*
