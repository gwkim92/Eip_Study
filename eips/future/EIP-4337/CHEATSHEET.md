# EIP-4337 Cheat Sheet

> **빠른 참조** - Account Abstraction (계정 추상화)

## 🎯 핵심 (5초)

```
EOA 문제: 개인키 분실 = 영구 손실 💥
EIP-4337: 스마트 컨트랙트 = 계정

→ 소셜 복구, 가스리스, 멀티시그, 세션 키!
```

## 📝 핵심 구조

```
User → UserOperation → Bundler → EntryPoint → Smart Account
                                              ↓
                                         Paymaster (선택)
```

## 💻 UserOperation 구조

```solidity
struct UserOperation {
    address sender;              // 스마트 계정 주소
    uint256 nonce;              // 재실행 방지
    bytes initCode;             // 계정 생성 (없으면 '0x')
    bytes callData;             // 실행할 함수
    uint256 callGasLimit;       // 실행 가스
    uint256 verificationGasLimit; // 검증 가스
    uint256 preVerificationGas; // Bundler 보상
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;     // Paymaster 주소 + 데이터
    bytes signature;            // 서명
}
```

## 🔧 기본 Smart Account 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccount {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

contract SimpleAccount is IAccount {
    address public owner;
    IEntryPoint private immutable _entryPoint;

    constructor(IEntryPoint entryPoint_, address owner_) {
        _entryPoint = entryPoint_;
        owner = owner_;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        // 서명 검증
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        if (signer != owner) {
            return 1;  // 검증 실패
        }

        // 가스비 지불
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{
                value: missingAccountFunds
            }("");
            require(success, "Failed to pay");
        }

        return 0;  // 검증 성공
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    receive() external payable {}
}
```

## 🏭 Account Factory

```solidity
contract AccountFactory {
    IEntryPoint public immutable entryPoint;

    constructor(IEntryPoint entryPoint_) {
        entryPoint = entryPoint_;
    }

    // CREATE2로 계정 생성
    function createAccount(address owner, uint256 salt)
        external
        returns (SimpleAccount)
    {
        address addr = getAddress(owner, salt);

        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SimpleAccount(payable(addr));
        }

        SimpleAccount account = new SimpleAccount{salt: bytes32(salt)}(
            entryPoint,
            owner
        );

        return account;
    }

    // 주소 사전 계산
    function getAddress(address owner, uint256 salt)
        public
        view
        returns (address)
    {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            bytes32(salt),
                            keccak256(
                                abi.encodePacked(
                                    type(SimpleAccount).creationCode,
                                    abi.encode(entryPoint, owner)
                                )
                            )
                        )
                    )
                )
            )
        );
    }
}
```

## 💰 Paymaster 구현

```solidity
contract SimplePaymaster is IPaymaster {
    IEntryPoint public immutable entryPoint;
    address public owner;

    mapping(address => bool) public allowedAccounts;

    constructor(IEntryPoint entryPoint_) {
        entryPoint = entryPoint_;
        owner = msg.sender;
    }

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Not EntryPoint");
        require(allowedAccounts[userOp.sender], "Not allowed");

        uint256 balance = entryPoint.balanceOf(address(this));
        require(balance >= maxCost, "Insufficient balance");

        return ("", 0);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external override {
        // 필요시 추가 로직
    }

    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    receive() external payable {
        deposit();
    }
}
```

## 🚀 Frontend 사용 (ethers.js)

```javascript
import { ethers } from 'ethers';

// 1. UserOperation 생성
const userOp = {
    sender: smartAccountAddress,
    nonce: await entryPoint.getNonce(smartAccountAddress, 0),
    initCode: '0x',  // 이미 배포됨
    callData: smartAccount.interface.encodeFunctionData('execute', [
        targetAddress,
        ethers.utils.parseEther('0.1'),
        '0x'
    ]),
    callGasLimit: 100000,
    verificationGasLimit: 100000,
    preVerificationGas: 21000,
    maxFeePerGas: await provider.getGasPrice(),
    maxPriorityFeePerGas: 1000000000,
    paymasterAndData: '0x',
    signature: '0x'
};

