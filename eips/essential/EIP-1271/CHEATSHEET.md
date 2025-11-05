# EIP-1271 Cheat Sheet

> **빠른 참조** - 스마트 컨트랙트 서명 검증

## 🎯 핵심 (5초)

```
ecrecover() → EOA만 가능
EIP-1271 → 컨트랙트도 서명 검증 가능!

→ Gnosis Safe, Account Abstraction 등
```

## 📝 인터페이스

```solidity
interface IERC1271 {
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue);
}

// Magic Value
bytes4 constant MAGIC = 0x1626ba7e;  // 성공
bytes4 constant FAIL = 0xffffffff;   // 실패
```

## 💻 기본 구현 (단일 소유자)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1271.sol";

contract SimpleWallet is IERC1271 {
    address public owner;
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    constructor() {
        owner = msg.sender;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        require(signature.length == 65, "Invalid length");

        // 서명 분해
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) v += 27;

        // 검증
        address signer = ecrecover(hash, v, r, s);

        return (signer != address(0) && signer == owner)
            ? MAGICVALUE
            : bytes4(0xffffffff);
    }
}
```

## 🔐 멀티시그 구현

```solidity
contract MultiSigWallet is IERC1271 {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    function isValidSignature(
        bytes32 hash,
        bytes memory signatures
    ) external view override returns (bytes4) {
        uint256 signatureCount = signatures.length / 65;
        require(signatureCount >= threshold, "Not enough");

        address[] memory signers = new address[](signatureCount);

        for (uint256 i = 0; i < signatureCount; i++) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            uint256 offset = i * 65;
            assembly {
                r := mload(add(signatures, add(offset, 32)))
                s := mload(add(signatures, add(offset, 64)))
                v := byte(0, mload(add(signatures, add(offset, 96))))
            }

            if (v < 27) v += 27;

            address signer = ecrecover(hash, v, r, s);
            require(signer != address(0) && isOwner[signer]);

            // 중복 체크
            for (uint256 j = 0; j < i; j++) {
                require(signers[j] != signer, "Duplicate");
            }

            signers[i] = signer;
        }

        return MAGICVALUE;
    }
}
```

## 🌐 Frontend: EOA + Contract 통합

```javascript
import { ethers } from 'ethers';

// 1. 컨트랙트 여부 확인
async function isContract(address, provider) {
    const code = await provider.getCode(address);
    return code !== '0x';
}

// 2. 통합 검증 함수
async function verifySignature(
    signerAddress,
    hash,
    signature,
    provider
) {
    if (await isContract(signerAddress, provider)) {
        // Contract: EIP-1271
        const wallet = new ethers.Contract(
            signerAddress,
            ['function isValidSignature(bytes32,bytes) view returns (bytes4)'],
            provider
        );

        try {
            const result = await wallet.isValidSignature(hash, signature);
            return result === '0x1626ba7e';
        } catch {
            return false;
        }
    } else {
        // EOA: ecrecover
        const recoveredAddress = ethers.recoverAddress(hash, signature);
        return recoveredAddress.toLowerCase() === signerAddress.toLowerCase();
    }
}

// 3. EIP-712 + EIP-1271
async function signAndVerify(wallet, message) {
    const domain = {
        name: 'MyDApp',
        version: '1',
        chainId: (await wallet.provider.getNetwork()).chainId,
        verifyingContract: contractAddress
    };

    const types = {
        Order: [
            { name: 'maker', type: 'address' },
            { name: 'price', type: 'uint256' }
        ]
    };

    // EIP-712 서명
    const signature = await wallet.signTypedData(domain, types, message);

    // EIP-712 해시
    const hash = ethers.TypedDataEncoder.hash(domain, types, message);

    // EIP-1271 검증
    const isValid = await verifySignature(
        await wallet.getAddress(),
        hash,
        signature,
        wallet.provider
    );

    return { signature, isValid };
}
```

## 🔗 EIP-712 통합

```solidity
contract Wallet is IERC1271 {
    address public owner;
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    // EIP-712 Domain
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor() {
        owner = msg.sender;

        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes("MyWallet")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        require(signature.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) v += 27;

        address signer = ecrecover(hash, v, r, s);

        return (signer == owner) ? MAGICVALUE : bytes4(0xffffffff);
    }
}
```

## 💡 세션 키 패턴

```solidity
contract SessionKeyWallet is IERC1271 {
    address public owner;
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    struct SessionKey {
        bool isActive;
        uint256 expiresAt;
        uint256 spendLimit;
        uint256 spent;
    }

    mapping(address => SessionKey) public sessionKeys;

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        // 서명 분해 로직...
        address signer = recoverSigner(hash, signature);

        // 소유자 확인
        if (signer == owner) {
            return MAGICVALUE;
        }

        // 세션 키 확인
        SessionKey storage session = sessionKeys[signer];
        if (session.isActive &&
            session.expiresAt > block.timestamp &&
            session.spent < session.spendLimit)
        {
            return MAGICVALUE;
        }

        return bytes4(0xffffffff);
    }

    // 세션 키 추가
    function addSessionKey(
        address key,
        uint256 duration,
        uint256 spendLimit
    ) external {
        require(msg.sender == owner);

        sessionKeys[key] = SessionKey({
            isActive: true,
            expiresAt: block.timestamp + duration,
            spendLimit: spendLimit,
            spent: 0
        });
    }
}
```

## ⚠️ 보안 체크리스트

```solidity
// ✅ 1. View Function 사용
function isValidSignature(bytes32, bytes memory)
    external view returns (bytes4)  // 반드시 view!
{
    // 상태 변경 금지
}

