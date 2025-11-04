# EIP-2612 - Permit (ERC-20 Gasless Approval)

## 목적
사용자가 `approve()` 트랜잭션 없이 토큰 사용 승인을 할 수 있게 함

## 문제 상황 (EIP-2612 이전)

```solidity
// 기존 방식: 2번의 트랜잭션 필요
// 1단계: 사용자가 approve 트랜잭션 전송 (가스비 지불)
token.approve(spender, amount);

// 2단계: 실제 사용 (또 가스비 지불)
dapp.useTokens(amount);
```

**문제점**:
- 2번의 트랜잭션 = 2배의 가스비
- 사용자 UX 나쁨
- 신규 사용자 진입장벽

## 해결책 (EIP-2612)

```solidity
// IERC20Permit 인터페이스
interface IERC20Permit {
    function permit(
        address owner,      // 토큰 소유자
        address spender,    // 승인받을 주소
        uint256 value,      // 승인 금액
        uint256 deadline,   // 서명 만료 시간
        uint8 v,           // 서명 v
        bytes32 r,         // 서명 r
        bytes32 s          // 서명 s
    ) external;

    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
```

## 완전한 구현 예제

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

// DApp 컨트랙트에서 사용
contract MyDApp {
    IERC20Permit public token;

    function depositWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        // permit 호출로 승인 + 전송을 한 번에!
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        token.transferFrom(msg.sender, address(this), amount);

        // 실제 로직 수행...
    }
}
```

## 프론트엔드 통합

```javascript
// 1. 서명 생성 (가스비 없음!)
const nonce = await token.nonces(userAddress);
const deadline = Math.floor(Date.now() / 1000) + 3600; // 1시간 후

const domain = {
    name: await token.name(),
    version: '1',
    chainId: (await provider.getNetwork()).chainId,
    verifyingContract: token.address
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

const value = {
    owner: userAddress,
    spender: dappAddress,
    value: amount,
    nonce: nonce,
    deadline: deadline
};

const signature = await signer.signTypedData(domain, types, value);
const { v, r, s } = ethers.Signature.from(signature);

// 2. depositWithPermit 호출 (한 번의 트랜잭션!)
await dapp.depositWithPermit(amount, deadline, v, r, s);
```

## 실전 활용 패턴

### 패턴 1: Multicall과 함께 사용
```solidity
contract Router {
    function swapWithPermit(
        address tokenIn,
        uint256 amountIn,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
        // swap 파라미터들...
    ) external {
        IERC20Permit(tokenIn).permit(
            msg.sender, address(this), amountIn, deadline, v, r, s
        );

        // 스왑 실행
        _swap(tokenIn, amountIn, ...);
    }
}
```

### 패턴 2: 가스비 대납 (Meta-Transaction)
```solidity
contract Relayer {
    function executeWithPermit(
        address user,
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s,
        bytes calldata data
    ) external {
        // 사용자 대신 permit 실행
        token.permit(user, address(this), amount, deadline, v, r, s);

        // 로직 실행 (relayer가 가스비 지불)
        _execute(user, amount, data);
    }
}
```

## 보안 고려사항

```solidity
// 잘못된 사용 - Front-running 위험
function badPermit(
    uint256 amount,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external {
    token.permit(msg.sender, address(this), amount, deadline, v, r, s);
    // 공격자가 이 서명을 가로채서 먼저 사용 가능!
}

// 올바른 사용 - 즉시 사용
function goodPermit(
    uint256 amount,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external {
    token.permit(msg.sender, address(this), amount, deadline, v, r, s);
    token.transferFrom(msg.sender, address(this), amount);
    // 즉시 토큰을 전송하므로 안전
}

// 더 나은 방법 - try/catch로 이미 사용된 permit 처리
function robustPermit(
    uint256 amount,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external {
    try token.permit(msg.sender, address(this), amount, deadline, v, r, s) {
        // permit 성공
    } catch {
        // 이미 approve되어 있거나 permit가 이미 사용됨
        // allowance 확인
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );
    }

    token.transferFrom(msg.sender, address(this), amount);
}
```

## 가스비 비교

```
기존 방식 (approve + transferFrom):
- approve(): ~46,000 gas
- transferFrom(): ~50,000 gas
- 총합: ~96,000 gas (2번의 트랜잭션)

Permit 방식:
- permit + transferFrom: ~60,000 gas (1번의 트랜잭션)
- 서명 생성: 가스비 없음 (오프체인)

절약: ~36,000 gas + 트랜잭션 1회 감소
```

## 주요 DApp 활용 사례

- **Uniswap V2/V3**: 모든 LP 토큰이 permit 지원
- **Aave**: 예치 시 permit 사용
- **Compound**: cToken에 permit 적용
- **1inch**: 스왑 시 permit 통합

## 샘플 컨트랙트
- [ERC20Permit.sol](./contracts/ERC20Permit.sol) - 기본 구현
- [DAppWithPermit.sol](./contracts/DAppWithPermit.sol) - DApp 통합 예제

## 참고 자료
- [EIP-2612 Specification](https://eips.ethereum.org/EIPS/eip-2612)
- [OpenZeppelin ERC20Permit](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Permit)