// 2. 서명
const userOpHash = await entryPoint.getUserOpHash(userOp);
const signature = await signer.signMessage(ethers.utils.arrayify(userOpHash));
userOp.signature = signature;

// 3. Bundler에 제출
await bundlerProvider.sendUserOperation(userOp);
```

## 📦 SDK 사용 (userop)

```javascript
import { Presets, Client } from 'userop';
import { ethers } from 'ethers';

// 1. Bundler 설정
const bundlerRPC = 'https://api.stackup.sh/v1/node/YOUR_API_KEY';
const paymasterRPC = 'https://api.stackup.sh/v1/paymaster/YOUR_API_KEY';

// 2. Account 빌더
const simpleAccount = await Presets.Builder.SimpleAccount.init(
    signer,
    bundlerRPC,
    {
        paymasterMiddleware: paymasterRPC ?
            Presets.Middleware.verifyingPaymaster(paymasterRPC, { type: 'payg' })
            : undefined
    }
);

// 3. Client 초기화
const client = await Client.init(bundlerRPC);

// 4. UserOperation 실행
const res = await client.sendUserOperation(
    simpleAccount.execute(
        targetAddress,
        ethers.utils.parseEther('0.1'),
        '0x'
    )
);

const event = await res.wait();
console.log('Transaction hash:', event.transactionHash);
```

## 🎮 배치 트랜잭션

```javascript
// approve + deposit + stake를 한 번에!
const calls = [
    {
        to: token.address,
        value: 0,
        data: token.interface.encodeFunctionData('approve', [
            spenderAddress,
            ethers.utils.parseEther('100')
        ])
    },
    {
        to: spenderAddress,
        value: 0,
        data: spender.interface.encodeFunctionData('deposit', [
            ethers.utils.parseEther('100')
        ])
    },
    {
        to: spenderAddress,
        value: 0,
        data: spender.interface.encodeFunctionData('stake', [])
    }
];

const callData = smartAccount.interface.encodeFunctionData(
    'executeBatch',
    [
        calls.map(c => c.to),
        calls.map(c => c.value),
        calls.map(c => c.data)
    ]
);

const userOp = {
    sender: smartAccount.address,
    callData: callData,
    // ...
};

await client.sendUserOperation(userOp);
// → 한 번의 서명으로 3개 실행!
```

## 🔑 세션 키 패턴

```solidity
contract SessionKeyAccount is IAccount {
    address public mainOwner;

    struct SessionKey {
        address key;
        uint256 validUntil;
        uint256 gasLimit;
        address[] allowedTargets;
    }

    mapping(address => SessionKey) public sessionKeys;

    function addSessionKey(
        address key,
        uint256 validUntil,
        uint256 gasLimit,
        address[] calldata allowedTargets
    ) external {
        require(msg.sender == mainOwner, "Not main owner");

        sessionKeys[key] = SessionKey({
            key: key,
            validUntil: validUntil,
            gasLimit: gasLimit,
            allowedTargets: allowedTargets
        });
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        // 메인 소유자
        if (signer == mainOwner) {
            // 가스비 지불 후 성공
            return 0;
        }

        // 세션 키 확인
        SessionKey memory session = sessionKeys[signer];

        if (session.key == address(0)) return 1;
        if (block.timestamp > session.validUntil) return 1;
        if (userOp.callGasLimit > session.gasLimit) return 1;

        return 0;
    }
}
```

사용 예제:

```javascript
// 1. 세션 키 생성
const sessionKey = ethers.Wallet.createRandom();

// 2. 등록 (24시간 유효)
await smartAccount.addSessionKey(
    sessionKey.address,
    Math.floor(Date.now() / 1000) + 86400,
    500000,
    [gameContract.address]
);

