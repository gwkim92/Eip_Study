# EIP-2612 빠른 시작 가이드 (Quick Start Guide)

## 5분 안에 EIP-2612 이해하기 (Get Started in 5 Minutes)

### 1. 핵심 개념 (Basic Concept)

```
기존 ERC-20                   EIP-2612 Permit
   |                              |
   | 1. approve() 트랜잭션        | 1. 서명 (무료)
   | 2. transferFrom()            | 2. permit + 실행
   v                              v
2번 트랜잭션, 높은 비용        1번 트랜잭션, 저렴
```

**핵심**: Permit = **서명만으로 토큰 승인, 가스비 절감!**

---

## 2. 최소 구현 (Minimal Implementation)

### 기본 ERC20Permit 토큰

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

// 끝! ERC20Permit이 모든 걸 해줍니다 ✅
```

### Permit을 받는 DApp

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAppWithPermit {
    function depositWithPermit(
        IERC20Permit token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 1️⃣ Permit 실행 (승인)
        token.permit(
            msg.sender,      // owner
            address(this),   // spender
            amount,
            deadline,
            v, r, s
        );

        // 2️⃣ 즉시 transferFrom (한 트랜잭션에서)
        IERC20(address(token)).transferFrom(
            msg.sender,
            address(this),
            amount
        );

        // 3️⃣ 비즈니스 로직
        // ... (스테이킹, 스왑 등)
    }
}
```

---

## 3. 사용 방법 (How to Use)

### Frontend (ethers.js v6)

```javascript
import { ethers } from 'ethers';

async function permitAndDeposit() {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const userAddress = await signer.getAddress();

    // 토큰과 DApp 컨트랙트
    const token = new ethers.Contract(tokenAddress, ERC20PermitABI, signer);
    const dapp = new ethers.Contract(dappAddress, DAppABI, signer);

    // 예치할 금액
    const amount = ethers.parseUnits('100', 18);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1시간 후
    const nonce = await token.nonces(userAddress);

    // 1️⃣ Domain
    const domain = {
        name: await token.name(),
        version: '1',
        chainId: (await provider.getNetwork()).chainId,
        verifyingContract: tokenAddress
    };

    // 2️⃣ Types
    const types = {
        Permit: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' }
        ]
    };

    // 3️⃣ Value
    const value = {
        owner: userAddress,
        spender: dappAddress,
        value: amount,
        nonce: nonce,
        deadline: deadline
    };

    // 4️⃣ 서명 생성 (오프체인, 무료!)
    const signature = await signer.signTypedData(domain, types, value);
    const sig = ethers.Signature.from(signature);

    // 5️⃣ Permit + Deposit (한 번에!)
    const tx = await dapp.depositWithPermit(
        tokenAddress,
        amount,
        deadline,
        sig.v,
        sig.r,
        sig.s
    );

    await tx.wait();
    console.log('예치 완료! 🎉');
}
```

---

## 4. 주요 사용 사례 (Key Use Cases)

### A. 가스 없는 스테이킹

```solidity
contract Staking {
    IERC20Permit public immutable stakingToken;

    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        // Permit (승인)
        stakingToken.permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v, r, s
        );

        // 즉시 스테이킹
        stakingToken.transferFrom(msg.sender, address(this), amount);
        _stake(msg.sender, amount);
    }
}
```

### B. 스왑 with Permit

```solidity
contract DEX {
    function swapWithPermit(
        IERC20Permit tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        // Permit
        tokenIn.permit(msg.sender, address(this), amountIn, deadline, v, r, s);

        // Swap
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        uint256 amountOut = _calculateSwap(tokenIn, tokenOut, amountIn);
        require(amountOut >= minAmountOut, "Slippage");

        tokenOut.transfer(msg.sender, amountOut);
    }
}
```

### C. 가스 대납 (Relayer)

```solidity
contract GaslessTransfer {
    function transferWithPermit(
        IERC20Permit token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        // Permit (from이 서명함)
        token.permit(from, address(this), amount, deadline, v, r, s);

        // Relayer가 가스비 지불하고 전송
        token.transferFrom(from, to, amount);

        // 수수료 받기
        _chargeFee(from);
    }
}
```

---

## 5. Permit 함수 인터페이스

```solidity
interface IERC20Permit is IERC20 {
    function permit(
        address owner,       // 토큰 소유자
        address spender,     // 승인받을 주소
        uint256 value,       // 승인 금액
        uint256 deadline,    // 만료 시간
        uint8 v,             // 서명 v
        bytes32 r,           // 서명 r
        bytes32 s            // 서명 s
    ) external;

    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
```

---

## 6. 완전한 예제

