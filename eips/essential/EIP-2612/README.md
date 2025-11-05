# EIP-2612: Permit Extension for ERC-20 (가스 없는 토큰 승인)

> **"approve() 트랜잭션 없이 서명만으로 토큰 승인 - 가스비 절감과 UX 개선"**

## 목차
- [개요](#개요)
- [문제와 해결책](#문제와-해결책)
- [핵심 개념](#핵심-개념)
- [구현 방법](#구현-방법)
- [실전 예제](#실전-예제)
- [프론트엔드 통합](#프론트엔드-통합)
- [보안 고려사항](#보안-고려사항)
- [FAQ](#faq)

---

## 개요

### EIP-2612란?

EIP-2612는 **ERC-20 토큰에 permit() 함수를 추가**하여, 사용자가 오프체인 서명만으로 토큰 승인을 할 수 있게 합니다. EIP-712를 활용한 실용적인 표준입니다.

**핵심 기능:**
- `approve()` 트랜잭션 불필요
- 가스비 절감 (서명은 무료)
- 더 나은 UX
- 한 번의 트랜잭션으로 승인 + 전송

### 왜 중요한가?

```
Before EIP-2612 (기존 방식):
┌─────────────────────────────────────────┐
│  Step 1: approve() 트랜잭션              │
│  → 가스비 46,000 gas                    │
│  → 사용자 대기 (블록 확인)               │
├─────────────────────────────────────────┤
│  Step 2: transferFrom() 트랜잭션         │
│  → 가스비 50,000 gas                    │
│  → 또 대기                              │
├─────────────────────────────────────────┤
│  총 비용: ~96,000 gas, 2개 트랜잭션      │
│  ❌ 비싸고 느림!                         │
└─────────────────────────────────────────┘

After EIP-2612 (Permit):
┌─────────────────────────────────────────┐
│  Step 1: 서명 (오프체인)                 │
│  → 가스비 0                             │
│  → 즉시 완료                             │
├─────────────────────────────────────────┤
│  Step 2: permit + transferFrom          │
│  → 가스비 ~60,000 gas                   │
│  → 한 번에 완료                          │
├─────────────────────────────────────────┤
│  총 비용: ~60,000 gas, 1개 트랜잭션      │
│  ✅ 저렴하고 빠름!                       │
└─────────────────────────────────────────┘
```

---

## 문제와 해결책

### 문제: 2단계 승인 프로세스

```solidity
// 기존 ERC-20: 2번의 트랜잭션
// 1단계: 사용자가 DApp에 approve
await token.approve(dappAddress, amount);
// → 가스비 지불, 블록 확인 대기

// 2단계: DApp이 transferFrom
await dapp.doSomething(amount);
// → 또 가스비 지불, 또 대기

// 😫 불편하고 비쌈!
```

**문제점:**
1. **높은 가스비**: 2번의 트랜잭션 = 2배 비용
2. **나쁜 UX**: 두 번 지갑 승인 필요
3. **진입 장벽**: 신규 사용자가 토큰 없으면 시작 불가
4. **시간 소요**: 2개 블록 확인 대기

### 해결책: Permit (서명 기반 승인)

```solidity
// EIP-2612: 1번의 트랜잭션
// 1단계: 서명 생성 (오프체인, 무료)
const signature = await signer.signTypedData(...);

// 2단계: permit + 실제 로직 (한 번에)
await dapp.doSomethingWithPermit(amount, deadline, v, r, s);
// → 1번의 가스비만, 1번의 대기만

// ✅ 간편하고 저렴!
```

---

## 핵심 개념

### 1. permit() 함수

```solidity
function permit(
    address owner,       // 토큰 소유자
    address spender,     // 승인받을 주소
    uint256 value,       // 승인 금액
    uint256 deadline,    // 서명 만료 시간
    uint8 v,            // 서명 파라미터
    bytes32 r,          // 서명 파라미터
    bytes32 s           // 서명 파라미터
) external;
```

**동작 원리:**
```
1. 사용자가 오프체인에서 승인 서명 생성
   ↓
2. 누군가(사용자 or 제3자)가 permit() 호출
   ↓
3. 컨트랙트가 서명 검증
   ↓
4. 검증 성공 시 allowance 설정
   ↓
5. 이제 transferFrom() 가능!
```

### 2. EIP-712 통합

EIP-2612는 EIP-712를 활용합니다:

```solidity
// Permit Type Hash
bytes32 public constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);

// Domain Separator
bytes32 public DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes("TokenName")),
    keccak256(bytes("1")),
    block.chainid,
    address(this)
));
```

### 3. Nonce 관리

재사용 공격 방지를 위한 nonce:

```solidity
mapping(address => uint256) public nonces;

function permit(...) external {
    // ...
    uint256 currentNonce = nonces[owner]++;
    // 서명 검증에 사용
}
```

**Nonce 특징:**
- 사용자별로 독립적
- 순차적으로 증가
- 같은 서명 재사용 불가

---

## 구현 방법

### 방법 1: OpenZeppelin 사용 (권장)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyToken is ERC20, ERC20Permit {
    constructor()
        ERC20("MyToken", "MTK")
        ERC20Permit("MyToken")
    {
        _mint(msg.sender, 1000000 * 10**18);
    }
}
```

**장점:**
- 검증된 구현
- 자동 nonce 관리
- EIP-712 통합
- 가스 최적화

### 방법 2: 직접 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MyTokenWithPermit is ERC20, EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    mapping(address => uint256) public nonces;

    constructor()
        ERC20("MyToken", "MTK")
        EIP712("MyToken", "1")
    {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            nonces[owner]++,
            deadline
        ));

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);

        require(signer == owner, "Invalid signature");

        _approve(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
```

---

## 실전 예제

### 예제 1: DApp에서 Permit 사용

```solidity
contract Staking {
    IERC20Permit public stakingToken;

    constructor(address _token) {
        stakingToken = IERC20Permit(_token);
    }

    /// @notice Permit과 스테이킹을 한 번에
    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 1. Permit 실행
        stakingToken.permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v, r, s
        );

        // 2. 토큰 전송
        stakingToken.transferFrom(msg.sender, address(this), amount);

        // 3. 스테이킹 로직
        _stake(msg.sender, amount);
    }

    function _stake(address user, uint256 amount) internal {
        // 스테이킹 처리
    }
}
```

### 예제 2: DEX 스왑

```solidity
contract DEX {
    function swapWithPermit(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 amountOut) {
        // 1. Permit
        IERC20Permit(tokenIn).permit(
            msg.sender,
            address(this),
            amountIn,
            deadline,
            v, r, s
        );

        // 2. 스왑 실행
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        amountOut = _swap(tokenIn, amountIn, tokenOut);

        require(amountOut >= minAmountOut, "Slippage");
        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }

    function _swap(address tokenIn, uint256 amountIn, address tokenOut)
        internal
        returns (uint256)
    {
        // 스왑 로직
    }
}
```

### 예제 3: 가스 대납 (Relayer)

```solidity
contract GaslessTransfer {
    /// @notice 제3자가 가스비를 대납
    function transferWithPermit(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        // 1. Permit (사용자의 서명 사용)
        IERC20Permit(token).permit(
            from,
            address(this),
            amount,
            deadline,
            v, r, s
        );

        // 2. 전송 (relayer가 가스비 지불)
        IERC20(token).transferFrom(from, to, amount);

        // 3. Relayer 보상 (선택적)
        uint256 fee = amount * 1 / 100; // 1% 수수료
        IERC20(token).transferFrom(from, msg.sender, fee);
    }
}
```

### 예제 4: Multicall

```solidity
contract Router {
    function multiActionWithPermit(
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s,
        bytes[] calldata actions
    ) external {
        // 1. Permit
        IERC20Permit(token).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v, r, s
        );

        // 2. 여러 작업 실행
        for (uint i = 0; i < actions.length; i++) {
            (bool success,) = address(this).delegatecall(actions[i]);
            require(success, "Action failed");
        }
    }

    // 예: 스왑 → 스테이킹 → LP 추가 등
}
```

---

## 프론트엔드 통합

### ethers.js v6

```javascript
import { ethers } from 'ethers';

// 1. 토큰 컨트랙트 연결
const token = new ethers.Contract(tokenAddress, ERC20PermitABI, signer);

// 2. Permit 파라미터 준비
const owner = await signer.getAddress();
const spender = dappAddress;
const value = ethers.parseUnits('1000', 18);
const nonce = await token.nonces(owner);
const deadline = Math.floor(Date.now() / 1000) + 3600; // 1시간 후

// 3. Domain & Types
const domain = {
    name: await token.name(),
    version: '1',
    chainId: (await provider.getNetwork()).chainId,
    verifyingContract: tokenAddress
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

const permitValue = {
    owner,
    spender,
    value,
    nonce,
    deadline
};

// 4. 서명 생성 (가스비 없음!)
const signature = await signer.signTypedData(domain, types, permitValue);
const { v, r, s } = ethers.Signature.from(signature);

// 5. DApp 함수 호출 (한 번의 트랜잭션!)
const tx = await dapp.stakeWithPermit(value, deadline, v, r, s);
await tx.wait();

console.log('Staked without approve transaction!');
```

### React Hook 예제

```javascript
import { useState } from 'react';
import { useWallet } from './useWallet';

export function usePermit(tokenAddress) {
    const { signer, provider } = useWallet();
    const [loading, setLoading] = useState(false);

    const createPermit = async (spender, amount) => {
        setLoading(true);
        try {
            const token = new ethers.Contract(
                tokenAddress,
                ERC20PermitABI,
                signer
            );

            const owner = await signer.getAddress();
            const value = ethers.parseUnits(amount, 18);
            const nonce = await token.nonces(owner);
            const deadline = Math.floor(Date.now() / 1000) + 3600;

            const domain = {
                name: await token.name(),
                version: '1',
                chainId: (await provider.getNetwork()).chainId,
                verifyingContract: tokenAddress
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

            const permitValue = { owner, spender, value, nonce, deadline };
            const signature = await signer.signTypedData(domain, types, permitValue);
            const { v, r, s } = ethers.Signature.from(signature);

            return { value, deadline, v, r, s };
        } finally {
            setLoading(false);
        }
    };

    return { createPermit, loading };
}

// 사용 예
function StakingComponent() {
    const { createPermit } = usePermit(tokenAddress);

    const handleStake = async () => {
        const { value, deadline, v, r, s } = await createPermit(
            stakingAddress,
            '1000'
        );

        await stakingContract.stakeWithPermit(value, deadline, v, r, s);
    };

    return <button onClick={handleStake}>Stake</button>;
}
```

---

## 보안 고려사항

### 1. Front-running 방지

```solidity
// ❌ 취약한 패턴
function badPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    external
{
    token.permit(msg.sender, address(this), amount, deadline, v, r, s);
    // 공격자가 이 서명을 가로채서 먼저 사용 가능!
}

// ✅ 안전한 패턴: 즉시 사용
function goodPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    external
{
    token.permit(msg.sender, address(this), amount, deadline, v, r, s);
    token.transferFrom(msg.sender, address(this), amount);
    // 즉시 전송하므로 front-running 의미 없음
}
```

### 2. Try-Catch로 에러 처리

```solidity
// 권장: permit 실패 시 대비
function robustPermit(
    uint256 amount,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external {
    try token.permit(msg.sender, address(this), amount, deadline, v, r, s) {
        // Permit 성공
    } catch {
        // 이미 approve되었거나, permit가 이미 사용됨
        uint256 currentAllowance = token.allowance(msg.sender, address(this));
        require(currentAllowance >= amount, "Insufficient allowance");
    }

    token.transferFrom(msg.sender, address(this), amount);
}
```

### 3. Deadline 검증

```solidity
// 항상 deadline 확인
require(block.timestamp <= deadline, "Permit expired");

// Frontend에서도 확인
if (Date.now() / 1000 > deadline) {
    throw new Error('Signature expired');
}
```

### 4. 서명 재사용 방지

Nonce가 자동으로 증가하므로 재사용 불가능하지만, 추가 확인:

```solidity
// permit() 내부에서 nonce 증가 확인
nonces[owner]++;  // 반드시 실행되어야 함
```

---

## FAQ

### Q1: 모든 ERC-20이 permit을 지원하나?

**A:** 아니요, EIP-2612를 구현한 토큰만 지원합니다.

```javascript
// Permit 지원 확인
try {
    await token.DOMAIN_SEPARATOR();
    await token.nonces(address);
    // ✅ Permit 지원
} catch {
    // ❌ Permit 미지원, 기존 approve 사용
}
```

### Q2: Permit과 approve를 같이 사용할 수 있나?

**A:** 네, 완전히 호환됩니다.

```solidity
// 방법 1: Permit
token.permit(...);

// 방법 2: Approve (기존)
token.approve(spender, amount);

// 둘 다 allowance를 설정하므로 같은 효과
```

### Q3: 가스비가 얼마나 절감되나?

**A:**
```
기존: approve (46k) + transferFrom (50k) = 96k gas
Permit: permit+transferFrom (60k) = 60k gas

절감: ~36k gas (약 37%)
+ 트랜잭션 1회 감소
```

### Q4: Permit 서명을 누가 제출하나?

**A:** 누구든지 가능합니다!

```javascript
// 1. 사용자가 직접 제출
await dapp.stakeWithPermit(amount, deadline, v, r, s);

// 2. Relayer가 대신 제출 (가스 대납)
await relayer.executePermit(user, amount, deadline, v, r, s);

// 3. Backend가 일괄 처리
await backend.batchPermit([permit1, permit2, ...]);
```

---

## 참고 자료

### 공식 문서
- [EIP-2612 Specification](https://eips.ethereum.org/EIPS/eip-2612)
- [EIP-712 Specification](https://eips.ethereum.org/EIPS/eip-712)

### 실전 예제
- [contracts/ERC20Permit.sol](./contracts/ERC20Permit.sol)
- [contracts/DAppWithPermit.sol](./contracts/DAppWithPermit.sol)
- [CHEATSHEET.md](./CHEATSHEET.md)

### 라이브러리
- [OpenZeppelin ERC20Permit](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Permit)

### 실제 사용
- Uniswap V2/V3 LP 토큰
- Aave aTokens
- Compound cTokens
- USDC (Circle)

---

## 요약

**EIP-2612 한 줄 요약:**
> "서명만으로 토큰 승인 - approve() 트랜잭션 불필요, 가스비 절감"

**핵심 포인트:**
1. ✅ **가스 절감**: 2번 → 1번 트랜잭션
2. ✅ **UX 개선**: 즉시 승인 가능
3. ✅ **EIP-712 활용**: 안전한 서명
4. ✅ **Meta-tx 가능**: 가스비 대납

**다음 학습:**
- [EIP-1271 (Contract Signatures)](../EIP-1271/README.md)
- [EIP-1967 (Proxy Storage)](../EIP-1967/README.md)

---

*최종 업데이트: 2024년*
*작성자: EIP Study Group*
