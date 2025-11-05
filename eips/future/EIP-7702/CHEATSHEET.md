# EIP-7702 Cheat Sheet

> **빠른 참조** - EOA 코드 위임 (Set EOA Account Code)

## 🎯 핵심 (5초)

```
문제: EOA는 스마트 컨트랙트 기능 사용 불가 😢
해결: 트랜잭션 실행 중 임시로 코드 위임 ✨

→ Authorization List로 코드 위임
→ 기존 EOA 주소 유지
→ Account Abstraction 기능 즉시 사용
```

## 📋 Type 4 트랜잭션 구조

```javascript
{
    type: 4,  // EIP-7702
    to: "0x...",  // EOA 주소
    data: "0x...",
    authorizationList: [  // 🆕 새 필드!
        {
            chainId: 1,
            address: "0x...",  // 위임할 컨트랙트
            nonce: 5,
            yParity: 0,
            r: "0x...",
            s: "0x..."
        }
    ],
    maxFeePerGas: "50000000000",
    maxPriorityFeePerGas: "2000000000",
    gasLimit: 300000
}
```

## 🔑 Authorization 생성

```javascript
const { ethers } = require('ethers');

// 1. Authorization Hash 계산
const MAGIC = '0x05';  // EIP-7702 magic byte
const authHash = ethers.utils.keccak256(
    ethers.utils.concat([
        MAGIC,
        ethers.utils.defaultAbiCoder.encode(
            ['uint256', 'uint256', 'address'],
            [chainId, nonce, delegationAddress]
        )
    ])
);

// 2. 서명
const signature = await eoaSigner.signMessage(
    ethers.utils.arrayify(authHash)
);

const { v, r, s } = ethers.utils.splitSignature(signature);

// 3. Authorization 객체
const authorization = {
    chainId: chainId,
    address: delegationAddress,
    nonce: nonce,
    yParity: v - 27,
    r: r,
    s: s
};
```

## 💻 기본 Delegation 컨트랙트