// ✅ 2. Zero Address 체크
address signer = ecrecover(hash, v, r, s);
require(signer != address(0), "Invalid");

// ✅ 3. Signature Malleability 방지
require(
    uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
    "Invalid s"
);

// ✅ 4. Nonce 사용 (재사용 방지)
struct Message {
    uint256 nonce;
    uint256 chainId;
    uint256 deadline;
    // ...
}

// ✅ 5. Try-Catch 사용
try IERC1271(account).isValidSignature(hash, sig)
    returns (bytes4 magicValue)
{
    return magicValue == 0x1626ba7e;
} catch {
    return false;
}

// ✅ 6. EIP-712 Domain Separation
bytes32 DOMAIN_SEPARATOR = keccak256(abi.encode(
    DOMAIN_TYPEHASH,
    keccak256(bytes("AppName")),
    keccak256(bytes("1")),
    block.chainid,
    address(this)
));
```

## 📊 실전 패턴

### DApp 통합

```solidity
contract DApp {
    function validateSignature(
        address account,
        bytes32 hash,
        bytes memory signature
    ) public view returns (bool) {
        // 1. 컨트랙트 확인
        if (account.code.length > 0) {
            // EIP-1271
            try IERC1271(account).isValidSignature(hash, signature)
                returns (bytes4 magicValue)
            {
                return magicValue == 0x1626ba7e;
            } catch {
                return false;
            }
        } else {
            // EOA
            (uint8 v, bytes32 r, bytes32 s) = splitSig(signature);
            return ecrecover(hash, v, r, s) == account;
        }
    }
}
```

### OpenZeppelin 사용

```solidity
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MyWallet is IERC1271 {
    using ECDSA for bytes32;

    address public owner;

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        address signer = hash.recover(signature);
        return (signer == owner) ? 0x1626ba7e : 0xffffffff;
    }
}
```

## 📈 Gas 비용

```
단일 소유자:     ~30,000 gas
멀티시그 2-of-3: ~80,000 gas
멀티시그 3-of-5: ~120,000 gas

✅ view function: 조회 무료
✅ 실행 시에만 가스 발생
```

## 🎓 사용 사례

```
✅ Gnosis Safe      - 멀티시그 지갑
✅ Account Abstraction - EIP-4337
✅ Argent Wallet    - 소셜 복구
✅ OpenSea          - NFT 마켓플레이스
✅ Uniswap Permit2  - 통합 승인
✅ DAO 투표         - 조직 서명
✅ 메타 트랜잭션    - 가스리스
```

## 🔑 핵심 상수

```solidity
// Magic Value (성공)
bytes4(keccak256("isValidSignature(bytes32,bytes)"))
= 0x1626ba7e

// 실패 값
bytes4(0xffffffff)

// ECDSA s 값 최대값 (malleability 방지)
0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
```

## 💬 자주하는 실수

### ❌ 실수 1: view 누락

```solidity
// ❌ 틀림
function isValidSignature(bytes32, bytes memory)
    external returns (bytes4)  // view 없음!

// ✅ 맞음
function isValidSignature(bytes32, bytes memory)
    external view returns (bytes4)  // view!
```

### ❌ 실수 2: Zero Address 체크 누락

```solidity
// ❌ 틀림
address signer = ecrecover(hash, v, r, s);
return (signer == owner) ? MAGICVALUE : 0xffffffff;

// ✅ 맞음
address signer = ecrecover(hash, v, r, s);
require(signer != address(0));  // 필수!
return (signer == owner) ? MAGICVALUE : 0xffffffff;
```

### ❌ 실수 3: Try-Catch 누락

```solidity
// ❌ 틀림: 실패 시 revert
bytes4 result = IERC1271(account).isValidSignature(hash, sig);

// ✅ 맞음: try-catch로 안전하게
try IERC1271(account).isValidSignature(hash, sig)
    returns (bytes4 result)
{
    return result == 0x1626ba7e;
} catch {
    return false;
}
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 가이드
- [EIP-1271 Spec](https://eips.ethereum.org/EIPS/eip-1271)
- [EIP-712 (Typed Data)](../EIP-712/README.md)
- [Gnosis Safe](https://github.com/safe-global/safe-contracts)

---

**핵심 요약:**
```
isValidSignature(hash, signature) → 0x1626ba7e (성공)
                                  → 0xffffffff (실패)

→ 컨트랙트가 서명을 검증할 수 있게 해주는 표준
→ EOA + Contract 모두 지원
→ Gnosis Safe, Account Abstraction 등에 필수
```

**마지막 업데이트: 2025**
