# EIP-1271: Smart Contract Signature Validation

> **스마트 컨트랙트를 위한 서명 검증 표준**

## 📋 목차

- [개요](#개요)
- [문제점](#문제점)
- [해결책](#해결책)
- [핵심 개념](#핵심-개념)
- [구현 방법](#구현-방법)
- [실전 예제](#실전-예제)
- [프론트엔드 통합](#프론트엔드-통합)
- [보안 고려사항](#보안-고려사항)
- [실제 사용 사례](#실제-사용-사례)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

**EIP-1271**은 스마트 컨트랙트가 서명을 검증할 수 있도록 하는 표준 인터페이스입니다.

### 🎯 핵심 목적

```
EOA (개인 지갑)      → ecrecover()로 서명 검증 ✅
Contract (컨트랙트) → ❌ 개인키가 없음!
                     → ✅ EIP-1271로 해결!
```

### ⚡ 5초 요약

```solidity
function isValidSignature(bytes32 hash, bytes memory signature)
    external view returns (bytes4 magicValue);

// 반환값: 0x1626ba7e = 성공
//        그 외 = 실패
```

---

## 문제점

### EOA의 한계

**Externally Owned Account (EOA)**는 개인키로 직접 서명할 수 있습니다:

```solidity
// EOA 서명 검증
address signer = ecrecover(hash, v, r, s);
require(signer == expectedAddress, "Invalid signature");
```

**하지만 스마트 컨트랙트는?**

### 컨트랙트가 서명할 수 없는 이유

```
❌ 문제 1: 개인키가 없음
   컨트랙트는 코드로만 존재, 개인키 없음

❌ 문제 2: 멀티시그 지갑
   Gnosis Safe 같은 지갑은 여러 서명 필요

❌ 문제 3: Account Abstraction
   EIP-4337 같은 고급 지갑 로직

❌ 문제 4: DAO/조직
   조직 차원의 서명 로직 필요
```

### 실제 시나리오

**OpenSea에서 NFT 판매하기:**

```
1. 사용자: Gnosis Safe 멀티시그 지갑 사용
2. OpenSea: "이 NFT 판매 주문에 서명해주세요"
3. 문제: Gnosis Safe는 개인키가 없음!
4. 해결: EIP-1271로 멀티시그 로직으로 검증
```

---

## 해결책

### EIP-1271 인터페이스

```solidity
interface IERC1271 {
    /**
     * @param hash 서명할 데이터의 해시
     * @param signature 서명 데이터
     * @return magicValue 성공: 0x1626ba7e, 실패: 다른 값
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue);
}
```

### Magic Value란?

```solidity
// 성공 시 반환값
bytes4 constant MAGICVALUE = 0x1626ba7e;

// 계산 방법
MAGICVALUE = bytes4(keccak256("isValidSignature(bytes32,bytes)"));

// 실패 시
return 0xffffffff; // 또는 다른 값
```

### 작동 원리

```
┌─────────────────────────────────────────────┐
│  1. DApp (OpenSea, Uniswap 등)              │
│     "이 주문에 서명이 유효한가요?"           │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  2. isValidSignature(hash, signature) 호출  │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  3. 컨트랙트 내부 검증 로직                 │
│     - 단일 소유자?                          │
│     - 멀티시그?                             │
│     - 세션 키?                              │
│     - DAO 투표?                             │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  4. 반환: 0x1626ba7e (성공) or 실패         │
└─────────────────────────────────────────────┘
```

---

## 핵심 개념

### 1. Magic Value

**왜 0x1626ba7e인가?**

```solidity
// 함수 시그니처의 해시 처음 4바이트
keccak256("isValidSignature(bytes32,bytes)")
= 0x1626ba7e...

// EIP 표준: 함수 이름으로 고유값 생성
bytes4(keccak256("functionName(types)"))
```

### 2. View Function

**중요: 상태를 변경하면 안 됩니다!**

```solidity
// ✅ 올바른 예
function isValidSignature(bytes32 hash, bytes memory signature)
    external view returns (bytes4)  // view!
{
    // 읽기만 가능
    address signer = ecrecover(hash, v, r, s);
    return (signer == owner) ? MAGICVALUE : 0xffffffff;
}

// ❌ 잘못된 예
function isValidSignature(bytes32 hash, bytes memory signature)
    external returns (bytes4)  // view 아님!
{
    nonce++;  // ❌ 상태 변경!
    // ...
}
```

**이유:**
- 서명 검증은 조회용
- 가스비 없이 호출 가능
- 다른 컨트랙트에서 안전하게 호출

### 3. EOA vs Contract 통합 패턴

```solidity
function verifySignature(
    address account,
    bytes32 hash,
    bytes memory signature
) public view returns (bool) {
    // 컨트랙트인지 확인
    if (account.code.length > 0) {
        // 컨트랙트: EIP-1271 사용
        try IERC1271(account).isValidSignature(hash, signature)
            returns (bytes4 magicValue)
        {
            return magicValue == 0x1626ba7e;
        } catch {
            return false;
        }
    } else {
        // EOA: ecrecover 사용
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        return ecrecover(hash, v, r, s) == account;
    }
}
```

### 4. EIP-712와의 결합

**구조화된 데이터 서명:**

```solidity
// EIP-712로 해시 생성
bytes32 structHash = keccak256(abi.encode(
    TYPE_HASH,
    order.maker,
    order.taker,
    order.price
));

bytes32 digest = keccak256(abi.encodePacked(
    "\x19\x01",
    DOMAIN_SEPARATOR,
    structHash
));

// EIP-1271로 검증
bytes4 result = IERC1271(wallet).isValidSignature(digest, signature);
require(result == 0x1626ba7e, "Invalid signature");
```

---

## 구현 방법

### 패턴 1: 단일 소유자 지갑

**가장 기본적인 구현:**

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

        // ecrecover로 서명자 복구
        address signer = ecrecover(hash, v, r, s);

        // 소유자인지 확인
        return (signer != address(0) && signer == owner)
            ? MAGICVALUE
            : bytes4(0xffffffff);
    }
}
```

### 패턴 2: 멀티시그 지갑 (Gnosis Safe 스타일)

**여러 소유자, threshold 시스템:**

```solidity
contract MultiSigWallet is IERC1271 {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;  // 필요한 서명 개수

    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_threshold > 0 && _threshold <= _owners.length);

        for (uint256 i = 0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]], "Duplicate");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }

        threshold = _threshold;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signatures
    ) external view override returns (bytes4) {
        // 서명 개수 확인 (각 65바이트)
        require(signatures.length % 65 == 0, "Invalid length");
        uint256 signatureCount = signatures.length / 65;

        require(signatureCount >= threshold, "Not enough sigs");

        address[] memory signers = new address[](signatureCount);

        // 각 서명 검증
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

            require(signer != address(0), "Invalid sig");
            require(isOwner[signer], "Not owner");

            // 중복 확인
            for (uint256 j = 0; j < i; j++) {
                require(signers[j] != signer, "Duplicate sig");
            }

            signers[i] = signer;
        }

        return MAGICVALUE;
    }
}
```

### 패턴 3: 세션 키 지갑

**임시 권한 부여 (게임, DApp 자동화):**

```solidity
contract SessionKeyWallet is IERC1271 {
    address public owner;
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    struct SessionKey {
        bool isActive;
        uint256 expiresAt;
        uint256 spendLimit;
        uint256 spent;
        address[] allowedTargets;
    }

    mapping(address => SessionKey) public sessionKeys;

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

        // 1. 소유자 확인
        if (signer == owner) {
            return MAGICVALUE;
        }

        // 2. 세션 키 확인
        SessionKey storage session = sessionKeys[signer];
        if (session.isActive &&
            session.expiresAt > block.timestamp &&
            session.spent < session.spendLimit)
        {
            return MAGICVALUE;
        }

        return bytes4(0xffffffff);
    }

    // 세션 키 추가 (소유자만)
    function addSessionKey(
        address key,
        uint256 duration,
        uint256 spendLimit,
        address[] memory allowedTargets
    ) external {
        require(msg.sender == owner);

        sessionKeys[key] = SessionKey({
            isActive: true,
            expiresAt: block.timestamp + duration,
            spendLimit: spendLimit,
            spent: 0,
            allowedTargets: allowedTargets
        });
    }
}
```

### 패턴 4: OpenZeppelin 활용

```solidity
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MyWallet is IERC1271 {
    using ECDSA for bytes32;

    address public owner;
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        // OpenZeppelin ECDSA 라이브러리 사용
        address signer = hash.recover(signature);

        return (signer == owner) ? MAGICVALUE : bytes4(0xffffffff);
    }
}
```

---

## 실전 예제

### 예제 1: OpenSea NFT 주문 검증

```solidity
contract NFTMarketplace {
    struct Order {
        address maker;      // 판매자
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 deadline;
    }

    function validateOrder(
        Order memory order,
        bytes memory signature
    ) public view returns (bool) {
        // EIP-712 해시 생성
        bytes32 orderHash = keccak256(abi.encode(
            keccak256("Order(address maker,address nftContract,uint256 tokenId,uint256 price,uint256 deadline)"),
            order.maker,
            order.nftContract,
            order.tokenId,
            order.price,
            order.deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            orderHash
        ));

        // EOA vs Contract 구분
        if (order.maker.code.length > 0) {
            // 컨트랙트: EIP-1271
            try IERC1271(order.maker).isValidSignature(digest, signature)
                returns (bytes4 magicValue)
            {
                return magicValue == 0x1626ba7e;
            } catch {
                return false;
            }
        } else {
            // EOA: ecrecover
            (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
            return ecrecover(digest, v, r, s) == order.maker;
        }
    }

    function splitSignature(bytes memory sig)
        internal pure returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(sig.length == 65);
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
```

### 예제 2: 메타 트랜잭션 (가스리스)

```solidity
contract MetaTransactionExecutor {
    struct MetaTx {
        address from;
        address to;
        uint256 value;
        bytes data;
        uint256 nonce;
    }

    mapping(address => uint256) public nonces;

    function executeMetaTx(
        MetaTx memory metaTx,
        bytes memory signature
    ) external returns (bytes memory) {
        require(metaTx.nonce == nonces[metaTx.from], "Invalid nonce");

        // 메타 트랜잭션 해시
        bytes32 metaTxHash = keccak256(abi.encode(
            keccak256("MetaTx(address from,address to,uint256 value,bytes data,uint256 nonce)"),
            metaTx.from,
            metaTx.to,
            metaTx.value,
            keccak256(metaTx.data),
            metaTx.nonce
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            metaTxHash
        ));

        // EIP-1271로 검증
        require(
            verifySignature(metaTx.from, digest, signature),
            "Invalid signature"
        );

        nonces[metaTx.from]++;

        // 트랜잭션 실행 (msg.sender가 가스 지불)
        (bool success, bytes memory result) = metaTx.to.call{value: metaTx.value}(metaTx.data);
        require(success, "Execution failed");

        return result;
    }

    function verifySignature(
        address account,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        if (account.code.length > 0) {
            try IERC1271(account).isValidSignature(hash, signature)
                returns (bytes4 magicValue)
            {
                return magicValue == 0x1626ba7e;
            } catch {
                return false;
            }
        } else {
            (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
            return ecrecover(hash, v, r, s) == account;
        }
    }
}
```

### 예제 3: DAO 투표

```solidity
contract DAOVoting is IERC1271 {
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public members;
    uint256 public memberCount;
    uint256 public votingThreshold;  // 필요한 찬성 비율

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        // 서명 개수 확인
        uint256 signatureCount = signature.length / 65;

        // 임계값 확인
        if (signatureCount * 100 < memberCount * votingThreshold) {
            return bytes4(0xffffffff);
        }

        address[] memory signers = new address[](signatureCount);

        for (uint256 i = 0; i < signatureCount; i++) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            uint256 offset = i * 65;
            assembly {
                r := mload(add(signature, add(offset, 32)))
                s := mload(add(signature, add(offset, 64)))
                v := byte(0, mload(add(signature, add(offset, 96))))
            }

            if (v < 27) v += 27;
            address signer = ecrecover(hash, v, r, s);

            // 멤버인지 확인
            require(members[signer], "Not member");

            // 중복 확인
            for (uint256 j = 0; j < i; j++) {
                require(signers[j] != signer, "Duplicate");
            }

            signers[i] = signer;
        }

        return MAGICVALUE;
    }
}
```

---

## 프론트엔드 통합

### ethers.js v6 예제

```javascript
import { ethers } from 'ethers';

// 1. 컨트랙트 주소가 EOA인지 Contract인지 확인
async function isContract(address, provider) {
    const code = await provider.getCode(address);
    return code !== '0x';
}

// 2. 서명 생성 (EIP-712)
async function createSignature(wallet, message) {
    const domain = {
        name: 'MyDApp',
        version: '1',
        chainId: (await wallet.provider.getNetwork()).chainId,
        verifyingContract: contractAddress
    };

    const types = {
        Order: [
            { name: 'maker', type: 'address' },
            { name: 'nftContract', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
            { name: 'price', type: 'uint256' }
        ]
    };

    const value = {
        maker: await wallet.getAddress(),
        nftContract: nftAddress,
        tokenId: 123,
        price: ethers.parseEther('1.0')
    };

    // EIP-712 서명
    const signature = await wallet.signTypedData(domain, types, value);
    return signature;
}

// 3. EIP-1271 검증
async function verifyEIP1271Signature(
    walletAddress,
    hash,
    signature,
    provider
) {
    const ERC1271_MAGICVALUE = '0x1626ba7e';

    const wallet = new ethers.Contract(
        walletAddress,
        ['function isValidSignature(bytes32,bytes) view returns (bytes4)'],
        provider
    );

    try {
        const result = await wallet.isValidSignature(hash, signature);
        return result === ERC1271_MAGICVALUE;
    } catch (error) {
        console.error('EIP-1271 verification failed:', error);
        return false;
    }
}

// 4. 통합: EOA + Contract 모두 지원
async function verifySignature(
    signerAddress,
    message,
    signature,
    provider
) {
    // EIP-712 해시 계산
    const hash = ethers.TypedDataEncoder.hash(domain, types, message);

    if (await isContract(signerAddress, provider)) {
        // Contract: EIP-1271
        return await verifyEIP1271Signature(
            signerAddress,
            hash,
            signature,
            provider
        );
    } else {
        // EOA: ecrecover
        const recoveredAddress = ethers.verifyTypedData(
            domain,
            types,
            message,
            signature
        );
        return recoveredAddress.toLowerCase() === signerAddress.toLowerCase();
    }
}

// 5. 사용 예제
async function main() {
    const provider = new ethers.JsonRpcProvider('https://...');
    const wallet = new ethers.Wallet(privateKey, provider);

    const message = {
        maker: await wallet.getAddress(),
        nftContract: nftAddress,
        tokenId: 123,
        price: ethers.parseEther('1.0')
    };

    // 서명 생성
    const signature = await createSignature(wallet, message);
    console.log('Signature:', signature);

    // 검증
    const isValid = await verifySignature(
        await wallet.getAddress(),
        message,
        signature,
        provider
    );
    console.log('Valid:', isValid);
}
```

### React Hook 예제

```javascript
import { useState, useCallback } from 'react';
import { useWallet } from './useWallet';
import { ethers } from 'ethers';

export function useEIP1271Signature(contractAddress) {
    const { provider, signer, address } = useWallet();
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState(null);

    // 컨트랙트 여부 확인
    const isContract = useCallback(async (addr) => {
        if (!provider) return false;
        const code = await provider.getCode(addr);
        return code !== '0x';
    }, [provider]);

    // 서명 생성
    const signMessage = useCallback(async (domain, types, value) => {
        if (!signer) throw new Error('No signer');

        setIsLoading(true);
        setError(null);

        try {
            const signature = await signer.signTypedData(domain, types, value);
            return signature;
        } catch (err) {
            setError(err.message);
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, [signer]);

    // 서명 검증
    const verifySignature = useCallback(async (
        signerAddr,
        hash,
        signature
    ) => {
        if (!provider) throw new Error('No provider');

        setIsLoading(true);
        setError(null);

        try {
            const isContractWallet = await isContract(signerAddr);

            if (isContractWallet) {
                // EIP-1271 검증
                const wallet = new ethers.Contract(
                    signerAddr,
                    ['function isValidSignature(bytes32,bytes) view returns (bytes4)'],
                    provider
                );

                const result = await wallet.isValidSignature(hash, signature);
                return result === '0x1626ba7e';
            } else {
                // EOA 검증
                const recoveredAddress = ethers.recoverAddress(hash, signature);
                return recoveredAddress.toLowerCase() === signerAddr.toLowerCase();
            }
        } catch (err) {
            setError(err.message);
            return false;
        } finally {
            setIsLoading(false);
        }
    }, [provider, isContract]);

    return {
        signMessage,
        verifySignature,
        isLoading,
        error
    };
}

// 사용 예제
function NFTOrderComponent() {
    const { signMessage, verifySignature } = useEIP1271Signature();
    const [signature, setSignature] = useState('');

    const handleSign = async () => {
        const domain = {
            name: 'NFTMarketplace',
            version: '1',
            chainId: 1,
            verifyingContract: '0x...'
        };

        const types = {
            Order: [
                { name: 'maker', type: 'address' },
                { name: 'price', type: 'uint256' }
            ]
        };

        const value = {
            maker: '0x...',
            price: ethers.parseEther('1.0')
        };

        const sig = await signMessage(domain, types, value);
        setSignature(sig);
    };

    return (
        <div>
            <button onClick={handleSign}>Sign Order</button>
            {signature && <p>Signature: {signature}</p>}
        </div>
    );
}
```

---

## 보안 고려사항

### 1. Reentrancy 공격

**문제:**

```solidity
// ❌ 위험: view가 아님
function isValidSignature(bytes32 hash, bytes memory signature)
    external returns (bytes4)  // view 없음!
{
    // 악의적 컨트랙트가 이 함수를 재진입 공격 가능
    externalCall();
    return MAGICVALUE;
}
```

**해결:**

```solidity
// ✅ 안전: view 사용
function isValidSignature(bytes32 hash, bytes memory signature)
    external view returns (bytes4)  // view!
{
    // view function은 상태 변경 불가
    // 재진입 공격 불가
    return _validateSignature(hash, signature);
}
```

### 2. Signature Replay 공격

**문제:**

```solidity
// ❌ 위험: nonce 없음
struct Message {
    address to;
    uint256 value;
    // nonce 없음!
}

// 같은 서명 재사용 가능 → 중복 실행!
```

**해결:**

```solidity
// ✅ 안전: nonce + chainId 포함
struct Message {
    address to;
    uint256 value;
    uint256 nonce;    // 재사용 방지
    uint256 chainId;  // 체인 간 재사용 방지
}

mapping(address => uint256) public nonces;

function executeMessage(Message memory msg, bytes memory sig) external {
    require(msg.nonce == nonces[msg.sender], "Invalid nonce");
    require(msg.chainId == block.chainid, "Wrong chain");

    // 서명 검증...

    nonces[msg.sender]++;  // nonce 증가
}
```

### 3. Signature Malleability

**문제:**

```solidity
// ❌ ECDSA의 s 값은 두 가지 가능
// (v, r, s) != (v, r, -s mod n)
// 같은 메시지, 다른 서명 → 중복 카운팅 가능
```

**해결:**

```solidity
// ✅ OpenZeppelin ECDSA 사용
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SafeWallet is IERC1271 {
    using ECDSA for bytes32;

    function isValidSignature(bytes32 hash, bytes memory signature)
        external view override returns (bytes4)
    {
        // OpenZeppelin이 자동으로 malleability 체크
        address signer = hash.recover(signature);
        return (signer == owner) ? MAGICVALUE : bytes4(0xffffffff);
    }
}
```

**또는 수동 검증:**

```solidity
function isValidSignature(bytes32 hash, bytes memory signature)
    external view override returns (bytes4)
{
    (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

    // s 값 범위 확인 (malleability 방지)
    require(
        uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
        "Invalid s value"
    );

    address signer = ecrecover(hash, v, r, s);
    return (signer == owner) ? MAGICVALUE : bytes4(0xffffffff);
}
```

### 4. Domain Separation (EIP-712)

**문제:**

```solidity
// ❌ 위험: 도메인 분리 없음
bytes32 hash = keccak256(abi.encode(data));
// 다른 DApp에서 같은 해시 사용 가능!
```

**해결:**

```solidity
// ✅ 안전: EIP-712로 도메인 분리
bytes32 DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes("MyDApp")),
    keccak256(bytes("1")),
    block.chainid,
    address(this)
));

bytes32 structHash = keccak256(abi.encode(TYPE_HASH, data));
bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

// 이제 다른 DApp/체인에서 재사용 불가!
```

### 5. Gas Limits

**문제:**

```solidity
// ❌ 위험: 무한 루프 가능
function isValidSignature(bytes32 hash, bytes memory signature)
    external view returns (bytes4)
{
    // 가스 제한 없이 복잡한 로직
    for (uint256 i = 0; i < veryLargeArray.length; i++) {
        // 가스 초과 가능!
    }
}
```

**해결:**

```solidity
// ✅ 안전: 가스 효율적인 로직
function isValidSignature(bytes32 hash, bytes memory signature)
    external view returns (bytes4)
{
    // 1. 고정 길이 배열 사용
    // 2. 조기 종료 (early return)
    // 3. 필요한 만큼만 반복

    uint256 limit = min(owners.length, 10);  // 최대 10개
    for (uint256 i = 0; i < limit; i++) {
        if (checkSignature(i)) {
            return MAGICVALUE;  // 조기 종료
        }
    }

    return bytes4(0xffffffff);
}
```

### 6. Zero Address 체크

```solidity
// ✅ ecrecover 실패 시 address(0) 반환 확인
address signer = ecrecover(hash, v, r, s);
require(signer != address(0), "Invalid signature");  // 필수!
require(signer == owner, "Not owner");
```

### 7. Try-Catch 사용

```solidity
// ✅ EIP-1271 호출 시 try-catch 사용
if (account.code.length > 0) {
    try IERC1271(account).isValidSignature(hash, signature)
        returns (bytes4 magicValue)
    {
        return magicValue == 0x1626ba7e;
    } catch {
        // 호출 실패 시 false 반환
        return false;
    }
}
```

---

## 실제 사용 사례

### 1. Gnosis Safe

**멀티시그 지갑의 표준:**

```solidity
// Gnosis Safe의 EIP-1271 구현
function isValidSignature(bytes32 _data, bytes memory _signature)
    public view override returns (bytes4)
{
    // threshold만큼의 서명 검증
    require(checkNSignatures(_data, _signature, threshold));
    return 0x1626ba7e;
}
```

**사용 예:**
- 여러 소유자가 하나의 지갑 공유
- 2-of-3, 3-of-5 등 임계값 설정
- OpenSea, Uniswap 등에서 직접 거래

### 2. Account Abstraction (EIP-4337)

**Smart Contract Wallet:**

```solidity
// UserOperation 서명 검증
function validateUserOp(
    UserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
) external returns (uint256 validationData) {
    // EIP-1271로 서명 검증
    require(
        this.isValidSignature(userOpHash, userOp.signature) == 0x1626ba7e,
        "Invalid signature"
    );

    // ...
}
```

**장점:**
- 소셜 로그인
- 가스 대납
- 배치 트랜잭션

### 3. Argent Wallet

**Guardian 기반 복구 시스템:**

```solidity
// Guardian들의 서명으로 복구
function isValidSignature(bytes32 hash, bytes memory signature)
    external view override returns (bytes4)
{
    address signer = recoverSigner(hash, signature);

    // 소유자 or Guardian
    if (signer == owner || isGuardian[signer]) {
        return 0x1626ba7e;
    }

    return bytes4(0xffffffff);
}
```

### 4. OpenSea

**NFT Marketplace:**

```javascript
// OpenSea에서 Gnosis Safe 사용자 지원
async function validateOrder(order, signature) {
    const orderHash = hashOrder(order);

    if (await isContract(order.maker)) {
        // EIP-1271 검증
        const wallet = new ethers.Contract(order.maker, ERC1271_ABI);
        const result = await wallet.isValidSignature(orderHash, signature);
        return result === '0x1626ba7e';
    } else {
        // EOA 검증
        return ecrecover(orderHash, signature) === order.maker;
    }
}
```

### 5. Uniswap Permit2

**통합 승인 시스템:**

```solidity
// Permit2에서 EIP-1271 지원
function permitTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
) external {
    // EIP-1271로 검증
    if (owner.code.length > 0) {
        require(
            IERC1271(owner).isValidSignature(hash, signature) == 0x1626ba7e,
            "Invalid signature"
        );
    } else {
        // EOA 검증...
    }
}
```

---

## FAQ

### Q1. EIP-1271과 EIP-712의 차이는?

**A:**
```
EIP-712: 서명할 데이터를 구조화하는 방법
         (어떻게 해시를 만들까?)

EIP-1271: 서명을 검증하는 방법
          (이 서명이 유효한가?)

→ 함께 사용: EIP-712로 해시 생성 → EIP-1271로 검증
```

### Q2. Magic Value는 왜 필요한가?

**A:**
```solidity
// 1. 명확한 성공/실패 구분
return 0x1626ba7e;  // 성공
return 0xffffffff;  // 실패

// 2. 함수 시그니처로 고유값 생성
bytes4(keccak256("isValidSignature(bytes32,bytes)"))

// 3. 다른 함수와 충돌 방지
```

### Q3. View가 아닌 함수로 구현하면?

**A:**
```
❌ 문제:
1. 가스비 발생
2. 다른 컨트랙트에서 staticcall 실패
3. 상태 변경으로 재진입 공격 가능

✅ 반드시 view로 구현해야 함!
```

### Q4. 멀티시그에서 서명 순서는?

**A:**
```solidity
// ✅ 주소 순으로 정렬 필요 (Gnosis Safe 방식)
address[] memory signers = [0x111, 0x222, 0x333];

// 서명도 주소 순으로:
// 1. 0x111의 서명
// 2. 0x222의 서명
// 3. 0x333의 서명

// 이유: 중복 확인 효율화
for (uint i = 0; i < signers.length; i++) {
    require(signers[i] > lastSigner, "Wrong order");
    lastSigner = signers[i];
}
```

### Q5. EOA와 Contract 구분은 어떻게?

**A:**
```javascript
// 코드 길이로 확인
const code = await provider.getCode(address);
const isContract = code !== '0x';

// Solidity
if (account.code.length > 0) {
    // Contract
} else {
    // EOA
}
```

### Q6. 세션 키는 언제 사용하나?

**A:**
```
✅ 사용 사례:
1. 게임: 자동 아이템 구매
2. DeFi: 자동 트레이딩 봇
3. DApp: 임시 권한 부여

장점:
- 매번 서명 불필요
- 제한된 권한 (금액, 기간, 대상)
- 언제든 취소 가능
```

### Q7. 서명 재사용 방지는?

**A:**
```solidity
struct Message {
    // 1. Nonce (순차적)
    uint256 nonce;

    // 2. ChainId (체인 간 재사용 방지)
    uint256 chainId;

    // 3. Deadline (만료 시간)
    uint256 deadline;

    // 4. Contract Address (도메인 분리)
    address verifyingContract;
}

// 검증
require(msg.nonce == nonces[user], "Used");
require(msg.chainId == block.chainid, "Wrong chain");
require(msg.deadline >= block.timestamp, "Expired");
```

### Q8. Gas 비용은?

**A:**
```
단일 소유자:    ~30,000 gas
멀티시그 2-of-3: ~80,000 gas
멀티시그 3-of-5: ~120,000 gas

✅ view function이므로 조회는 무료
✅ 실행 시에만 가스 발생
```

---

## 참고 자료

### 공식 문서
- [EIP-1271 Specification](https://eips.ethereum.org/EIPS/eip-1271)
- [EIP-712: Typed Structured Data](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)

### 구현 예제
- [Gnosis Safe Contracts](https://github.com/safe-global/safe-contracts)
- [OpenZeppelin IERC1271](https://docs.openzeppelin.com/contracts/4.x/api/interfaces#IERC1271)
- [Argent Wallet](https://github.com/argentlabs/argent-contracts)

### 학습 자료
- [EIP-712 README](../EIP-712/README.md)
- [EIP-2612 (Permit) README](../EIP-2612/README.md)
- [Account Abstraction Guide](https://ethereum.org/en/developers/docs/accounts)

### 보안 감사
- [Trail of Bits: Smart Contract Security](https://www.trailofbits.com/)
- [OpenZeppelin Security](https://www.openzeppelin.com/security-audits)

---

## 라이센스

MIT License

---

**마지막 업데이트:** 2025
**버전:** 1.0.0

**핵심 포인트:**
- 🔑 컨트랙트가 서명을 검증할 수 있는 표준
- 🎯 EOA와 Contract 모두 지원
- 🛡️ 멀티시그, Account Abstraction, DAO 등 고급 기능
- ⚡ View function으로 가스 효율적
- 🔗 EIP-712와 함께 사용하여 강력한 보안