### 1. SimpleDelegation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleDelegation {
    // 단일 트랜잭션 실행
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        require(msg.sender == address(this), "Not authorized");

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");

        return result;
    }

    // 배치 트랜잭션 실행
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (bytes[] memory) {
        require(msg.sender == address(this), "Not authorized");
        require(
            targets.length == values.length &&
            targets.length == datas.length,
            "Length mismatch"
        );

        bytes[] memory results = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call{
                value: values[i]
            }(datas[i]);
            require(success, "Batch execution failed");
            results[i] = result;
        }

        return results;
    }
}
```

### 2. SessionDelegation

```solidity
contract SessionDelegation {
    struct Session {
        address operator;
        uint256 validUntil;
        uint256 gasLimit;
        uint256 gasUsed;
        bool active;
    }

    mapping(bytes32 => Session) public sessions;

    event SessionCreated(bytes32 indexed sessionId, address operator, uint256 validUntil);
    event SessionRevoked(bytes32 indexed sessionId);

    // 세션 생성
    function createSession(
        address operator,
        uint256 duration,
        uint256 gasLimit,
        uint256 nonce
    ) external returns (bytes32 sessionId) {
        require(msg.sender == address(this), "Not authorized");

        sessionId = keccak256(
            abi.encodePacked(msg.sender, operator, nonce, block.timestamp)
        );

        sessions[sessionId] = Session({
            operator: operator,
            validUntil: block.timestamp + duration,
            gasLimit: gasLimit,
            gasUsed: 0,
            active: true
        });

        emit SessionCreated(sessionId, operator, block.timestamp + duration);
        return sessionId;
    }

    // 세션으로 실행
    function executeWithSession(
        bytes32 sessionId,
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        Session storage session = sessions[sessionId];

        require(session.active, "Session not active");
        require(block.timestamp < session.validUntil, "Session expired");
        require(msg.sender == session.operator, "Not session operator");

        uint256 gasBefore = gasleft();

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");

        uint256 gasUsed = gasBefore - gasleft();
        session.gasUsed += gasUsed;
        require(session.gasUsed <= session.gasLimit, "Gas limit exceeded");

        return result;
    }

    // 세션 취소
    function revokeSession(bytes32 sessionId) external {
        require(msg.sender == address(this), "Not authorized");
        sessions[sessionId].active = false;
        emit SessionRevoked(sessionId);
    }
}
```

### 3. MultiSigDelegation

```solidity
contract MultiSigDelegation {
    uint256 public threshold;
    address[] public signers;
    mapping(address => bool) public isSigner;

    event ExecutionSuccess(bytes32 txHash);

    // 초기화
    function initialize(
        address[] memory _signers,
        uint256 _threshold
    ) external {
        require(msg.sender == address(this), "Not authorized");
        require(signers.length == 0, "Already initialized");
        require(_threshold > 0 && _threshold <= _signers.length);

        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            require(signer != address(0));
            require(!isSigner[signer]);

            isSigner[signer] = true;
            signers.push(signer);
        }

        threshold = _threshold;
    }

    // 멀티시그 실행
    function executeMultiSig(
        address target,
        uint256 value,
        bytes calldata data,
        bytes[] calldata signatures
    ) external payable returns (bytes memory) {
        require(signatures.length >= threshold, "Not enough signatures");

        bytes32 txHash = keccak256(abi.encode(target, value, data, block.chainid));
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash)
        );

        address lastSigner = address(0);
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = recoverSigner(ethSignedHash, signatures[i]);
            require(isSigner[signer], "Invalid signer");
            require(signer > lastSigner, "Duplicate or unordered");
            lastSigner = signer;
        }

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");

        emit ExecutionSuccess(txHash);
        return result;
    }

    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        require(signature.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return ecrecover(hash, v, r, s);
    }
}
```

## 🚀 실전 사용 예제

### 배치 트랜잭션 (여러 작업 한 번에)

```javascript
const { ethers } = require('ethers');