// 3. 게임에서 세션 키로 서명
async function playGame(action) {
    const userOp = buildUserOp(gameAction);
    userOp.signature = await sessionKey.signMessage(userOpHash);
    await client.sendUserOperation(userOp);
    // → 빠르고 편리!
}
```

## 🛡️ 소셜 복구 패턴

```solidity
contract RecoverableAccount is IAccount {
    address public owner;
    address[] public guardians;
    mapping(address => bool) public isGuardian;

    struct Recovery {
        address newOwner;
        uint256 approvalCount;
        mapping(address => bool) approved;
    }

    mapping(uint256 => Recovery) public recoveries;
    uint256 public recoveryNonce;
    uint256 public requiredApprovals;  // 예: 2-of-3

    // 복구 시작
    function initiateRecovery(address newOwner) external {
        require(isGuardian[msg.sender], "Not guardian");

        recoveryNonce++;
        Recovery storage recovery = recoveries[recoveryNonce];
        recovery.newOwner = newOwner;
        recovery.approvalCount = 1;
        recovery.approved[msg.sender] = true;
    }

    // 복구 승인
    function approveRecovery(uint256 nonce) external {
        require(isGuardian[msg.sender], "Not guardian");

        Recovery storage recovery = recoveries[nonce];
        require(!recovery.approved[msg.sender], "Already approved");

        recovery.approved[msg.sender] = true;
        recovery.approvalCount++;

        // 충분한 승인이 모이면 실행
        if (recovery.approvalCount >= requiredApprovals) {
            owner = recovery.newOwner;
            delete recoveries[nonce];
        }
    }
}
```

## 🔧 EntryPoint 상수

```solidity
// EntryPoint v0.6 주소 (모든 체인 동일)
address constant ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

// 검증 결과
uint256 constant SIG_VALIDATION_FAILED = 1;
uint256 constant SIG_VALIDATION_SUCCESS = 0;
```

## ⚠️ 보안 체크리스트

```solidity
// ✅ 1. EntryPoint 확인
function validateUserOp(...) external override returns (uint256) {
    require(msg.sender == address(_entryPoint), "Not EntryPoint");
    // ...
}

// ✅ 2. 서명 검증
bytes32 hash = userOpHash.toEthSignedMessageHash();
address signer = hash.recover(userOp.signature);
require(signer != address(0), "Invalid signature");
require(signer == owner, "Not owner");

// ✅ 3. 가스비 지불
if (missingAccountFunds > 0) {
    (bool success,) = payable(msg.sender).call{
        value: missingAccountFunds
    }("");
    require(success, "Failed to pay");
}

// ✅ 4. Nonce 관리
uint256 currentNonce = _entryPoint.getNonce(address(this), nonceKey);
require(userOp.nonce == currentNonce, "Invalid nonce");

// ✅ 5. 재진입 방지
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

function execute(...) external nonReentrant {
    // ...
}
```

## 📊 주요 SDK

### Alchemy Account Kit

```javascript
import { createModularAccountAlchemyClient } from '@alchemy/aa-alchemy';

const client = await createModularAccountAlchemyClient({
    apiKey: 'YOUR_API_KEY',
    chain: mainnet,
    signer: signer
});

const result = await client.sendUserOperation({
    target: recipient,
    data: '0x',
    value: ethers.utils.parseEther('0.1')
});
```

### ZeroDev

```javascript
import { ZeroDevProvider } from '@zerodev/sdk';

const provider = await ZeroDevProvider.init('projectId', {
    owner: signer
});

// ethers.js처럼 사용
const tx = await provider.sendTransaction({
    to: recipient,
    value: ethers.utils.parseEther('0.1')
});
```

### Biconomy

```javascript
import { BiconomySmartAccount } from '@biconomy/account';

const smartAccount = await BiconomySmartAccount.create({
    signer: signer,
    bundlerUrl: bundlerUrl,
    paymasterUrl: paymasterUrl
});

const userOp = await smartAccount.buildUserOp([
    { to: target, data: data }
]);

const response = await smartAccount.sendUserOp(userOp);
```

## 💡 일반적인 실수

### ❌ 실수 1: 서명 검증 누락

```solidity
// ❌ 위험
function validateUserOp(...) external override returns (uint256) {
    return 0;  // 누구나 사용 가능!
}