### Staking 컨트랙트

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract SimpleStaking {
    IERC20Permit public immutable token;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public rewards;

    constructor(address _token) {
        token = IERC20Permit(_token);
    }

    // 기존 방식: 2번 트랜잭션
    function stake(uint256 amount) external {
        // 사전에 approve() 호출 필요!
        IERC20(address(token)).transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] += amount;
    }

    // Permit 방식: 1번 트랜잭션
    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Permit으로 승인
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        // 즉시 전송
        IERC20(address(token)).transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] += amount;

        // 한 트랜잭션에서 모두 완료! ✅
    }

    function unstake(uint256 amount) external {
        require(stakes[msg.sender] >= amount, "Not enough stakes");
        stakes[msg.sender] -= amount;
        IERC20(address(token)).transfer(msg.sender, amount);
    }
}
```

### Frontend

```javascript
async function stakeWithPermit(amount) {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const userAddress = await signer.getAddress();

    const token = new ethers.Contract(tokenAddress, TokenABI, signer);
    const staking = new ethers.Contract(stakingAddress, StakingABI, signer);

    // 서명 데이터 준비
    const value = ethers.parseUnits(amount, 18);
    const deadline = Math.floor(Date.now() / 1000) + 3600;
    const nonce = await token.nonces(userAddress);

    const domain = {
        name: 'MyToken',
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

    const message = {
        owner: userAddress,
        spender: stakingAddress,
        value: value,
        nonce: nonce,
        deadline: deadline
    };

    // 서명
    const signature = await signer.signTypedData(domain, types, message);
    const sig = ethers.Signature.from(signature);

    // 스테이킹 (1번의 트랜잭션)
    const tx = await staking.stakeWithPermit(
        value,
        deadline,
        sig.v,
        sig.r,
        sig.s
    );

    await tx.wait();
    console.log('스테이킹 완료!');
}
```

---

## 7. 보안 체크리스트

### ✅ 반드시 확인할 것

```solidity
function permitSafe(
    IERC20Permit token,
    address owner,
    uint256 amount,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external {
    // 1. Deadline 확인
    require(block.timestamp <= deadline, "Expired");

    // 2. Try-catch로 permit 실행
    try token.permit(owner, address(this), amount, deadline, v, r, s) {
        // 성공
    } catch {
        // 실패해도 계속 진행 (이미 approve됐을 수 있음)
        // 또는 require로 중단
    }

    // 3. Allowance 확인
    uint256 allowance = IERC20(address(token)).allowance(owner, address(this));
    require(allowance >= amount, "Insufficient allowance");

    // 4. TransferFrom
    IERC20(address(token)).transferFrom(owner, address(this), amount);
}
```

### ❌ 흔한 실수

```solidity
// 1. Deadline 확인 안 함
function badPermit1(...) external {
    token.permit(...);  // ❌ 만료된 서명도 통과
}

// 2. Permit 실패 시 revert
function badPermit2(...) external {
    token.permit(...);  // ❌ 이미 approve됐으면 실패
    // 대신 try-catch 사용!
}

// 3. Nonce 재사용
// 서명을 두 번 사용하려고 시도
// ❌ Nonce가 증가하므로 불가능 (안전!)
```

---

## 8. 테스트

```javascript
describe("Staking with Permit", function () {
    let token, staking, owner, user;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("MyToken");
        token = await Token.deploy();

        const Staking = await ethers.getContractFactory("SimpleStaking");
        staking = await Staking.deploy(await token.getAddress());

        // 사용자에게 토큰 전송
        await token.transfer(user.address, ethers.parseUnits('1000', 18));
    });

    it("Permit으로 스테이킹", async function () {
        const amount = ethers.parseUnits('100', 18);
        const deadline = Math.floor(Date.now() / 1000) + 3600;
        const nonce = await token.nonces(user.address);

        // Domain
        const domain = {
            name: 'MyToken',
            version: '1',
            chainId: (await ethers.provider.getNetwork()).chainId,
            verifyingContract: await token.getAddress()
        };

        // Types
        const types = {
            Permit: [
                { name: 'owner', type: 'address' },
                { name: 'spender', type: 'address' },
                { name: 'value', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ]
        };

        // Value
        const value = {
            owner: user.address,
            spender: await staking.getAddress(),
            value: amount,
            nonce: nonce,
            deadline: deadline
        };

        // 서명
        const signature = await user.signTypedData(domain, types, value);
        const sig = ethers.Signature.from(signature);

        // 스테이킹
        await staking.connect(user).stakeWithPermit(
            amount,
            deadline,
            sig.v,
            sig.r,
            sig.s
        );

        // 검증
        expect(await staking.stakes(user.address)).to.equal(amount);
        expect(await token.balanceOf(await staking.getAddress())).to.equal(amount);
    });
});
```

---

## 9. FAQ

**Q: 모든 ERC-20이 Permit을 지원하나요?**
- 아니요. EIP-2612를 구현한 토큰만 가능합니다.
- USDC, DAI, Uniswap LP 토큰 등이 지원합니다.

**Q: Permit 지원 여부를 어떻게 확인하나요?**
```javascript
async function supportsPermit(tokenAddress) {
    const token = new ethers.Contract(tokenAddress, ['function permit(address,address,uint256,uint256,uint8,bytes32,bytes32)'], provider);
    try {
        await token.permit.staticCall(ethers.ZeroAddress, ethers.ZeroAddress, 0, 0, 0, ethers.ZeroHash, ethers.ZeroHash);
        return false; // revert 안 하면 잘못된 구현
    } catch (error) {
        return error.message.includes('permit'); // permit 함수 존재
    }
}
```

**Q: Permit 실패 시 어떻게 하나요?**
- Try-catch로 감싸고, 실패하면 일반 approve 요청
```solidity
try token.permit(...) {} catch {
    // fallback: approve 요청
}
```

**Q: 가스비는 얼마나 절감되나요?**
- 기존: approve (46K) + transferFrom (50K) = 96K gas
- Permit: permit + transferFrom = 약 60K gas
- **절감: 약 37%**

---

## 10. 다음 단계

1. ✅ `contracts/ERC20Permit.sol` 확인
2. ✅ `contracts/DAppWithPermit.sol` 실행
3. ✅ OpenZeppelin의 `ERC20Permit` 사용
4. ✅ Frontend에서 Permit 구현
5. ✅ 테스트 작성
6. ✅ Uniswap, Aave 등의 실제 구현 분석

---

**마지막 업데이트**: 2025-11-05  
**버전**: 1.0.0

**시작하기**: `contracts/ERC20Permit.sol`로 시작하세요! 🚀