async function executeBatchTransaction() {
    // 1. Delegation 컨트랙트 배포
    const SimpleDelegation = await ethers.getContractFactory('SimpleDelegation');
    const delegation = await SimpleDelegation.deploy();

    // 2. EOA 서명자
    const eoaSigner = new ethers.Wallet(privateKey, provider);

    // 3. Authorization 생성
    const chainId = (await provider.getNetwork()).chainId;
    const nonce = await eoaSigner.getTransactionCount();

    const MAGIC = '0x05';
    const authHash = ethers.utils.keccak256(
        ethers.utils.concat([
            MAGIC,
            ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256', 'address'],
                [chainId, nonce, delegation.address]
            )
        ])
    );

    const signature = await eoaSigner.signMessage(
        ethers.utils.arrayify(authHash)
    );
    const { v, r, s } = ethers.utils.splitSignature(signature);

    const authorization = {
        chainId: chainId,
        address: delegation.address,
        nonce: nonce,
        yParity: v - 27,
        r: r,
        s: s
    };

    // 4. 배치 트랜잭션 데이터
    const targets = [
        usdcToken.address,
        uniswapRouter.address,
        aavePool.address
    ];

    const values = [0, 0, 0];

    const datas = [
        // USDC approve
        usdcToken.interface.encodeFunctionData('approve', [
            uniswapRouter.address,
            ethers.utils.parseUnits('1000', 6)
        ]),
        // Uniswap swap
        uniswapRouter.interface.encodeFunctionData('swapExactTokensForTokens', [
            ethers.utils.parseUnits('1000', 6),
            0,
            [usdcToken.address, wethToken.address],
            eoaSigner.address,
            Math.floor(Date.now() / 1000) + 60 * 20
        ]),
        // Aave deposit
        aavePool.interface.encodeFunctionData('supply', [
            wethToken.address,
            ethers.utils.parseEther('1'),
            eoaSigner.address,
            0
        ])
    ];

    // 5. Type 4 트랜잭션 전송
    const tx = {
        type: 4,
        to: eoaSigner.address,  // EOA 주소
        data: delegation.interface.encodeFunctionData('executeBatch', [
            targets,
            values,
            datas
        ]),
        authorizationList: [authorization],
        gasLimit: 500000,
        maxFeePerGas: ethers.utils.parseUnits('50', 'gwei'),
        maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei')
    };

    const txResponse = await eoaSigner.sendTransaction(tx);
    const receipt = await txResponse.wait();

    console.log('Batch executed:', receipt.transactionHash);
    console.log('USDC approved, swapped to WETH, deposited to Aave!');
}
```

### Session Key로 게임 자동화

```javascript
async function setupGameSession() {
    // 1. SessionDelegation 배포 및 세션 생성
    const gameOperator = new ethers.Wallet(operatorPrivateKey);

    // 세션 생성 트랜잭션 (Type 4)
    const sessionId = await createSessionWithEIP7702(
        eoaSigner,
        sessionDelegation.address,
        gameOperator.address,
        24 * 60 * 60,  // 24시간
        1000000  // 1M gas limit
    );

    console.log('Session created:', sessionId);

    // 2. 게임 오퍼레이터가 세션으로 트랜잭션 실행 (일반 트랜잭션!)
    const tx = await sessionDelegation.connect(gameOperator).executeWithSession(
        sessionId,
        gameContract.address,
        0,
        gameContract.interface.encodeFunctionData('claimReward', [123])
    );

    await tx.wait();
    console.log('Game action executed by operator without user signature!');
}
```

## 🔒 보안 체크리스트

### ✅ 해야 할 것

```solidity
contract SecureDelegation {
    // 1. msg.sender 검증
    function execute(...) external {
        require(msg.sender == address(this), "Not authorized");
        // ✅ 위임된 EOA만 호출 가능
    }

    // 2. 재진입 방지
    bool private locked;

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function execute(...) external nonReentrant {
        // ✅ 재진입 공격 방지
    }

    // 3. Storage 네임스페이스 사용 (EIP-7201)
    bytes32 private constant DELEGATION_STORAGE_LOCATION =
        keccak256("my.delegation.storage") - 1;

    struct DelegationStorage {
        mapping(address => bool) authorized;
        uint256 nonce;
    }

    function _getDelegationStorage() private pure
        returns (DelegationStorage storage $)
    {
        assembly {
            $.slot := DELEGATION_STORAGE_LOCATION
        }
    }
}
```

### ❌ 하면 안 되는 것

```solidity
// ❌ 1. msg.sender 검증 없음
function execute(...) external {
    // 누구나 호출 가능! 위험!
}

// ❌ 2. Authorization 재사용
// Nonce가 자동 증가하므로 같은 Authorization은 한 번만 사용 가능

// ❌ 3. 일반 Storage 슬롯 사용
contract BadDelegation {
    address public owner;  // slot 0 - EOA storage와 충돌!
}

// ❌ 4. selfdestruct 사용
function destroy() external {
    selfdestruct(payable(msg.sender));  // 절대 금지!
}

// ❌ 5. Chain ID 검증 안 함
// Authorization은 특정 체인에서만 유효해야 함
```

## 📊 EIP-3074 vs EIP-7702

| 구분 | EIP-3074 (❌ 거부됨) | EIP-7702 (✅ 선택됨) |
|------|---------------------|---------------------|
| **방식** | AUTH/AUTHCALL opcodes | Authorization List |
| **위임 범위** | 전역 (모든 컨트랙트) | 트랜잭션당 임시 |
| **보안** | Invoker 신뢰 필요 | EOA가 직접 제어 |
| **상태** | 영구적 | 임시적 |
| **EOA 컨텍스트** | 불분명 | msg.sender == address(this) |
| **업그레이드 경로** | 불명확 | 명확 (EIP-7702 → 완전 SC) |

## 📦 배포 (Hardhat)

```javascript
// hardhat.config.js
module.exports = {
    solidity: "0.8.20",
    networks: {
        pectra: {  // Pectra testnet
            url: process.env.PECTRA_RPC_URL,
            accounts: [process.env.PRIVATE_KEY]
        }
    }
};