// ✅ 안전
function validateUserOp(...) external override returns (uint256) {
    bytes32 hash = userOpHash.toEthSignedMessageHash();
    address signer = hash.recover(userOp.signature);
    require(signer == owner, "Not owner");
    return 0;
}
```

### ❌ 실수 2: 가스비 미지불

```solidity
// ❌ 위험
function validateUserOp(...) external override returns (uint256) {
    // 서명 검증만 하고 가스비 미지불
    return 0;
}

// ✅ 안전
function validateUserOp(...) external override returns (uint256) {
    // 서명 검증...

    if (missingAccountFunds > 0) {
        (bool success,) = payable(msg.sender).call{
            value: missingAccountFunds
        }("");
        require(success);
    }

    return 0;
}
```

### ❌ 실수 3: initCode 오류

```javascript
// ❌ 틀림: 이미 배포된 계정에 initCode 포함
const userOp = {
    sender: existingAccountAddress,
    initCode: factoryData,  // 오류!
    // ...
};

// ✅ 맞음
const codeSize = await provider.getCode(accountAddress);
const userOp = {
    sender: accountAddress,
    initCode: codeSize === '0x' ? factoryData : '0x',
    // ...
};
```

## 📈 Gas 비용

```
일반 EOA 트랜잭션:  ~21,000 gas
Smart Account:       ~42,000 gas (+100%)

배치 트랜잭션 (3개):
- EOA:              ~63,000 gas (21,000 × 3)
- Smart Account:    ~50,000 gas (배치 실행으로 절약!)

Paymaster 사용:
- 사용자 가스비:    0 gas ✅
- DApp 가스비:      ~45,000 gas
```

## 🎓 사용 사례

```
✅ Safe (Gnosis Safe)  - 멀티시그 + AA
✅ Argent Wallet       - 소셜 복구
✅ Biconomy            - 가스리스 DApp
✅ ZeroDev             - 개발자 SDK
✅ Alchemy             - Account Kit
✅ Stackup             - Bundler 인프라
```

## 🔍 디버깅

### UserOperation 해시 계산

```javascript
const userOpHash = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
        [
            'address', 'uint256', 'bytes32', 'bytes32',
            'uint256', 'uint256', 'uint256',
            'uint256', 'uint256', 'bytes32',
            'address', 'uint256'
        ],
        [
            userOp.sender,
            userOp.nonce,
            ethers.utils.keccak256(userOp.initCode),
            ethers.utils.keccak256(userOp.callData),
            userOp.callGasLimit,
            userOp.verificationGasLimit,
            userOp.preVerificationGas,
            userOp.maxFeePerGas,
            userOp.maxPriorityFeePerGas,
            ethers.utils.keccak256(userOp.paymasterAndData),
            entryPointAddress,
            chainId
        ]
    )
);
```

### 계정 주소 검증

```javascript
// 예상 주소 계산
const predictedAddress = await factory.getAddress(owner, salt);

// 실제 배포 확인
const code = await provider.getCode(predictedAddress);
console.log('Deployed:', code !== '0x');

// CREATE2 검증
const computedAddress = ethers.utils.getCreate2Address(
    factory.address,
    salt,
    ethers.utils.keccak256(creationCode)
);
console.log('Address match:', predictedAddress === computedAddress);
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 가이드
- [EIP-4337 Spec](https://eips.ethereum.org/EIPS/eip-4337)
- [공식 사이트](https://www.erc4337.io/)
- [Alchemy Account Kit](https://accountkit.alchemy.com/)
- [ZeroDev Docs](https://docs.zerodev.app/)
- [Biconomy SDK](https://docs.biconomy.io/)
- [Stackup](https://www.stackup.sh/)

---

**핵심 요약:**

```
Account Abstraction = 스마트 컨트랙트를 계정으로 사용

구조:
→ User → UserOp → Bundler → EntryPoint → Smart Account

핵심 기능:
✅ 소셜 복구 (개인키 분실 복구)
✅ 가스리스 (Paymaster가 대신 지불)
✅ 배치 실행 (여러 트랜잭션 한 번에)
✅ 멀티시그 (여러 소유자)
✅ 세션 키 (승인 불필요)

EntryPoint v0.6:
0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
```

**마지막 업데이트: 2025**
