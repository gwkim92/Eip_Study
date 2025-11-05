# EIP-2612 Cheat Sheet

> **빠른 참조** - EIP-2612 Permit (가스 없는 토큰 승인)

## 🎯 핵심 (5초)

```
approve() 트랜잭션 불필요
→ 서명만으로 토큰 승인
→ 가스비 37% 절감
→ 1번의 트랜잭션으로 완료
```

## 📝 기본 구현

### OpenZeppelin 사용

```solidity
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

### DApp에서 사용

```solidity
contract Staking {
    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        token.transferFrom(msg.sender, address(this), amount);
        _stake(msg.sender, amount);
    }
}
```

## 🌐 Frontend (ethers.js)

```javascript
// 1. Domain & Types
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

// 2. 서명 생성 (무료!)
const value = {
    owner: await signer.getAddress(),
    spender: dappAddress,
    value: ethers.parseUnits('1000', 18),
    nonce: await token.nonces(owner),
    deadline: Math.floor(Date.now() / 1000) + 3600
};

const sig = await signer.signTypedData(domain, types, value);
const { v, r, s } = ethers.Signature.from(sig);

// 3. 실행 (한 번만!)
await dapp.stakeWithPermit(value.value, value.deadline, v, r, s);
```

## ⚠️ 보안 체크리스트

```solidity
// ✅ 즉시 사용
function good(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) {
    token.permit(msg.sender, address(this), amount, deadline, v, r, s);
    token.transferFrom(msg.sender, address(this), amount);  // 즉시!
}

// ✅ Try-catch 사용
try token.permit(...) {} catch {
    require(token.allowance(msg.sender, address(this)) >= amount);
}

// ✅ Deadline 확인
require(block.timestamp <= deadline);
```

## 📊 가스비 비교

```
기존 방식:
  approve: 46,000 gas
  + transferFrom: 50,000 gas
  = 96,000 gas (2 txs)

Permit:
  permit + transferFrom: 60,000 gas (1 tx)

절감: 36,000 gas (37%)
```

## 💡 사용 사례

```
✅ Uniswap LP 토큰
✅ Aave 예치
✅ DEX 스왑
✅ 스테이킹
✅ 가스비 대납
```

## 🔗 링크

- [README.md](./README.md)
- [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612)

---

**핵심:** 서명으로 approve 대체 = 가스 절감 + UX 개선