// scripts/deploy.js
const { ethers } = require('hardhat');

async function main() {
    // 1. SimpleDelegation 배포
    const SimpleDelegation = await ethers.getContractFactory('SimpleDelegation');
    const delegation = await SimpleDelegation.deploy();
    await delegation.deployed();

    console.log('SimpleDelegation deployed:', delegation.address);

    // 2. 첫 번째 위임 테스트
    const [signer] = await ethers.getSigners();
    const nonce = await signer.getTransactionCount();
    const chainId = (await ethers.provider.getNetwork()).chainId;

    // Authorization 생성
    const MAGIC = '0x05';
    const authHash = ethers.utils.keccak256(
        ethers.utils.concat([
            MAGIC,
            ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256', 'address'],
                [chainId, nonce, delegation.address]
            )
        ])
    );

    const signature = await signer.signMessage(
        ethers.utils.arrayify(authHash)
    );
    const { v, r, s } = ethers.utils.splitSignature(signature);

    const authorization = {
        chainId: chainId,
        address: delegation.address,
        nonce: nonce,
        yParity: v - 27,
        r: r,
        s: s
    };

    // Type 4 트랜잭션
    const tx = {
        type: 4,
        to: signer.address,
        data: delegation.interface.encodeFunctionData('execute', [
            targetContract.address,
            0,
            targetContract.interface.encodeFunctionData('someFunction', [])
        ]),
        authorizationList: [authorization],
        gasLimit: 300000
    };

    const txResponse = await signer.sendTransaction(tx);
    await txResponse.wait();

    console.log('First delegation executed!');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
