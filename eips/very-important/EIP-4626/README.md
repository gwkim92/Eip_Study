# EIP-4626: Tokenized Vault Standard (토큰화된 볼트 표준)

> **"DeFi 프로토콜 간 수익 창출 볼트의 표준 인터페이스"**

## 목차
- [개요](#개요)
- [EIP-4626이 해결하는 문제](#eip-4626이-해결하는-문제)
- [핵심 개념](#핵심-개념)
- [주요 함수](#주요-함수)
- [수학적 모델](#수학적-모델)
- [실전 예제](#실전-예제)
- [보안 고려사항](#보안-고려사항)
- [실제 사용 사례](#실제-사용-사례)
- [학습 로드맵](#학습-로드맵)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

### EIP-4626이란?

EIP-4626은 **수익 창출 볼트(Yield-bearing Vaults)**에 대한 표준 API를 정의합니다. 이 표준은 사용자가 자산(asset)을 예치하고 공유 토큰(shares)을 받는 방식을 통일합니다.

**간단한 비유:**
- 은행 예금: 돈을 맡기면(deposit) 통장(shares)을 받고, 이자가 붙습니다
- EIP-4626 Vault: 토큰을 맡기면 공유 토큰을 받고, 수익이 쌓입니다

### 왜 중요한가?

```
Before EIP-4626 (2022년 이전):
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Yearn     │     │   Aave      │     │  Compound   │
│   Vault     │     │   aToken    │     │   cToken    │
├─────────────┤     ├─────────────┤     ├─────────────┤
│ deposit()   │     │ mint()      │     │ supply()    │
│ withdraw()  │     │ redeem()    │     │ borrow()    │
│ balance()   │     │ balanceOf() │     │ getBalance()│
└─────────────┘     └─────────────┘     └─────────────┘
     ❌ 각자 다른 함수명, 다른 로직

After EIP-4626:
┌─────────────────────────────────────────────────┐
│           EIP-4626 Standard Interface           │
├─────────────────────────────────────────────────┤
│ deposit(), withdraw(), mint(), redeem()         │
│ totalAssets(), convertToShares(), preview*()    │
└─────────────────────────────────────────────────┘
          ↓              ↓              ↓
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │  Yearn  │    │  Aave   │    │Compound │
    └─────────┘    └─────────┘    └─────────┘
         ✅ 통일된 인터페이스, 상호 호환 가능
```

**주요 장점:**
1. **상호 운용성**: 모든 볼트가 동일한 인터페이스 사용
2. **통합 용이성**: 한 번의 코드로 모든 EIP-4626 볼트 사용 가능
3. **수익률 비교**: 표준화된 방식으로 다양한 프로토콜의 수익률 비교
4. **컴포저빌리티**: DeFi 레고처럼 쉽게 조합 가능

---

## EIP-4626이 해결하는 문제

### 문제 1: 프로토콜마다 다른 인터페이스

**Before (각 프로토콜마다 다른 방식):**
```solidity
// Yearn Vault
yearnVault.deposit(1000 ether);
uint256 shares = yearnVault.balanceOf(user);

// Aave
aToken.mint(1000 ether, user);
uint256 balance = aToken.balanceOf(user);

// Compound
cToken.supply(1000 ether);
uint256 balance = cToken.balanceOfUnderlying(user);

// 😫 각각 다른 함수명, 다른 파라미터, 다른 로직!
```

**After (EIP-4626 통일):**
```solidity
// 모든 프로토콜이 동일한 인터페이스
function depositToAnyVault(IERC4626 vault, uint256 amount) external {
    vault.deposit(amount, msg.sender);
    // ✅ Yearn, Aave, Compound 모두 동일한 방식!
}
```

### 문제 2: 수익률 계산 방식의 불일치

**Before:**
```solidity
// Yearn: pricePerShare
uint256 yearnAPY = (yearnVault.pricePerShare() - 1e18) * 100;

// Aave: liquidityIndex
uint256 aaveAPY = calculateAaveAPY(aToken.liquidityIndex());

// Compound: exchangeRate
uint256 compoundAPY = calculateCompoundAPY(cToken.exchangeRateCurrent());

// 😫 각각 다른 계산 방식!
```

**After:**
```solidity
// 모든 볼트에서 동일한 방식
function calculateAPY(IERC4626 vault) external view returns (uint256) {
    uint256 sharePrice = vault.convertToAssets(1e18);
    // ✅ 표준화된 계산!
    return ((sharePrice - 1e18) * 100);
}
```

### 문제 3: 통합의 어려움

**Before:**
```solidity
contract MultiVaultStrategy {
    // 각 프로토콜마다 별도 로직 필요
    function depositToYearn(uint256 amount) external { /*...*/ }
    function depositToAave(uint256 amount) external { /*...*/ }
    function depositToCompound(uint256 amount) external { /*...*/ }

    // 😫 100줄 이상의 중복 코드!
}
```

**After:**
```solidity
contract MultiVaultStrategy {
    // 하나의 함수로 모든 볼트 처리
    function depositToVault(IERC4626 vault, uint256 amount) external {
        vault.deposit(amount, msg.sender);
        // ✅ 10줄의 깔끔한 코드!
    }
}
```

---

## 핵심 개념

### 1. Assets vs Shares

EIP-4626의 가장 중요한 개념은 **자산(assets)**과 **공유(shares)**의 구분입니다.

```
┌─────────────────────────────────────────────────┐
│                    Vault                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  Assets (기초 자산):                             │
│  ┌──────────────────────────────────────┐      │
│  │  USDC, DAI, WETH 등 실제 토큰        │      │
│  │  총 1,100 USDC (초기 1,000 + 수익 100)│      │
│  └──────────────────────────────────────┘      │
│                                                 │
│  Shares (공유 토큰):                             │
│  ┌──────────────────────────────────────┐      │
│  │  Vault Token (vToken)                │      │
│  │  총 1,000 vToken                     │      │
│  │                                      │      │
│  │  1 vToken = 1.1 USDC (수익 반영)     │      │
│  └──────────────────────────────────────┘      │
└─────────────────────────────────────────────────┘

공식: sharePrice = totalAssets / totalShares
     1.1 USDC = 1,100 USDC / 1,000 vToken
```

**실제 예:**
```solidity
// 사용자 A: 1000 USDC 예치
vault.deposit(1000e6, userA);
// → 1000 vToken 받음 (sharePrice = 1.0)

// ⏰ 시간 경과 → 수익 100 USDC 발생
// totalAssets = 1100 USDC
// totalShares = 1000 vToken
// sharePrice = 1.1 USDC

// 사용자 B: 1100 USDC 예치
vault.deposit(1100e6, userB);
// → 1000 vToken 받음 (1100 / 1.1 = 1000)

// 사용자 A 인출
vault.redeem(1000 vToken, userA, userA);
// → 1100 USDC 받음 (1000 * 1.1 = 1100)
// ✅ 100 USDC 수익 실현!
```

### 2. Deposit vs Mint

EIP-4626은 예치를 위한 **두 가지 방법**을 제공합니다:

```
Deposit (자산 기준):
┌─────────────────────────────────────────┐
│ "1000 USDC를 넣으면 몇 개의 공유 받나요?" │
├─────────────────────────────────────────┤
│ Input:  1000 USDC (assets)             │
│ Output: ??? shares (계산됨)             │
└─────────────────────────────────────────┘

Mint (공유 기준):
┌─────────────────────────────────────────┐
│ "1000 공유를 받으려면 얼마를 넣어야 하나요?"│
├─────────────────────────────────────────┤
│ Input:  1000 shares                    │
│ Output: ??? USDC (계산됨)               │
└─────────────────────────────────────────┘
```

**코드 예제:**
```solidity
// Scenario: sharePrice = 1.1 USDC

// 방법 1: Deposit (자산 기준)
uint256 shares = vault.deposit(1100e6, user);
// → 1000 shares 받음

// 방법 2: Mint (공유 기준)
uint256 assets = vault.mint(1000e18, user);
// → 1100 USDC 필요

// ✅ 결과는 동일하지만 접근 방식이 다름!
```

### 3. Withdraw vs Redeem

마찬가지로 인출도 **두 가지 방법**이 있습니다:

```
Withdraw (자산 기준):
┌─────────────────────────────────────────┐
│ "1000 USDC를 빼려면 공유를 몇 개 태워야 하나요?"│
├─────────────────────────────────────────┤
│ Input:  1000 USDC (assets)             │
│ Output: ??? shares (소각됨)             │
└─────────────────────────────────────────┘

Redeem (공유 기준):
┌─────────────────────────────────────────┐
│ "1000 공유를 태우면 얼마를 받나요?"        │
├─────────────────────────────────────────┤
│ Input:  1000 shares                    │
│ Output: ??? USDC (받음)                 │
└─────────────────────────────────────────┘
```

**코드 예제:**
```solidity
// Scenario: sharePrice = 1.1 USDC

// 방법 1: Withdraw (자산 기준)
uint256 shares = vault.withdraw(1100e6, user, user);
// → 1000 shares 소각됨

// 방법 2: Redeem (공유 기준)
uint256 assets = vault.redeem(1000e18, user, user);
// → 1100 USDC 받음

// ✅ 결과는 동일!
```

### 4. Preview Functions (미리보기 함수)

EIP-4626의 강력한 기능 중 하나는 **거래 전 결과를 미리 볼 수 있다**는 점입니다.

```
예측 가능한 DeFi:
┌─────────────────────────────────────────┐
│  Before Transaction (미리 확인)         │
├─────────────────────────────────────────┤
│  previewDeposit(1000 USDC)             │
│  → 909 shares 받을 예정                 │
│                                         │
│  "괜찮네! 실행하자"                      │
├─────────────────────────────────────────┤
│  After Transaction (실제 실행)          │
├─────────────────────────────────────────┤
│  deposit(1000 USDC)                    │
│  → 909 shares 받음 ✅                   │
└─────────────────────────────────────────┘
```

**모든 Preview 함수:**
```solidity
// 예치 미리보기
previewDeposit(assets)  → 받을 shares
previewMint(shares)     → 필요한 assets

// 인출 미리보기
previewWithdraw(assets) → 소각될 shares
previewRedeem(shares)   → 받을 assets
```

**실전 활용:**
```solidity
// 1. 예치 전 슬리피지 확인
uint256 expectedShares = vault.previewDeposit(1000e6);
require(expectedShares >= minShares, "Too much slippage!");
vault.deposit(1000e6, msg.sender);

// 2. 최적의 볼트 찾기
IERC4626[] memory vaults = [vaultA, vaultB, vaultC];
uint256 bestShares = 0;
IERC4626 bestVault;

for (uint i = 0; i < vaults.length; i++) {
    uint256 shares = vaults[i].previewDeposit(1000e6);
    if (shares > bestShares) {
        bestShares = shares;
        bestVault = vaults[i];
    }
}

// ✅ 최고 수익률 볼트에 예치!
bestVault.deposit(1000e6, msg.sender);
```

---

## 주요 함수

### 필수 구현 함수 (20개)

EIP-4626은 총 20개의 함수를 정의하며, 모두 구현해야 합니다.

#### 1. 메타데이터 (1개)

```solidity
/// @notice 기초 자산 토큰 주소 반환
/// @return assetTokenAddress 기초 자산의 ERC-20 주소
function asset() external view returns (address assetTokenAddress);
```

**사용 예:**
```solidity
address usdcAddress = vault.asset();
IERC20(usdcAddress).approve(address(vault), 1000e6);
```

#### 2. 예치/인출 로직 (4개)

```solidity
/// @notice 자산을 예치하고 공유 토큰 발행
/// @param assets 예치할 자산 수량
/// @param receiver 공유 토큰을 받을 주소
/// @return shares 발행된 공유 토큰 수량
function deposit(uint256 assets, address receiver)
    external returns (uint256 shares);

/// @notice 공유 토큰을 받기 위해 자산 예치
/// @param shares 받고자 하는 공유 토큰 수량
/// @param receiver 공유 토큰을 받을 주소
/// @return assets 필요한 자산 수량
function mint(uint256 shares, address receiver)
    external returns (uint256 assets);

/// @notice 자산을 인출하고 공유 토큰 소각
/// @param assets 인출할 자산 수량
/// @param receiver 자산을 받을 주소
/// @param owner 공유 토큰 소유자
/// @return shares 소각된 공유 토큰 수량
function withdraw(uint256 assets, address receiver, address owner)
    external returns (uint256 shares);

/// @notice 공유 토큰을 소각하고 자산 인출
/// @param shares 소각할 공유 토큰 수량
/// @param receiver 자산을 받을 주소
/// @param owner 공유 토큰 소유자
/// @return assets 인출된 자산 수량
function redeem(uint256 shares, address receiver, address owner)
    external returns (uint256 assets);
```

**함수 선택 가이드:**
```
┌─────────────────────────────────────────────────┐
│ 무엇을 기준으로 거래하고 싶은가?                   │
├─────────────────────────────────────────────────┤
│                                                 │
│ 자산 수량이 확실할 때:                            │
│   - 예치: deposit(1000 USDC)                   │
│   - 인출: withdraw(1000 USDC)                  │
│                                                 │
│ 공유 수량이 확실할 때:                            │
│   - 예치: mint(1000 shares)                    │
│   - 인출: redeem(1000 shares)                  │
│                                                 │
└─────────────────────────────────────────────────┘
```

#### 3. 회계 로직 (5개)

```solidity
/// @notice 볼트가 관리하는 총 자산
/// @return totalManagedAssets 총 자산 수량
function totalAssets() external view returns (uint256 totalManagedAssets);

/// @notice 자산을 공유 토큰으로 변환
/// @param assets 변환할 자산 수량
/// @return shares 해당하는 공유 토큰 수량
function convertToShares(uint256 assets)
    external view returns (uint256 shares);

/// @notice 공유 토큰을 자산으로 변환
/// @param shares 변환할 공유 토큰 수량
/// @return assets 해당하는 자산 수량
function convertToAssets(uint256 shares)
    external view returns (uint256 assets);

/// @notice 예치 시 받을 공유 토큰 미리보기
/// @param assets 예치할 자산 수량
/// @return shares 받을 공유 토큰 수량
function previewDeposit(uint256 assets)
    external view returns (uint256 shares);

/// @notice 민트에 필요한 자산 미리보기
/// @param shares 받을 공유 토큰 수량
/// @return assets 필요한 자산 수량
function previewMint(uint256 shares)
    external view returns (uint256 assets);

/// @notice 인출 시 소각될 공유 토큰 미리보기
/// @param assets 인출할 자산 수량
/// @return shares 소각될 공유 토큰 수량
function previewWithdraw(uint256 assets)
    external view returns (uint256 shares);

/// @notice 상환 시 받을 자산 미리보기
/// @param shares 소각할 공유 토큰 수량
/// @return assets 받을 자산 수량
function previewRedeem(uint256 shares)
    external view returns (uint256 assets);
```

**핵심 공식:**
```solidity
// Share Price 계산
sharePrice = totalAssets / totalShares

// Asset → Share 변환
shares = (assets * totalShares) / totalAssets

// Share → Asset 변환
assets = (shares * totalAssets) / totalShares
```

#### 4. 한도 로직 (4개)

```solidity
/// @notice 최대 예치 가능 자산
/// @param receiver 공유 토큰을 받을 주소
/// @return maxAssets 최대 예치 가능 수량
function maxDeposit(address receiver)
    external view returns (uint256 maxAssets);

/// @notice 최대 민트 가능 공유
/// @param receiver 공유 토큰을 받을 주소
/// @return maxShares 최대 민트 가능 수량
function maxMint(address receiver)
    external view returns (uint256 maxShares);

/// @notice 최대 인출 가능 자산
/// @param owner 공유 토큰 소유자
/// @return maxAssets 최대 인출 가능 수량
function maxWithdraw(address owner)
    external view returns (uint256 maxAssets);

/// @notice 최대 상환 가능 공유
/// @param owner 공유 토큰 소유자
/// @return maxShares 최대 상환 가능 수량
function maxRedeem(address owner)
    external view returns (uint256 maxShares);
```

**활용 예:**
```solidity
// 안전한 예치
uint256 max = vault.maxDeposit(msg.sender);
require(amount <= max, "Exceeds max deposit");
vault.deposit(amount, msg.sender);

// 전액 인출
uint256 maxShares = vault.maxRedeem(msg.sender);
vault.redeem(maxShares, msg.sender, msg.sender);
```

#### 5. ERC-20 표준 (6개)

EIP-4626 볼트는 ERC-20 토큰이기도 합니다 (공유 토큰).

```solidity
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function transfer(address to, uint256 amount) external returns (bool);
function allowance(address owner, address spender) external view returns (uint256);
function approve(address spender, uint256 amount) external returns (bool);
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```

**중요:** 공유 토큰은 자유롭게 거래 가능합니다!
```solidity
// 공유 토큰 전송
vaultToken.transfer(friend, 100e18);

// 공유 토큰 거래
uniswapRouter.swapExactTokensForTokens(
    100e18,
    minOut,
    [address(vaultToken), address(usdc)],
    msg.sender,
    deadline
);
```

---

## 수학적 모델

### 1. Share Price 계산

```solidity
sharePrice = totalAssets / totalShares
```

**예제 시나리오:**
```
Initial State:
- totalAssets = 0
- totalShares = 0
- sharePrice = undefined (특수 케이스)

After User A deposits 1000 USDC:
- totalAssets = 1000 USDC
- totalShares = 1000 vToken
- sharePrice = 1.0 USDC

After 10% yield:
- totalAssets = 1100 USDC (1000 + 100)
- totalShares = 1000 vToken (unchanged)
- sharePrice = 1.1 USDC

After User B deposits 1100 USDC:
- totalAssets = 2200 USDC (1100 + 1100)
- totalShares = 2000 vToken (1000 + 1000)
- sharePrice = 1.1 USDC (unchanged)

After User A redeems 1000 vToken:
- totalAssets = 1100 USDC (2200 - 1100)
- totalShares = 1000 vToken (2000 - 1000)
- sharePrice = 1.1 USDC (unchanged)
```

### 2. Conversion Formulas

```solidity
// Asset → Share (Deposit)
function convertToShares(uint256 assets) public view returns (uint256) {
    uint256 supply = totalShares;

    // 첫 예치: 1:1 비율
    if (supply == 0) {
        return assets;
    }

    // 이후 예치: 현재 sharePrice 적용
    return (assets * supply) / totalAssets;
}

// Share → Asset (Redeem)
function convertToAssets(uint256 shares) public view returns (uint256) {
    uint256 supply = totalShares;

    // 공유가 없으면 1:1
    if (supply == 0) {
        return shares;
    }

    // 현재 sharePrice 적용
    return (shares * totalAssets) / supply;
}
```

### 3. Rounding Direction (반올림 방향)

EIP-4626은 **사용자에게 불리하게** 반올림하여 볼트를 보호합니다.

```solidity
// Deposit: 사용자는 적게 받음 (볼트 보호)
function previewDeposit(uint256 assets) public view returns (uint256) {
    return convertToShares(assets); // Round DOWN
}

// Mint: 사용자는 많이 지불 (볼트 보호)
function previewMint(uint256 shares) public view returns (uint256) {
    uint256 supply = totalShares;
    return supply == 0
        ? shares
        : (shares * totalAssets + supply - 1) / supply; // Round UP
}

// Withdraw: 사용자는 많이 소각 (볼트 보호)
function previewWithdraw(uint256 assets) public view returns (uint256) {
    uint256 supply = totalShares;
    return supply == 0
        ? assets
        : (assets * supply + totalAssets - 1) / totalAssets; // Round UP
}

// Redeem: 사용자는 적게 받음 (볼트 보호)
function previewRedeem(uint256 shares) public view returns (uint256) {
    return convertToAssets(shares); // Round DOWN
}
```

**왜 볼트에게 유리하게?**
```
만약 사용자에게 유리하게 반올림하면:
┌─────────────────────────────────────────┐
│ 1000명의 사용자가 각각 0.001 USDC씩     │
│ 더 받으면 → 1 USDC 손실                │
│                                         │
│ 공격자가 이를 악용할 수 있음!            │
└─────────────────────────────────────────┘

볼트에게 유리하게 반올림:
┌─────────────────────────────────────────┐
│ 0.001 USDC씩 볼트에 남음                │
│ → 전체 예치자에게 공평하게 분배됨        │
│ ✅ 공격 불가능!                         │
└─────────────────────────────────────────┘
```

---

## 실전 예제

### 예제 1: 기본 사용법

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract VaultUser {
    IERC4626 public vault;
    IERC20 public asset;

    constructor(address vaultAddress) {
        vault = IERC4626(vaultAddress);
        asset = IERC20(vault.asset());
    }

    /// @notice 1000 USDC 예치
    function depositExample() external {
        uint256 amount = 1000e6; // 1000 USDC

        // 1. 자산 승인
        asset.approve(address(vault), amount);

        // 2. 예상 공유 확인
        uint256 expectedShares = vault.previewDeposit(amount);

        // 3. 예치 실행
        uint256 shares = vault.deposit(amount, msg.sender);

        // 4. 검증
        require(shares == expectedShares, "Unexpected shares");
    }

    /// @notice 모든 공유 토큰 상환
    function redeemAll() external {
        // 1. 내 공유 토큰 확인
        uint256 myShares = vault.balanceOf(msg.sender);

        // 2. 받을 자산 미리보기
        uint256 expectedAssets = vault.previewRedeem(myShares);

        // 3. 상환 실행
        uint256 assets = vault.redeem(myShares, msg.sender, msg.sender);

        // 4. 검증
        require(assets == expectedAssets, "Unexpected assets");
    }
}
```

### 예제 2: 수익률 비교 및 최적 볼트 선택

```solidity
contract VaultAggregator {
    /// @notice 최고 수익률 볼트에 예치
    function depositToBestVault(
        IERC4626[] calldata vaults,
        uint256 amount
    ) external returns (address bestVault, uint256 shares) {
        require(vaults.length > 0, "No vaults");

        IERC20 asset = IERC20(vaults[0].asset());

        // 1. 모든 볼트의 수익률 비교
        uint256 maxShares = 0;
        uint256 bestIndex = 0;

        for (uint256 i = 0; i < vaults.length; i++) {
            // 같은 자산만 비교
            require(vaults[i].asset() == address(asset), "Asset mismatch");

            uint256 expectedShares = vaults[i].previewDeposit(amount);
            if (expectedShares > maxShares) {
                maxShares = expectedShares;
                bestIndex = i;
            }
        }

        // 2. 최고 수익률 볼트에 예치
        bestVault = address(vaults[bestIndex]);
        asset.transferFrom(msg.sender, address(this), amount);
        asset.approve(bestVault, amount);
        shares = vaults[bestIndex].deposit(amount, msg.sender);
    }

    /// @notice 모든 볼트의 APY 계산
    function calculateAPYs(IERC4626[] calldata vaults)
        external
        view
        returns (uint256[] memory apys)
    {
        apys = new uint256[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            // 1 share의 가치 계산
            uint256 sharePrice = vaults[i].convertToAssets(1e18);

            // APY 계산 (간단한 방식)
            // 실제로는 시간 가중 수익률 사용 필요
            apys[i] = sharePrice > 1e18
                ? ((sharePrice - 1e18) * 10000) / 1e18
                : 0;
        }
    }
}
```

### 예제 3: 볼트 간 마이그레이션

```solidity
contract VaultMigrator {
    /// @notice 한 볼트에서 다른 볼트로 이동
    function migrate(
        IERC4626 fromVault,
        IERC4626 toVault,
        uint256 shares
    ) external returns (uint256 newShares) {
        require(
            fromVault.asset() == toVault.asset(),
            "Different assets"
        );

        // 1. 기존 볼트에서 인출
        fromVault.transferFrom(msg.sender, address(this), shares);
        uint256 assets = fromVault.redeem(
            shares,
            address(this),
            address(this)
        );

        // 2. 새 볼트에 예치
        IERC20(fromVault.asset()).approve(address(toVault), assets);
        newShares = toVault.deposit(assets, msg.sender);
    }

    /// @notice 리밸런싱 (여러 볼트로 분산)
    function rebalance(
        IERC4626 fromVault,
        IERC4626[] calldata toVaults,
        uint256[] calldata weights // basis points (10000 = 100%)
    ) external {
        require(toVaults.length == weights.length, "Length mismatch");

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        require(totalWeight == 10000, "Weights must sum to 100%");

        // 1. 모든 자산 인출
        uint256 shares = fromVault.balanceOf(msg.sender);
        fromVault.transferFrom(msg.sender, address(this), shares);
        uint256 totalAssets = fromVault.redeem(
            shares,
            address(this),
            address(this)
        );

        IERC20 asset = IERC20(fromVault.asset());

        // 2. 가중치에 따라 분산 예치
        for (uint256 i = 0; i < toVaults.length; i++) {
            uint256 amount = (totalAssets * weights[i]) / 10000;
            asset.approve(address(toVaults[i]), amount);
            toVaults[i].deposit(amount, msg.sender);
        }
    }
}
```

### 예제 4: 조건부 전략

```solidity
contract ConditionalStrategy {
    /// @notice APY가 최소 기준 이상일 때만 예치
    function depositIfGoodYield(
        IERC4626 vault,
        uint256 amount,
        uint256 minAPY // basis points
    ) external {
        // 1. 현재 APY 계산
        uint256 sharePrice = vault.convertToAssets(1e18);
        uint256 currentAPY = sharePrice > 1e18
            ? ((sharePrice - 1e18) * 10000) / 1e18
            : 0;

        // 2. 최소 기준 확인
        require(currentAPY >= minAPY, "APY too low");

        // 3. 예치
        IERC20 asset = IERC20(vault.asset());
        asset.transferFrom(msg.sender, address(this), amount);
        asset.approve(address(vault), amount);
        vault.deposit(amount, msg.sender);
    }

    /// @notice 수익률이 떨어지면 자동 인출
    function withdrawIfBadYield(
        IERC4626 vault,
        uint256 maxAPY // basis points
    ) external {
        uint256 sharePrice = vault.convertToAssets(1e18);
        uint256 currentAPY = sharePrice > 1e18
            ? ((sharePrice - 1e18) * 10000) / 1e18
            : 0;

        if (currentAPY > maxAPY) {
            // 전액 인출
            uint256 shares = vault.balanceOf(msg.sender);
            vault.transferFrom(msg.sender, address(this), shares);
            vault.redeem(shares, msg.sender, address(this));
        }
    }
}
```

### 예제 5: 배치 처리

```solidity
contract BatchVaultOperations {
    /// @notice 여러 볼트에 동시 예치
    function batchDeposit(
        IERC4626[] calldata vaults,
        uint256[] calldata amounts
    ) external returns (uint256[] memory shares) {
        require(vaults.length == amounts.length, "Length mismatch");

        shares = new uint256[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            IERC20 asset = IERC20(vaults[i].asset());
            asset.transferFrom(msg.sender, address(this), amounts[i]);
            asset.approve(address(vaults[i]), amounts[i]);
            shares[i] = vaults[i].deposit(amounts[i], msg.sender);
        }
    }

    /// @notice 여러 볼트에서 동시 인출
    function batchRedeem(
        IERC4626[] calldata vaults
    ) external returns (uint256[] memory assets) {
        assets = new uint256[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            uint256 shares = vaults[i].balanceOf(msg.sender);
            if (shares > 0) {
                vaults[i].transferFrom(msg.sender, address(this), shares);
                assets[i] = vaults[i].redeem(
                    shares,
                    msg.sender,
                    address(this)
                );
            }
        }
    }
}
```

---

## 보안 고려사항

### 1. Inflation Attack (인플레이션 공격)

가장 위험한 공격 벡터 중 하나입니다.

**공격 시나리오:**
```
Step 1: 공격자가 첫 예치
┌─────────────────────────────────────────┐
│ Attacker deposits 1 wei                │
│ → Receives 1 share                     │
│                                         │
│ totalAssets = 1 wei                    │
│ totalShares = 1 share                  │
└─────────────────────────────────────────┘

Step 2: 공격자가 직접 자산 전송
┌─────────────────────────────────────────┐
│ Attacker transfers 1,000,000 USDC      │
│ directly to vault (not via deposit)    │
│                                         │
│ totalAssets = 1,000,000 USDC + 1 wei   │
│ totalShares = 1 share (unchanged!)     │
│                                         │
│ sharePrice = 1,000,000 USDC            │
└─────────────────────────────────────────┘

Step 3: 피해자 예치
┌─────────────────────────────────────────┐
│ Victim deposits 1,000,000 USDC         │
│                                         │
│ shares = (1,000,000 * 1) / 1,000,000   │
│        = 1 share                       │
│                                         │
│ totalAssets = 2,000,000 USDC           │
│ totalShares = 2 shares                 │
└─────────────────────────────────────────┘

Step 4: 공격자 인출
┌─────────────────────────────────────────┐
│ Attacker redeems 1 share               │
│                                         │
│ assets = (1 * 2,000,000) / 2           │
│        = 1,000,000 USDC                │
│                                         │
│ 😈 공격자는 1 wei 투자로               │
│    1,000,000 USDC를 벌었습니다!        │
└─────────────────────────────────────────┘
```

**방어 방법 1: Virtual Shares & Assets**
```solidity
contract SecureVault is ERC4626 {
    // 가상의 자산과 공유를 추가
    uint256 private constant VIRTUAL_SHARES = 1e6;
    uint256 private constant VIRTUAL_ASSETS = 1;

    function _convertToShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = totalSupply();
        return (assets * (supply + VIRTUAL_SHARES))
               / (totalAssets() + VIRTUAL_ASSETS);
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        uint256 supply = totalSupply();
        return (shares * (totalAssets() + VIRTUAL_ASSETS))
               / (supply + VIRTUAL_SHARES);
    }
}
```

**방어 방법 2: Initial Deposit**
```solidity
contract SecureVault is ERC4626 {
    bool private initialized;

    function initialize() external {
        require(!initialized, "Already initialized");
        initialized = true;

        // 초기 1000 USDC를 dead address에 예치
        _deposit(msg.sender, DEAD_ADDRESS, 1000e6, 1000e18);
    }
}
```

**방어 방법 3: Minimum Deposit**
```solidity
contract SecureVault is ERC4626 {
    uint256 public constant MIN_DEPOSIT = 1000e6; // 1000 USDC

    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256)
    {
        require(assets >= MIN_DEPOSIT, "Below minimum");
        return super.deposit(assets, receiver);
    }
}
```

### 2. Rounding Errors (반올림 오류)

```solidity
// ❌ 나쁜 예: 반올림 방향 틀림
function convertToShares(uint256 assets) public view returns (uint256) {
    // 사용자에게 유리하게 반올림 → 취약!
    return (assets * totalSupply() + totalAssets() - 1) / totalAssets();
}

// ✅ 좋은 예: 볼트에게 유리하게
function convertToShares(uint256 assets) public view returns (uint256) {
    // 사용자는 적게 받음 → 안전!
    return (assets * totalSupply()) / totalAssets();
}
```

### 3. Reentrancy (재진입 공격)

```solidity
// ❌ 취약한 코드
function withdraw(uint256 assets, address receiver, address owner)
    public
    returns (uint256 shares)
{
    shares = previewWithdraw(assets);

    // 먼저 자산 전송 (위험!)
    asset.transfer(receiver, assets);

    // 나중에 공유 소각
    _burn(owner, shares);
}

// ✅ 안전한 코드 (Checks-Effects-Interactions)
function withdraw(uint256 assets, address receiver, address owner)
    public
    returns (uint256 shares)
{
    shares = previewWithdraw(assets);

    // 1. Checks
    require(shares <= balanceOf(owner), "Insufficient shares");

    // 2. Effects (상태 변경 먼저!)
    _burn(owner, shares);

    // 3. Interactions (외부 호출 나중에)
    asset.transfer(receiver, assets);
}
```

### 4. Access Control (접근 제어)

```solidity
contract SecureVault is ERC4626, Ownable {
    bool public depositsEnabled = true;
    bool public withdrawalsEnabled = true;

    mapping(address => bool) public blacklisted;

    /// @notice 긴급 정지
    function pauseDeposits() external onlyOwner {
        depositsEnabled = false;
    }

    function pauseWithdrawals() external onlyOwner {
        withdrawalsEnabled = false;
    }

    /// @notice 블랙리스트
    function blacklist(address user) external onlyOwner {
        blacklisted[user] = true;
    }

    /// @notice 수정된 deposit
    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256)
    {
        require(depositsEnabled, "Deposits paused");
        require(!blacklisted[msg.sender], "Blacklisted");
        return super.deposit(assets, receiver);
    }
}
```

### 5. Oracle Manipulation (오라클 조작)

```solidity
// ❌ 취약한 코드: 단일 블록 가격 사용
function totalAssets() public view returns (uint256) {
    uint256 balance = asset.balanceOf(address(this));
    uint256 aaveBalance = aToken.balanceOf(address(this));

    // 현재 블록의 환율만 사용 (위험!)
    uint256 exchangeRate = oracle.getPrice();

    return balance + (aaveBalance * exchangeRate / 1e18);
}

// ✅ 안전한 코드: TWAP 사용
function totalAssets() public view returns (uint256) {
    uint256 balance = asset.balanceOf(address(this));
    uint256 aaveBalance = aToken.balanceOf(address(this));

    // Time-Weighted Average Price 사용
    uint256 twapPrice = oracle.getTWAP(30 minutes);

    return balance + (aaveBalance * twapPrice / 1e18);
}
```

### 6. Fee Manipulation (수수료 조작)

```solidity
// ❌ 취약한 코드
contract FeeVault is ERC4626 {
    uint256 public performanceFee = 1000; // 10%

    function setPerformanceFee(uint256 newFee) external onlyOwner {
        performanceFee = newFee; // 제한 없음!
    }
}

// ✅ 안전한 코드
contract FeeVault is ERC4626 {
    uint256 public performanceFee = 1000; // 10%
    uint256 public constant MAX_FEE = 2000; // 20% 상한

    event FeeUpdated(uint256 oldFee, uint256 newFee);

    function setPerformanceFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "Fee too high");

        emit FeeUpdated(performanceFee, newFee);
        performanceFee = newFee;
    }
}
```

---

## 실제 사용 사례

### 1. Yearn Finance

Yearn은 EIP-4626을 채택한 가장 대표적인 프로토콜입니다.

```solidity
// Yearn V3 Vault
IERC4626 yvUSDC = IERC4626(0x...);

// 예치
usdc.approve(address(yvUSDC), 10000e6);
uint256 shares = yvUSDC.deposit(10000e6, msg.sender);

// 수익 확인
uint256 currentValue = yvUSDC.convertToAssets(shares);
uint256 profit = currentValue - 10000e6;

// 인출
yvUSDC.redeem(shares, msg.sender, msg.sender);
```

**실제 수익률:**
```
yvUSDC APY: ~5-8%
yvDAI APY: ~4-7%
yvWETH APY: ~3-5%

(2024년 기준, 변동 가능)
```

### 2. Balancer Boosted Pools

Balancer는 EIP-4626 볼트를 유동성 풀에 통합합니다.

```
Balancer Boosted Pool:
┌─────────────────────────────────────────┐
│          Liquidity Pool                 │
├─────────────────────────────────────────┤
│  50% yvUSDC (EIP-4626)                 │
│  50% yvDAI  (EIP-4626)                 │
└─────────────────────────────────────────┘
          ↓
   수익 이중 창출:
   1. Swap 수수료 (Balancer)
   2. Yield (Yearn)
```

### 3. Sommelier Finance

```solidity
// Sommelier Turbo GHO Vault
IERC4626 turboGHO = IERC4626(0x...);

// 자동 리밸런싱 전략
// - Aave GHO 대출
// - Curve 유동성 제공
// - Convex 스테이킹
// 모두 EIP-4626 인터페이스로 통합!

turboGHO.deposit(amount, msg.sender);
```

### 4. Gearbox Protocol

```solidity
// Gearbox Passive Pool
IERC4626 dUSDC = IERC4626(0x...);

// 레버리지 트레이더에게 대출
// EIP-4626으로 쉽게 통합
dUSDC.deposit(100000e6, msg.sender);
```

### 5. Olympus DAO

```solidity
// Olympus RBS Vault
IERC4626 rbsVault = IERC4626(0x...);

// Range-Bound Stability 전략
// OHM 가격 안정화에 기여
rbsVault.deposit(ohmAmount, msg.sender);
```

---

## 학습 로드맵

### Level 1: 초보자 (1-2주)

**목표:** EIP-4626의 기본 개념 이해

```
□ ERC-20 표준 복습
  - totalSupply, balanceOf, transfer
  - approve, transferFrom

□ EIP-4626 핵심 개념
  - Assets vs Shares
  - Deposit vs Mint
  - Withdraw vs Redeem

□ 간단한 볼트 사용
  - Remix에서 BasicERC4626Vault 배포
  - deposit() 함수로 자산 예치
  - redeem() 함수로 인출

□ 실습 과제:
  - TestERC20 토큰 민트
  - BasicERC4626Vault에 1000 토큰 예치
  - 받은 공유 토큰 확인
  - 전액 인출
```

### Level 2: 중급자 (2-3주)

**목표:** 수학적 모델과 Preview 함수 이해

```
□ Share Price 계산
  - totalAssets / totalShares
  - 수익 발생 시 변화 관찰

□ Conversion 함수
  - convertToShares vs previewDeposit 차이
  - convertToAssets vs previewRedeem 차이

□ Rounding Direction
  - 왜 볼트에게 유리하게 반올림?
  - Rounding 방향 바꾸면 어떻게 되나?

□ 실습 과제:
  - YieldGeneratingVault 배포
  - 시간 경과에 따른 sharePrice 변화 관찰
  - 여러 사용자의 예치/인출 시뮬레이션
  - 수익 분배가 공평한지 검증
```

### Level 3: 고급자 (3-4주)

**목표:** 보안 취약점과 최적화 기법

```
□ Inflation Attack
  - 공격 시나리오 이해
  - Virtual Shares 방어 구현
  - Initial Deposit 방어 구현

□ 가스 최적화
  - Storage vs Memory
  - Batch 연산 구현

□ 고급 전략
  - Multi-Vault Aggregator
  - Auto-Rebalancing
  - Conditional Execution

□ 실습 과제:
  - Inflation Attack 재현 (테스트넷)
  - SecureVault 구현
  - VaultAggregator 구현
  - 가스 비용 측정 및 최적화
```

### Level 4: 전문가 (4주+)

**목표:** 프로덕션급 볼트 구현

```
□ 실제 프로토콜 통합
  - Aave, Compound 연동
  - Uniswap V3 연동
  - Chainlink 오라클 통합

□ 고급 기능
  - Fee Structure (Performance, Management)
  - Emergency Pause
  - Access Control
  - Upgradability

□ 감사 준비
  - Slither, Mythril 사용
  - Formal Verification
  - Test Coverage 100%

□ 실전 프로젝트:
  - 나만의 Yield Strategy 구현
  - Testnet 배포 및 테스트
  - 감사 체크리스트 완성
  - Mainnet 배포 준비
```

---

## FAQ

### Q1: EIP-4626이 ERC-20과 다른 점은?

**A:** EIP-4626은 ERC-20을 **확장**합니다.

```
ERC-20 (기본 토큰):
- 전송, 승인, 잔액 조회만 가능
- 토큰 자체가 가치

EIP-4626 (볼트 토큰):
- ERC-20의 모든 기능 +
- 자산 예치/인출 기능
- 공유 토큰이 자산에 대한 청구권
```

### Q2: Deposit vs Mint, 언제 무엇을 사용?

**A:** 무엇을 확정하고 싶은지에 따라 선택

```
Deposit: 자산 수량이 확정
- "정확히 1000 USDC를 넣고 싶어"
- 공유는 얼마가 나올지 계산됨

Mint: 공유 수량이 확정
- "정확히 1000 vToken을 받고 싶어"
- 자산은 얼마가 필요한지 계산됨

대부분의 경우 Deposit 사용!
```

### Q3: Preview 함수가 왜 필요한가?

**A:** 슬리피지 방지와 투명성

```solidity
// Without Preview: 깜깜이 거래
vault.deposit(1000e6, msg.sender);
// 몇 개의 공유를 받을지 모름! 😰

// With Preview: 안심 거래
uint256 expectedShares = vault.previewDeposit(1000e6);
require(expectedShares >= 900e18, "Slippage too high");
vault.deposit(1000e6, msg.sender);
// ✅ 최소 900 공유는 보장!
```

### Q4: totalAssets은 어떻게 계산?

**A:** 볼트가 관리하는 모든 자산의 합

```solidity
function totalAssets() public view returns (uint256) {
    // 1. 볼트에 직접 있는 자산
    uint256 idle = asset.balanceOf(address(this));

    // 2. Aave에 예치된 자산
    uint256 inAave = aToken.balanceOf(address(this));

    // 3. Compound에 예치된 자산
    uint256 inCompound = cToken.balanceOfUnderlying(address(this));

    // 4. 미수금 (pending rewards 등)
    uint256 pending = calculatePendingRewards();

    return idle + inAave + inCompound + pending;
}
```

### Q5: 수익은 어떻게 분배되나?

**A:** Share Price 증가를 통해 자동 분배

```
시나리오:
┌─────────────────────────────────────────┐
│ User A: 1000 shares (50%)              │
│ User B: 1000 shares (50%)              │
│ Total Assets: 2000 USDC                │
│ Share Price: 1.0 USDC                  │
└─────────────────────────────────────────┘

After 10% Yield:
┌─────────────────────────────────────────┐
│ User A: 1000 shares (50%)              │
│ User B: 1000 shares (50%)              │
│ Total Assets: 2200 USDC                │
│ Share Price: 1.1 USDC                  │
│                                         │
│ User A 인출: 1000 * 1.1 = 1100 USDC    │
│ User B 인출: 1000 * 1.1 = 1100 USDC    │
│                                         │
│ ✅ 각각 100 USDC 수익!                 │
└─────────────────────────────────────────┘
```

### Q6: Inflation Attack은 왜 위험한가?

**A:** 첫 예치자가 극단적인 sharePrice 조작 가능

```
공격 비용: 1 wei
공격 이익: 피해자 자산의 ~50%

방어하지 않으면 치명적!
```

자세한 내용은 [보안 고려사항](#보안-고려사항) 참조.

### Q7: 여러 볼트의 수익률을 어떻게 비교?

**A:** `previewDeposit`으로 비교

```solidity
function compareVaults(IERC4626[] calldata vaults)
    external
    view
    returns (uint256[] memory shares)
{
    shares = new uint256[](vaults.length);
    uint256 testAmount = 1000e6; // 1000 USDC

    for (uint256 i = 0; i < vaults.length; i++) {
        shares[i] = vaults[i].previewDeposit(testAmount);
    }

    // 가장 많은 shares를 주는 볼트가 최고!
}
```

### Q8: EIP-4626 볼트는 업그레이드 가능?

**A:** 표준 자체는 업그레이드를 규정하지 않음

```solidity
// 옵션 1: 프록시 패턴 (EIP-1967)
contract UpgradeableVault is ERC4626Upgradeable {
    // OpenZeppelin의 업그레이드 가능한 구현
}

// 옵션 2: 마이그레이션
contract VaultMigrator {
    function migrate(
        IERC4626 oldVault,
        IERC4626 newVault
    ) external {
        // 구 볼트에서 인출 → 신 볼트에 예치
    }
}

// 대부분 마이그레이션 방식 선호 (더 안전)
```

### Q9: 수수료는 어떻게 부과?

**A:** 여러 방식 가능

```solidity
// 방식 1: Deposit/Withdraw 수수료
function deposit(uint256 assets, address receiver)
    public
    returns (uint256)
{
    uint256 fee = (assets * depositFee) / 10000;
    uint256 netAssets = assets - fee;

    asset.transferFrom(msg.sender, feeReceiver, fee);
    // 나머지로 예치
}

// 방식 2: Performance Fee (수익에서 차감)
function harvest() external {
    uint256 profit = calculateProfit();
    uint256 fee = (profit * performanceFee) / 10000;

    _mint(feeReceiver, convertToShares(fee));
    // 나머지는 예치자에게
}

// 방식 3: Management Fee (시간 기반)
function accrueManagementFee() public {
    uint256 timePassed = block.timestamp - lastFeeTime;
    uint256 fee = (totalAssets() * managementFee * timePassed)
                  / (365 days * 10000);

    _mint(feeReceiver, convertToShares(fee));
}
```

### Q10: EIP-4626은 모든 체인에서 사용 가능?

**A:** 네, EVM 호환 체인이면 모두 가능

```
지원 체인:
✅ Ethereum
✅ Arbitrum, Optimism (L2s)
✅ Polygon, BSC, Avalanche
✅ Base, zkSync, Scroll

표준은 동일하나 가스비와 속도만 다름!
```

---

## ethers.js 통합

### 기본 사용법

```javascript
const { ethers } = require("ethers");

// EIP-4626 ABI (필수 함수만)
const ERC4626_ABI = [
    "function asset() view returns (address)",
    "function totalAssets() view returns (uint256)",
    "function convertToShares(uint256 assets) view returns (uint256)",
    "function convertToAssets(uint256 shares) view returns (uint256)",
    "function deposit(uint256 assets, address receiver) returns (uint256)",
    "function mint(uint256 shares, address receiver) returns (uint256)",
    "function withdraw(uint256 assets, address receiver, address owner) returns (uint256)",
    "function redeem(uint256 shares, address receiver, address owner) returns (uint256)",
    "function previewDeposit(uint256 assets) view returns (uint256)",
    "function previewRedeem(uint256 shares) view returns (uint256)",
    "function balanceOf(address account) view returns (uint256)"
];

// 연결
const provider = new ethers.JsonRpcProvider("https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY");
const wallet = new ethers.Wallet("YOUR_PRIVATE_KEY", provider);
const vault = new ethers.Contract(VAULT_ADDRESS, ERC4626_ABI, wallet);

// 자산 주소 확인
const assetAddress = await vault.asset();
const asset = new ethers.Contract(assetAddress, ERC20_ABI, wallet);

// 예치
const amount = ethers.parseUnits("1000", 6); // 1000 USDC
await asset.approve(vault.target, amount);
const tx = await vault.deposit(amount, wallet.address);
await tx.wait();

console.log("Deposited!");
```

### 실시간 APY 계산

```javascript
async function calculateAPY(vaultAddress) {
    const vault = new ethers.Contract(vaultAddress, ERC4626_ABI, provider);

    // 1 share의 가치
    const sharePrice = await vault.convertToAssets(ethers.parseEther("1"));

    // APY 계산 (간단한 방식)
    const apy = ((Number(sharePrice) / 1e18) - 1) * 100;

    console.log(`Current APY: ${apy.toFixed(2)}%`);
    return apy;
}
```

### 최적 볼트 찾기

```javascript
async function findBestVault(vaultAddresses, amount) {
    let bestVault = null;
    let maxShares = 0n;

    for (const address of vaultAddresses) {
        const vault = new ethers.Contract(address, ERC4626_ABI, provider);
        const shares = await vault.previewDeposit(amount);

        if (shares > maxShares) {
            maxShares = shares;
            bestVault = address;
        }
    }

    console.log(`Best vault: ${bestVault}`);
    console.log(`Expected shares: ${ethers.formatEther(maxShares)}`);
    return bestVault;
}
```

### 자동 복리 투자

```javascript
async function autoCompound(vaultAddress) {
    const vault = new ethers.Contract(vaultAddress, ERC4626_ABI, wallet);

    // 현재 보유 공유
    const shares = await vault.balanceOf(wallet.address);

    // 현재 가치
    const assets = await vault.convertToAssets(shares);

    // 이익 계산 (초기 투자 1000 USDC로 가정)
    const initialInvestment = ethers.parseUnits("1000", 6);
    const profit = assets - initialInvestment;

    if (profit > 0) {
        console.log(`Profit: ${ethers.formatUnits(profit, 6)} USDC`);

        // 이익만 재투자
        const assetAddress = await vault.asset();
        const asset = new ethers.Contract(assetAddress, ERC20_ABI, wallet);

        // 인출
        const tx1 = await vault.redeem(shares, wallet.address, wallet.address);
        await tx1.wait();

        // 전액 재예치 (복리)
        await asset.approve(vault.target, assets);
        const tx2 = await vault.deposit(assets, wallet.address);
        await tx2.wait();

        console.log("Compounded!");
    }
}

// 매일 실행
setInterval(() => autoCompound(VAULT_ADDRESS), 24 * 60 * 60 * 1000);
```

---

## 참고 자료

### 공식 문서
- [EIP-4626 Specification](https://eips.ethereum.org/EIPS/eip-4626)
- [OpenZeppelin ERC4626 Implementation](https://docs.openzeppelin.com/contracts/4.x/erc4626)
- [Solmate ERC4626](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC4626.sol)

### 실전 예제
- [contracts/EIP4626Example.sol](./contracts/EIP4626Example.sol) - 기본 구현
- [CHEATSHEET.md](./CHEATSHEET.md) - 빠른 참조

### 외부 자료
- [Yearn V3 Vaults](https://docs.yearn.fi/)
- [EIP-4626 Security Review](https://mixbytes.io/blog/erc-4626-security-review)
- [Inflation Attack Explanation](https://ethereum-magicians.org/t/eip-4626-yield-bearing-vault-standard/7900)

### 추천 도구
- [Tenderly](https://tenderly.co/) - 트랜잭션 시뮬레이션
- [Slither](https://github.com/crytic/slither) - 정적 분석
- [Echidna](https://github.com/crytic/echidna) - Fuzzing 테스트

---

## 요약

**EIP-4626 한 줄 요약:**
> "DeFi 수익 창출 볼트의 표준 인터페이스로, 프로토콜 간 상호 운용성을 제공합니다."

**핵심 포인트:**
1. ✅ **통일성**: 모든 볼트가 동일한 인터페이스 사용
2. ✅ **투명성**: Preview 함수로 결과 미리 확인
3. ✅ **안전성**: 반올림 방향과 보안 패턴 표준화
4. ✅ **확장성**: ERC-20 기반으로 자유로운 거래 가능
5. ✅ **유연성**: Deposit/Mint, Withdraw/Redeem 양방향 지원

**다음 학습:**
- [EIP-5192 (Soulbound Token)](../EIP-5192/README.md)
- [EIP-2612 (Permit)](../../essential/EIP-2612/README.md)
- [EIP-1271 (Signature Validation)](../../essential/EIP-1271/README.md)

---

*최종 업데이트: 2024년*
*작성자: EIP Study Group*