```

## 🎯 사용 사례

### 1. 배치 트랜잭션
```
시나리오: DEX에서 Swap + Stake을 한 트랜잭션으로
→ SimpleDelegation.executeBatch() 사용
→ 2개 트랜잭션 → 1개 트랜잭션 (Gas 50% 절감)
```

### 2. 게임 자동화
```
시나리오: 게임 오퍼레이터가 24시간 동안 자동 플레이
→ SessionDelegation.createSession() 사용
→ 사용자는 한 번만 승인, 오퍼레이터가 자동 실행
```

### 3. 소셜 복구
```
시나리오: 키 분실 시 3명의 Guardian이 복구
→ MultiSigDelegation + RecoveryDelegation 사용
→ 2-of-3 서명으로 새 키로 자산 이전
```

### 4. Gasless 트랜잭션
```
시나리오: 사용자는 Gas 없이, Relayer가 Gas 대납
→ GaslessTransactionDelegation 사용
→ 사용자는 메타트랜잭션 서명, Relayer가 실행
```

### 5. Smart Session
```
시나리오: DeFi 프로토콜 자동 리밸런싱
→ SessionDelegation + 조건부 실행
→ 가격 변동 시 자동으로 포지션 조정
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 가이드
- [EIP-7702 Spec](https://eips.ethereum.org/EIPS/eip-7702)
- [EIP7702Example.sol](./contracts/EIP7702Example.sol) - 6가지 패턴
- [Vitalik의 EIP-7702 설명](https://notes.ethereum.org/@vbuterin/set_code_txn)
- [Pectra Upgrade](https://ethereum.org/en/roadmap/pectra/)

## 🎓 핵심 개념 요약

### Authorization List
```javascript
authorizationList: [
    {
        chainId: 1,           // 네트워크 지정
        address: "0x...",     // 위임할 컨트랙트
        nonce: 5,             // Authorization nonce
        yParity: 0,           // 서명 v 값
        r: "0x...",           // 서명 r
        s: "0x..."            // 서명 s
    }
]
```

### Delegation Designator
```
0xef0100 || address (23 bytes)
→ EOA code가 이 값이면 "위임됨" 표시
→ 트랜잭션 종료 후 자동 제거
```

### msg.sender == address(this)
```solidity
// 위임된 EOA에서 실행될 때
contract Delegation {
    function execute() external {
        // msg.sender == address(this) == EOA 주소
        require(msg.sender == address(this));
    }
}
```

### Storage in EOA
```
Delegation 컨트랙트의 storage 변수:
→ EOA 주소의 storage 슬롯에 저장
→ EIP-7201 네임스페이스 패턴 사용 권장
```

## 💡 자주하는 실수

### 실수 1: msg.sender 검증 안 함
```solidity
// ❌ 틀림
function execute(address target, bytes calldata data) external {
    // 누구나 호출 가능!
    target.call(data);
}

// ✅ 맞음
function execute(address target, bytes calldata data) external {
    require(msg.sender == address(this), "Not authorized");
    target.call(data);
}
```

### 실수 2: 일반 트랜잭션으로 시도
```javascript
// ❌ 틀림: Type 0 트랜잭션
const tx = await delegation.execute(target, data);

// ✅ 맞음: Type 4 트랜잭션
const tx = {
    type: 4,  // 반드시 Type 4!
    to: eoaAddress,
    data: delegation.interface.encodeFunctionData('execute', [target, data]),
    authorizationList: [authorization]
};
await signer.sendTransaction(tx);
```

### 실수 3: Nonce 재사용
```javascript
// ❌ 틀림: 같은 Authorization 두 번 사용
const auth1 = createAuth(chainId, nonce, delegation.address);
await sendTx(auth1);  // 성공
await sendTx(auth1);  // 실패! Nonce가 이미 증가됨

// ✅ 맞음: 매번 새로운 nonce 사용
const auth1 = createAuth(chainId, nonce, delegation.address);
await sendTx(auth1);  // nonce → nonce + 1
const auth2 = createAuth(chainId, nonce + 1, delegation.address);
await sendTx(auth2);  // 성공
```

## 📈 Gas 비용

```
일반 EOA 트랜잭션:
- 단일 트랜잭션: ~21,000 gas
- 2개 트랜잭션: ~42,000 gas

EIP-7702 배치 트랜잭션:
- Authorization 검증: ~3,000 gas
- Delegation 로딩: ~2,600 gas
- 2개 작업 실행: ~20,000 gas
- 총: ~25,600 gas (39% 절감!)

Type 4 추가 비용:
- Authorization당: ~3,000 gas
- 코드 로딩: ~2,600 gas
- 총 오버헤드: ~5,600 gas
```

## 🌍 실제 사용 예정

```
Safe (Gnosis Safe):
→ 기존 Safe EOA를 Smart Account로 업그레이드

Metamask:
→ EOA 사용자에게 Account Abstraction 기능 제공

Uniswap:
→ Swap + Add Liquidity 배치 트랜잭션

게임 (Parallel, Axie):
→ Session Key로 게임 자동화

지갑 (Rainbow, Coinbase Wallet):
→ Gasless 트랜잭션 지원
```

---

**핵심 요약:**

```
Type 4 트랜잭션:
→ authorizationList 필드 추가
→ EOA가 임시로 코드 위임
→ 트랜잭션 종료 후 자동 제거

보안 패턴:
✅ require(msg.sender == address(this))
✅ EIP-7201 네임스페이스 사용
✅ Authorization nonce 자동 증가
✅ 재진입 방지
❌ selfdestruct 금지

사용 사례:
→ 배치 트랜잭션 (Gas 절감)
→ Session Key (게임 자동화)
→ Multi-sig (보안 강화)
→ Gasless (UX 개선)
```

**Pectra Hardfork (2024-2025) 포함 예정!**

**마지막 업데이트: 2025**
