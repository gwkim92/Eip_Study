# EIP-4337: Account Abstraction (계정 추상화)

> **미래의 이더리움** - 스마트 컨트랙트 계정으로 트랜잭션 실행

## 📋 목차

- [개요](#개요)
- [문제점: EOA의 한계](#문제점-eoa의-한계)
- [해결책: Account Abstraction](#해결책-account-abstraction)
- [핵심 개념](#핵심-개념)
- [구조 및 작동 원리](#구조-및-작동-원리)
- [구현 방법](#구현-방법)
- [실전 예제](#실전-예제)
- [보안 고려사항](#보안-고려사항)
- [실제 사용 사례](#실제-사용-사례)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

## 개요

### EIP-4337이란?

**EIP-4337 (Account Abstraction)**은 스마트 컨트랙트를 계정으로 사용할 수 있게 해주는 표준입니다.

기존 이더리움에서는 트랜잭션을 시작하려면 반드시 **EOA (Externally Owned Account)**가 필요했지만, EIP-4337을 통해 스마트 컨트랙트 자체가 계정 역할을 할 수 있게 되었습니다.

### 왜 중요한가?

```
기존 (EOA):
❌ 개인키 분실 시 복구 불가
❌ 가스비는 반드시 ETH로 지불
❌ 트랜잭션 하나씩만 실행 가능
❌ 멀티시그 불가능
❌ 승인마다 서명 필요

EIP-4337 (Smart Account):
✅ 소셜 복구 가능
✅ 가스비를 ERC-20으로 지불 가능
✅ 배치 트랜잭션 실행
✅ 멀티시그 지원
✅ 세션 키로 편리한 DApp 사용
```

### 핵심 특징

1. **프로토콜 변경 없음**: 이더리움 프로토콜 자체를 변경하지 않고 구현
2. **EntryPoint 싱글톤**: 모든 Account Abstraction 동작을 처리하는 표준 컨트랙트
3. **Bundler**: UserOperation을 모아서 하나의 트랜잭션으로 실행
4. **Paymaster**: 가스비를 대신 지불해주는 스폰서 시스템
5. **유연한 검증**: 서명 방식을 자유롭게 커스터마이징

## 문제점: EOA의 한계

### EOA (Externally Owned Account)의 문제점

이더리움의 기존 계정 시스템인 EOA는 다음과 같은 한계가 있습니다:

#### 1. 개인키 관리의 어려움

```
문제: 개인키를 잃어버리면 계정을 영구적으로 잃음
→ 수십억 달러의 자산이 개인키 분실로 사라짐
```

#### 2. 가스비는 반드시 ETH

```solidity
// ❌ EOA는 항상 ETH로 가스비 지불
// 사용자가 USDC만 보유해도 ETH가 필요함
```

#### 3. 단일 서명

```
문제: 개인키 하나로만 계정 제어
→ 멀티시그, 소셜 복구 등 불가능
```

#### 4. 트랜잭션 하나씩만 실행

```javascript
// ❌ 각 동작마다 별도 트랜잭션 필요
await token.approve(spender, amount);  // Tx 1
await spender.deposit(amount);         // Tx 2
await spender.stake(amount);           // Tx 3
// → 3번의 서명, 3배의 가스비
```

#### 5. 서명 피로도

```
문제: DApp 사용할 때마다 지갑 팝업으로 서명
→ 게임, DeFi 등에서 매우 불편
```

### 실제 사례

**피해 사례:**
- 2021년, James Howells: 7,500 BTC (개인키 분실)
- 2022년, Stefan Thomas: 7,002 BTC (비밀번호 분실)
- 매년 수백만 달러가 개인키 분실로 손실

**사용자 경험 문제:**
- 평균 사용자는 메타마스크 사용법도 어려워함
- 가스비 개념 이해 어려움
- 실수로 잘못된 주소로 송금 시 복구 불가능

## 해결책: Account Abstraction

### Account Abstraction의 핵심 아이디어

**"계정을 스마트 컨트랙트로 만들자!"**

스마트 컨트랙트를 계정으로 사용하면, 계정의 로직을 자유롭게 프로그래밍할 수 있습니다.

```solidity
// 기존 EOA: 개인키 하나로만 제어
account = privateKey

// Account Abstraction: 프로그래밍 가능한 계정
contract SmartAccount {
    // 1. 멀티시그
    address[] public owners;

    // 2. 소셜 복구
    address[] public guardians;

    // 3. 세션 키
    mapping(address => SessionKey) public sessionKeys;

    // 4. 토큰으로 가스비 지불
    function payWithToken() external;

    // 5. 배치 실행
    function executeBatch(Call[] calldata calls) external;
}
```

### EIP-4337의 특징

#### 1. 프로토콜 변경 없음

```
기존 시도 (EIP-86, EIP-2938):
→ 이더리움 프로토콜 자체를 수정해야 함
→ 하드포크 필요, 합의 어려움

EIP-4337:
→ 기존 이더리움 위에서 동작
→ 스마트 컨트랙트로 구현
→ 지금 당장 사용 가능!
```

#### 2. UserOperation

트랜잭션 대신 **UserOperation**이라는 새로운 객체를 사용합니다.

```
EOA → Transaction → Blockchain

Smart Account → UserOperation → Bundler → EntryPoint → Blockchain
```

#### 3. Bundler (번들러)

여러 UserOperation을 모아서 하나의 트랜잭션으로 만드는 역할:

```
UserOp A ──┐
UserOp B ──┤→ Bundler → 하나의 Transaction → Blockchain
UserOp C ──┘
```

#### 4. Paymaster (가스 스폰서)

가스비를 대신 지불해주는 컨트랙트:

```solidity
contract Paymaster {
    // DApp이 사용자 대신 가스비 지불
    function validatePaymasterUserOp(...) external returns (bytes memory, uint256);
}
```

## 핵심 개념

### 1. UserOperation

트랜잭션을 대체하는 새로운 데이터 구조:

```solidity
struct UserOperation {
    address sender;              // 스마트 컨트랙트 계정 주소
    uint256 nonce;              // 재실행 방지
    bytes initCode;             // 계정 생성 코드 (없으면 빈 bytes)
    bytes callData;             // 실제 실행할 함수 호출
    uint256 callGasLimit;       // 실행에 사용할 가스
    uint256 verificationGasLimit; // 검증에 사용할 가스
    uint256 preVerificationGas; // Bundler 보상
    uint256 maxFeePerGas;       // EIP-1559 가스 가격
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;     // Paymaster 주소 + 데이터
    bytes signature;            // 서명
}
```

**각 필드 설명:**

- `sender`: 스마트 컨트랙트 계정 주소
- `nonce`: 트랜잭션 순서 보장 (재실행 공격 방지)
- `initCode`: 계정이 아직 배포되지 않았다면 배포 코드 포함
- `callData`: 계정에서 실행할 함수 호출 데이터
- `callGasLimit`: 실행에 필요한 가스 한도
- `verificationGasLimit`: 서명 검증에 필요한 가스
- `preVerificationGas`: Bundler가 UserOp를 처리하는 비용
- `maxFeePerGas` / `maxPriorityFeePerGas`: EIP-1559 가스 가격
- `paymasterAndData`: Paymaster 주소 (20 bytes) + 추가 데이터
- `signature`: 계정이 검증할 서명

### 2. EntryPoint

모든 UserOperation을 처리하는 싱글톤 컨트랙트:

```solidity
interface IEntryPoint {
    // Bundler가 UserOperation 배치를 제출
    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) external;

    // 계정의 nonce 조회
    function getNonce(address sender, uint192 key) external view returns (uint256);
}
```

**EntryPoint의 역할:**

1. UserOperation 검증
2. 계정의 `validateUserOp` 호출
3. Paymaster 검증 (있다면)
4. 가스비 선불 확인
5. 실제 호출 실행
6. 가스비 정산

**EntryPoint 주소 (v0.6):**
```
0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
```

### 3. Smart Account (IAccount)

스마트 컨트랙트 계정이 구현해야 하는 인터페이스:

```solidity
interface IAccount {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}
```

**validateUserOp의 역할:**

1. 서명 검증
2. Nonce 확인
3. 가스비 지불
4. 반환값:
   - `0`: 검증 성공
   - `1`: 검증 실패
   - `SIG_VALIDATION_FAILED`: 서명 실패

### 4. Bundler

UserOperation을 수집하고 EntryPoint에 제출하는 오프체인 서비스:

```
사용자 A → UserOp A ──┐
사용자 B → UserOp B ──┤
사용자 C → UserOp C ──┤→ Bundler → EntryPoint.handleOps([A,B,C])
```

**Bundler의 역할:**

1. UserOperation 수집 (멤풀)
2. 시뮬레이션으로 실행 가능성 검증
3. 가스비 충분한지 확인
4. 여러 UserOp를 하나의 트랜잭션으로 번들링
5. EntryPoint에 제출

**Bundler 구현:**
- Stackup
- Alchemy Rundler
- Skandha
- Infinitism (공식 참조 구현)

### 5. Paymaster

가스비를 대신 지불해주는 컨트랙트:

```solidity
interface IPaymaster {
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external;
}
```

**Paymaster 종류:**

1. **Verifying Paymaster**: 특정 조건 확인 후 지불
2. **Token Paymaster**: ERC-20 토큰으로 가스비 받고 ETH로 지불
3. **Sponsoring Paymaster**: DApp이 무조건 지불

### 6. Account Factory

스마트 컨트랙트 계정을 생성하는 팩토리:

```solidity
contract AccountFactory {
    function createAccount(address owner, uint256 salt)
        external
        returns (SimpleAccount);
}
```

**CREATE2 사용:**
- 계정 주소를 사전에 계산 가능
- 계정이 없어도 주소로 입금 가능
- 첫 UserOperation에서 계정 생성 + 실행 동시에

## 구조 및 작동 원리

### 전체 구조

```
┌──────────┐
│   User   │ (EOA 소유자)
└─────┬────┘
      │ 1. UserOp 생성 & 서명
      ↓
┌─────────────┐
│   Bundler   │ (오프체인)
└──────┬──────┘
       │ 2. UserOps 수집 & 번들링
       ↓
┌──────────────┐
│  EntryPoint  │ (온체인 싱글톤)
└──────┬───────┘
       │ 3. handleOps() 호출
       ↓
┌────────────────┐
│ Smart Account  │ (사용자의 컨트랙트 계정)
│ + Paymaster    │ (선택)
└────────────────┘
```

### 실행 흐름

#### 1. UserOperation 생성

```javascript
// 사용자가 UserOperation 생성
const userOp = {
    sender: '0xSmartAccountAddress',
    nonce: await entryPoint.getNonce(smartAccount, 0),
    initCode: '0x',  // 이미 배포됨
    callData: smartAccount.interface.encodeFunctionData('execute', [
        target,
        value,
        data
    ]),
    callGasLimit: 100000,
    verificationGasLimit: 100000,
    preVerificationGas: 21000,
    maxFeePerGas: await provider.getGasPrice(),
    maxPriorityFeePerGas: 1000000000,
    paymasterAndData: '0x',
    signature: '0x'  // 아직 서명 안 함
};

// 서명
const userOpHash = await entryPoint.getUserOpHash(userOp);
const signature = await signer.signMessage(ethers.utils.arrayify(userOpHash));
userOp.signature = signature;

// Bundler에게 제출
await bundlerProvider.sendUserOperation(userOp);
```

#### 2. Bundler 처리

```javascript
// Bundler의 처리 과정
class Bundler {
    async processUserOp(userOp) {
        // 1. 시뮬레이션
        const simulationResult = await this.simulate(userOp);
        if (!simulationResult.success) {
            throw new Error('Simulation failed');
        }

        // 2. 멤풀에 추가
        this.mempool.push(userOp);

        // 3. 충분한 UserOps가 모이면 번들링
        if (this.mempool.length >= 10) {
            await this.bundle();
        }
    }

    async bundle() {
        const userOps = this.mempool.splice(0, 10);

        // EntryPoint.handleOps() 호출
        const tx = await this.entryPoint.handleOps(
            userOps,
            this.beneficiary  // Bundler의 수익 주소
        );

        await tx.wait();
    }
}
```

#### 3. EntryPoint 실행

EntryPoint의 `handleOps` 함수 실행 순서:

```solidity
contract EntryPoint {
    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) external {
        for (uint256 i = 0; i < ops.length; i++) {
            UserOperation calldata op = ops[i];

            // 1단계: 검증
            uint256 validationData = _validatePrepayment(op);
            require(validationData == 0, "Validation failed");

            // 2단계: 실행
            _executeUserOp(op);

            // 3단계: 가스비 정산
            _postExecution(op);
        }

        // Bundler에게 보상
        beneficiary.transfer(totalFee);
    }

    function _validatePrepayment(UserOperation calldata op)
        internal
        returns (uint256)
    {
        // 1. 계정 배포 (initCode가 있다면)
        if (op.initCode.length > 0) {
            _createAccount(op.initCode);
        }

        // 2. 가스비 계산
        uint256 requiredPrefund = op.callGasLimit +
                                   op.verificationGasLimit +
                                   op.preVerificationGas;
        requiredPrefund *= op.maxFeePerGas;

        // 3. Paymaster 검증 (있다면)
        if (op.paymasterAndData.length > 0) {
            address paymaster = address(bytes20(op.paymasterAndData[0:20]));
            IPaymaster(paymaster).validatePaymasterUserOp(
                op,
                getUserOpHash(op),
                requiredPrefund
            );
        }

        // 4. 계정 검증
        uint256 missingAccountFunds = requiredPrefund;
        uint256 validationData = IAccount(op.sender).validateUserOp(
            op,
            getUserOpHash(op),
            missingAccountFunds
        );

        return validationData;
    }

    function _executeUserOp(UserOperation calldata op) internal {
        // 계정의 callData 실행
        (bool success, bytes memory result) = op.sender.call(op.callData);

        if (!success) {
            // 실패해도 가스비는 부과
            emit UserOperationRevertReason(
                getUserOpHash(op),
                op.sender,
                result
            );
        }
    }
}
```

#### 4. Smart Account 검증

```solidity
contract SimpleAccount is IAccount {
    address public owner;
    IEntryPoint private immutable _entryPoint;

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        // EntryPoint만 호출 가능
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        // 1. 서명 검증
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        if (signer != owner) {
            return SIG_VALIDATION_FAILED;  // 1
        }

        // 2. 가스비 지불
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{
                value: missingAccountFunds
            }("");
            require(success, "Failed to pay");
        }

        return 0;  // 검증 성공
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
    {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
```

### 계정이 없을 때: initCode

사용자가 아직 계정이 없다면, `initCode`로 계정 생성:

```javascript
// 1. 계정 주소 사전 계산 (CREATE2)
const accountFactory = new ethers.Contract(factoryAddress, factoryABI, provider);
const predictedAddress = await accountFactory.getAddress(owner, salt);

// 2. initCode 생성
const initCode = ethers.utils.concat([
    accountFactory.address,
    accountFactory.interface.encodeFunctionData('createAccount', [owner, salt])
]);

// 3. UserOp에 포함
const userOp = {
    sender: predictedAddress,  // 아직 배포 안 됨
    initCode: initCode,        // EntryPoint가 실행하여 계정 생성
    // ...
};

// 4. 첫 UserOp 실행 시 자동으로 계정 생성 + 트랜잭션 실행
```

## 구현 방법

### 1. 기본 Smart Account 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAccount.sol";
import "./IEntryPoint.sol";

contract SimpleAccount is IAccount {
    address public owner;
    IEntryPoint private immutable _entryPoint;

    event AccountExecuted(address indexed target, uint256 value, bytes data);

    constructor(IEntryPoint entryPoint_, address owner_) {
        _entryPoint = entryPoint_;
        owner = owner_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");
        _;
    }

    // IAccount 인터페이스 구현
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
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
            require(success, "Failed to pay for gas");
        }

        return 0;  // 검증 성공
    }

    // 단일 호출 실행
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPoint {
        _call(target, value, data);
    }

    // 배치 실행
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external onlyEntryPoint {
        require(
            targets.length == values.length &&
            targets.length == datas.length,
            "Length mismatch"
        );

        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], datas[i]);
        }
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        emit AccountExecuted(target, value, data);
    }

    function entryPoint() public view returns (IEntryPoint) {
        return _entryPoint;
    }

    receive() external payable {}
}
```

### 2. Account Factory 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SimpleAccount.sol";

contract AccountFactory {
    IEntryPoint public immutable entryPoint;

    event AccountCreated(address indexed account, address indexed owner);

    constructor(IEntryPoint entryPoint_) {
        entryPoint = entryPoint_;
    }

    // CREATE2로 계정 생성
    function createAccount(address owner, uint256 salt)
        external
        returns (SimpleAccount)
    {
        address addr = getAddress(owner, salt);

        // 이미 배포됐으면 반환
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SimpleAccount(payable(addr));
        }

        // 배포
        SimpleAccount account = new SimpleAccount{salt: bytes32(salt)}(
            entryPoint,
            owner
        );

        emit AccountCreated(address(account), owner);
        return account;
    }

    // 계정 주소 사전 계산
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

### 3. Paymaster 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IPaymaster.sol";
import "./IEntryPoint.sol";

// 간단한 Sponsoring Paymaster
contract SimplePaymaster is IPaymaster {
    IEntryPoint public immutable entryPoint;
    address public owner;

    mapping(address => bool) public allowedAccounts;

    event PaymasterDeposited(uint256 amount);
    event AccountAllowed(address indexed account);

    constructor(IEntryPoint entryPoint_) {
        entryPoint = entryPoint_;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // 특정 계정 허용
    function allowAccount(address account) external onlyOwner {
        allowedAccounts[account] = true;
        emit AccountAllowed(account);
    }

    // Paymaster 검증
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Not EntryPoint");

        // 허용된 계정만 스폰서
        require(allowedAccounts[userOp.sender], "Account not allowed");

        // 충분한 잔고 확인
        uint256 balance = entryPoint.balanceOf(address(this));
        require(balance >= maxCost, "Insufficient balance");

        return ("", 0);  // 검증 성공
    }

    // 실행 후 처리 (선택)
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external override {
        // 필요시 추가 로직
    }

    // Paymaster에 입금
    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
        emit PaymasterDeposited(msg.value);
    }

    // Paymaster에서 출금
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(to, amount);
    }

    receive() external payable {
        deposit();
    }
}
```

### 4. Token Paymaster (ERC-20으로 가스비)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IPaymaster.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenPaymaster is IPaymaster {
    IEntryPoint public immutable entryPoint;
    IERC20 public immutable token;  // 받을 토큰 (예: USDC)
    AggregatorV3Interface public immutable priceFeed;  // ETH/USDC 가격

    uint256 public constant PRICE_DENOMINATOR = 1e18;

    constructor(
        IEntryPoint entryPoint_,
        IERC20 token_,
        AggregatorV3Interface priceFeed_
    ) {
        entryPoint = entryPoint_;
        token = token_;
        priceFeed = priceFeed_;
    }

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Not EntryPoint");

        // 1. ETH 가스비를 토큰 가격으로 변환
        uint256 tokenAmount = _ethToToken(maxCost);

        // 2. 사용자가 충분한 토큰 보유 확인
        require(
            token.balanceOf(userOp.sender) >= tokenAmount,
            "Insufficient token balance"
        );

        // 3. Paymaster가 사용자의 토큰을 가져올 수 있는지 확인
        require(
            token.allowance(userOp.sender, address(this)) >= tokenAmount,
            "Insufficient token allowance"
        );

        // context에 토큰 금액 저장
        return (abi.encode(userOp.sender, tokenAmount), 0);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external override {
        (address sender, uint256 maxTokenAmount) = abi.decode(
            context,
            (address, uint256)
        );

        // 실제 사용한 가스비 계산
        uint256 actualTokenAmount = _ethToToken(actualGasCost);

        // 사용자에게서 토큰 가져오기
        require(
            token.transferFrom(sender, address(this), actualTokenAmount),
            "Token transfer failed"
        );
    }

    function _ethToToken(uint256 ethAmount) internal view returns (uint256) {
        // Chainlink Price Feed에서 ETH/USDC 가격 조회
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");

        // 가격 변환 (예: 1 ETH = 2000 USDC)
        return (ethAmount * uint256(price)) / PRICE_DENOMINATOR;
    }

    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }
}
```

### 5. MultiSig Account 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAccount.sol";

contract MultiSigAccount is IAccount {
    IEntryPoint private immutable _entryPoint;

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredSignatures;

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    constructor(
        IEntryPoint entryPoint_,
        address[] memory owners_,
        uint256 requiredSignatures_
    ) {
        require(
            owners_.length >= requiredSignatures_,
            "Invalid signatures requirement"
        );
        require(requiredSignatures_ > 0, "Required > 0");

        _entryPoint = entryPoint_;
        requiredSignatures = requiredSignatures_;

        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        // 다중 서명 검증
        if (!_validateSignatures(userOpHash, userOp.signature)) {
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

    function _validateSignatures(bytes32 hash, bytes memory signatures)
        internal
        view
        returns (bool)
    {
        require(
            signatures.length == requiredSignatures * 65,
            "Invalid signatures length"
        );

        bytes32 ethSignedHash = hash.toEthSignedMessageHash();
        address[] memory signers = new address[](requiredSignatures);

        for (uint256 i = 0; i < requiredSignatures; i++) {
            // 서명 추출
            bytes memory sig = new bytes(65);
            for (uint256 j = 0; j < 65; j++) {
                sig[j] = signatures[i * 65 + j];
            }

            address signer = ethSignedHash.recover(sig);

            // 소유자 확인
            if (!isOwner[signer]) {
                return false;
            }

            // 중복 확인
            for (uint256 j = 0; j < i; j++) {
                if (signers[j] == signer) {
                    return false;
                }
            }

            signers[i] = signer;
        }

        return true;
    }

    receive() external payable {}
}
```

### 6. Session Key Account 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAccount.sol";

contract SessionKeyAccount is IAccount {
    IEntryPoint private immutable _entryPoint;
    address public mainOwner;

    struct SessionKey {
        address key;
        uint256 validUntil;
        uint256 gasLimit;
        address[] allowedTargets;
    }

    mapping(address => SessionKey) public sessionKeys;

    event SessionKeyAdded(address indexed key, uint256 validUntil);
    event SessionKeyRevoked(address indexed key);

    constructor(IEntryPoint entryPoint_, address mainOwner_) {
        _entryPoint = entryPoint_;
        mainOwner = mainOwner_;
    }

    // 세션 키 추가 (mainOwner만)
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

        emit SessionKeyAdded(key, validUntil);
    }

    // 세션 키 취소
    function revokeSessionKey(address key) external {
        require(msg.sender == mainOwner, "Not main owner");
        delete sessionKeys[key];
        emit SessionKeyRevoked(key);
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        // 메인 소유자 확인
        if (signer == mainOwner) {
            if (missingAccountFunds > 0) {
                (bool success,) = payable(msg.sender).call{
                    value: missingAccountFunds
                }("");
                require(success, "Failed to pay");
            }
            return 0;
        }

        // 세션 키 확인
        SessionKey memory session = sessionKeys[signer];

        if (session.key == address(0)) {
            return 1;  // 유효하지 않은 세션 키
        }

        if (block.timestamp > session.validUntil) {
            return 1;  // 만료된 세션 키
        }

        if (userOp.callGasLimit > session.gasLimit) {
            return 1;  // 가스 한도 초과
        }

        // 가스비 지불
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{
                value: missingAccountFunds
            }("");
            require(success, "Failed to pay");
        }

        return 0;
    }

    receive() external payable {}
}
```

## 실전 예제

### 1. 기본 사용 (ethers.js + SDK)

```javascript
import { Presets, Client } from 'userop';
import { ethers } from 'ethers';

// 1. Bundler Provider 설정
const bundlerRPC = 'https://api.stackup.sh/v1/node/YOUR_API_KEY';
const paymasterRPC = 'https://api.stackup.sh/v1/paymaster/YOUR_API_KEY';

// 2. EOA Signer (소유자)
const signer = new ethers.Wallet(privateKey);

// 3. Simple Account 빌더
const simpleAccount = await Presets.Builder.SimpleAccount.init(
    signer,
    bundlerRPC,
    {
        paymasterMiddleware: paymasterRPC ? Presets.Middleware.verifyingPaymaster(
            paymasterRPC,
            { type: 'payg' }
        ) : undefined
    }
);

const client = await Client.init(bundlerRPC);

// 4. UserOperation 실행
const res = await client.sendUserOperation(
    simpleAccount.execute(
        targetAddress,
        ethers.utils.parseEther('0.1'),
        '0x'  // calldata
    ),
    {
        onBuild: (op) => console.log('UserOp built:', op)
    }
);

// 5. 결과 확인
const event = await res.wait();
console.log('UserOp executed:', event);
console.log('Transaction hash:', event.transactionHash);
```

### 2. 배치 트랜잭션

```javascript
import { ethers } from 'ethers';

// ERC-20 토큰 approve + transfer를 한 번에
const token = new ethers.Contract(tokenAddress, ERC20_ABI, provider);

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

// 한 번의 UserOperation으로 3개 호출
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
    nonce: await entryPoint.getNonce(smartAccount.address, 0),
    initCode: '0x',
    callData: callData,
    // ...
};

const result = await client.sendUserOperation(userOp);
// → 한 번의 서명, 한 번의 트랜잭션
```

### 3. Paymaster로 가스리스 트랜잭션

```javascript
// 사용자는 ETH가 없어도 됨!
const userOp = {
    sender: smartAccount.address,
    nonce: await entryPoint.getNonce(smartAccount.address, 0),
    initCode: '0x',
    callData: callData,
    callGasLimit: 100000,
    verificationGasLimit: 100000,
    preVerificationGas: 21000,
    maxFeePerGas: await provider.getGasPrice(),
    maxPriorityFeePerGas: 1000000000,

    // Paymaster 정보 추가
    paymasterAndData: ethers.utils.concat([
        paymasterAddress,
        '0x'  // 추가 데이터 (필요시)
    ]),

    signature: '0x'
};

// 서명
const userOpHash = await entryPoint.getUserOpHash(userOp);
const signature = await signer.signMessage(ethers.utils.arrayify(userOpHash));
userOp.signature = signature;

// Bundler에 제출
// → DApp이 가스비 지불!
const result = await client.sendUserOperation(userOp);
```

### 4. 세션 키로 게임 플레이

```javascript
// 1. 메인 소유자가 세션 키 생성
const sessionKey = ethers.Wallet.createRandom();

// 2. 세션 키 등록
const addSessionKeyCall = smartAccount.interface.encodeFunctionData(
    'addSessionKey',
    [
        sessionKey.address,
        Math.floor(Date.now() / 1000) + 86400,  // 24시간
        500000,  // 가스 한도
        [gameContract.address]  // 게임 컨트랙트만 호출 가능
    ]
);

await executeUserOp(mainOwner, addSessionKeyCall);

// 3. 이제 게임에서 세션 키로 서명
// → 메인 소유자 서명 불필요!
async function playGame(action) {
    const callData = smartAccount.interface.encodeFunctionData('execute', [
        gameContract.address,
        0,
        gameContract.interface.encodeFunctionData('play', [action])
    ]);

    const userOp = buildUserOp(smartAccount.address, callData);

    // 세션 키로 서명
    const userOpHash = await entryPoint.getUserOpHash(userOp);
    const signature = await sessionKey.signMessage(
        ethers.utils.arrayify(userOpHash)
    );
    userOp.signature = signature;

    await client.sendUserOperation(userOp);
    // → 빠르고 편리한 게임 플레이!
}

// 4. 게임 종료 후 세션 키 취소
const revokeCall = smartAccount.interface.encodeFunctionData(
    'revokeSessionKey',
    [sessionKey.address]
);

await executeUserOp(mainOwner, revokeCall);
```

### 5. 소셜 복구 (Social Recovery)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

    event RecoveryInitiated(uint256 indexed nonce, address indexed newOwner);
    event RecoveryApproved(uint256 indexed nonce, address indexed guardian);
    event RecoveryExecuted(uint256 indexed nonce, address indexed newOwner);

    constructor(
        address owner_,
        address[] memory guardians_,
        uint256 requiredApprovals_
    ) {
        owner = owner_;
        requiredApprovals = requiredApprovals_;

        for (uint256 i = 0; i < guardians_.length; i++) {
            guardians.push(guardians_[i]);
            isGuardian[guardians_[i]] = true;
        }
    }

    // 1. 복구 시작 (Guardian이 호출)
    function initiateRecovery(address newOwner) external {
        require(isGuardian[msg.sender], "Not guardian");
        require(newOwner != address(0), "Invalid owner");

        recoveryNonce++;
        Recovery storage recovery = recoveries[recoveryNonce];
        recovery.newOwner = newOwner;
        recovery.approvalCount = 1;
        recovery.approved[msg.sender] = true;

        emit RecoveryInitiated(recoveryNonce, newOwner);
    }

    // 2. 복구 승인 (다른 Guardian들이 호출)
    function approveRecovery(uint256 nonce) external {
        require(isGuardian[msg.sender], "Not guardian");

        Recovery storage recovery = recoveries[nonce];
        require(recovery.newOwner != address(0), "No recovery");
        require(!recovery.approved[msg.sender], "Already approved");

        recovery.approved[msg.sender] = true;
        recovery.approvalCount++;

        emit RecoveryApproved(nonce, msg.sender);

        // 3. 충분한 승인이 모이면 자동 실행
        if (recovery.approvalCount >= requiredApprovals) {
            address newOwner = recovery.newOwner;
            owner = newOwner;
            delete recoveries[nonce];

            emit RecoveryExecuted(nonce, newOwner);
        }
    }
}
```

사용 예제:

```javascript
// Alice의 스마트 계정
// 소유자: Alice
// Guardians: Bob, Charlie, Dave (2-of-3 필요)

// 1. Alice가 개인키를 잃어버림 😱

// 2. Bob이 복구 시작
const recoverableAccount = new ethers.Contract(
    aliceAccountAddress,
    RecoverableAccountABI,
    bobSigner
);

await recoverableAccount.initiateRecovery(aliceNewAddress);
// → Recovery #1 시작

// 3. Charlie가 승인
await recoverableAccount.connect(charlieSigner).approveRecovery(1);
// → 2-of-3 달성, Alice의 소유자 자동 변경!

// 4. Alice는 새로운 개인키로 계정 복구 ✅
```

## 보안 고려사항

### 1. 서명 검증 철저히

```solidity
// ❌ 위험: 서명 검증 부족
function validateUserOp(...) external override returns (uint256) {
    // 서명 확인 없이 통과
    return 0;  // 누구나 계정 사용 가능!
}

// ✅ 안전: 철저한 검증
function validateUserOp(
    UserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
) external override returns (uint256) {
    // 1. EntryPoint 확인
    require(msg.sender == address(_entryPoint), "Not EntryPoint");

    // 2. 서명 검증
    bytes32 hash = userOpHash.toEthSignedMessageHash();
    address signer = hash.recover(userOp.signature);

    require(signer != address(0), "Invalid signature");
    require(signer == owner, "Not owner");

    // 3. 가스비 지불
    if (missingAccountFunds > 0) {
        (bool success,) = payable(msg.sender).call{
            value: missingAccountFunds
        }("");
        require(success, "Failed to pay");
    }

    return 0;
}
```

### 2. Nonce 관리

```solidity
// EIP-4337은 2D Nonce 사용
// - key: 병렬 트랜잭션을 위한 키 (192 bits)
// - sequence: 순차 번호 (64 bits)

// ✅ Nonce 재사용 방지
function validateUserOp(...) external override returns (uint256) {
    uint256 currentNonce = _entryPoint.getNonce(address(this), nonceKey);
    require(userOp.nonce == currentNonce, "Invalid nonce");

    // ...
}

// ✅ 병렬 트랜잭션 지원
// key = 0: 일반 트랜잭션
// key = 1: 긴급 트랜잭션
// → 독립적으로 nonce 관리
```

### 3. 재진입 공격 방지

```solidity
// ❌ 위험: 재진입 가능
function execute(address target, uint256 value, bytes calldata data)
    external
{
    (bool success,) = target.call{value: value}(data);
    require(success);
}

// ✅ 안전: ReentrancyGuard 사용
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SafeAccount is IAccount, ReentrancyGuard {
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyEntryPoint
        nonReentrant  // 재진입 방지
    {
        (bool success,) = target.call{value: value}(data);
        require(success);
    }
}
```

### 4. Paymaster 악용 방지

```solidity
// ❌ 위험: 무제한 스폰서
contract BadPaymaster is IPaymaster {
    function validatePaymasterUserOp(...)
        external
        override
        returns (bytes memory, uint256)
    {
        return ("", 0);  // 모든 UserOp 승인!
    }
}

// ✅ 안전: 조건 확인
contract SafePaymaster is IPaymaster {
    mapping(address => bool) public allowedAccounts;
    mapping(address => uint256) public dailyLimit;
    mapping(address => uint256) public usedToday;

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory, uint256) {
        // 1. 허용된 계정만
        require(allowedAccounts[userOp.sender], "Not allowed");

        // 2. 일일 한도 확인
        require(
            usedToday[userOp.sender] + maxCost <= dailyLimit[userOp.sender],
            "Daily limit exceeded"
        );

        usedToday[userOp.sender] += maxCost;

        return ("", 0);
    }
}
```

### 5. 가스 한도 설정

```javascript
// ❌ 위험: 무제한 가스
const userOp = {
    // ...
    callGasLimit: 10000000,  // 너무 높음!
    verificationGasLimit: 10000000
};

// ✅ 안전: 적절한 한도
const userOp = {
    // ...
    callGasLimit: 100000,      // 실제 필요량
    verificationGasLimit: 100000,
    preVerificationGas: 21000
};

// Bundler가 시뮬레이션하여 적절한 가스 추정
const estimated = await bundler.estimateUserOperationGas(userOp);
userOp.callGasLimit = estimated.callGasLimit;
userOp.verificationGasLimit = estimated.verificationGasLimit;
```

### 6. 시뮬레이션 검증

Bundler는 UserOperation을 제출하기 전에 반드시 시뮬레이션해야 합니다:

```javascript
// Bundler 시뮬레이션
async function simulateUserOp(userOp) {
    try {
        // 1. 정적 호출로 시뮬레이션
        const result = await entryPoint.callStatic.simulateValidation(userOp);

        // 2. 금지된 opcode 사용 확인
        // - TIMESTAMP, BLOCKHASH 등 제한
        // - 외부 스토리지 접근 제한

        // 3. 가스 사용량 확인
        if (result.preOpGas > MAX_VERIFICATION_GAS) {
            throw new Error('Verification gas too high');
        }

        return true;
    } catch (error) {
        console.error('Simulation failed:', error);
        return false;
    }
}
```

### 7. 업그레이드 가능성 고려

```solidity
// ✅ UUPS 프록시 패턴 사용
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeableAccount is IAccount, UUPSUpgradeable {
    address public owner;

    function initialize(address owner_) external initializer {
        owner = owner_;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // → 버그 수정 가능, 새 기능 추가 가능
}
```

## 실제 사용 사례

### 1. Safe (Gnosis Safe) + EIP-4337

Safe는 가장 인기있는 멀티시그 지갑으로, EIP-4337을 통합했습니다.

```
Safe + EIP-4337:
→ 멀티시그 + Account Abstraction
→ 소셜 복구
→ Paymaster로 가스리스
→ 배치 트랜잭션
```

**사용 예:**
```javascript
import { Safe4337Pack } from '@safe-global/relay-kit';

const safe4337Pack = await Safe4337Pack.init({
    provider: rpcUrl,
    signer: signer,
    bundlerUrl: bundlerUrl,
    paymasterUrl: paymasterUrl,
    safeAddress: safeAddress
});

// 배치 실행
const userOps = await safe4337Pack.createTransaction({
    transactions: [
        { to: token, data: approveData },
        { to: spender, data: depositData }
    ]
});

await safe4337Pack.executeTransaction({ executable: userOps });
```

### 2. Argent Wallet

모바일 중심의 스마트 컨트랙트 지갑:

```
Argent 기능:
→ 이메일/소셜 로그인
→ 소셜 복구 (친구가 Guardian)
→ 일일 한도 설정
→ 승인 불필요한 거래
→ 가스리스 트랜잭션
```

### 3. Biconomy

Account Abstraction SDK 및 인프라 제공:

```javascript
import { BiconomySmartAccount } from '@biconomy/account';

const smartAccount = await BiconomySmartAccount.create({
    signer: signer,
    bundlerUrl: bundlerUrl,
    paymasterUrl: paymasterUrl
});

// 가스리스 트랜잭션
const userOp = await smartAccount.buildUserOp([
    { to: target, data: data }
]);

const response = await smartAccount.sendUserOp(userOp);
```

### 4. ZeroDev

개발자 친화적인 Account Abstraction SDK:

```javascript
import { ZeroDevProvider } from '@zerodev/sdk';

const provider = await ZeroDevProvider.init('projectId', {
    owner: signer
});

// 일반 ethers.js처럼 사용
const tx = await provider.sendTransaction({
    to: recipient,
    value: ethers.utils.parseEther('0.1')
});
// → 내부적으로 UserOperation 처리
```

### 5. Alchemy Account Kit

Alchemy가 제공하는 Account Abstraction 인프라:

```javascript
import {
    createModularAccountAlchemyClient
} from '@alchemy/aa-alchemy';

const client = await createModularAccountAlchemyClient({
    apiKey: 'YOUR_API_KEY',
    chain: mainnet,
    signer: signer
});

// Light Account 사용
const result = await client.sendUserOperation({
    target: recipient,
    data: '0x',
    value: ethers.utils.parseEther('0.1')
});
```

## FAQ

### Q1: EIP-4337과 EIP-2938의 차이는?

**A:**
- **EIP-2938**: 프로토콜 레벨 변경 (하드포크 필요)
- **EIP-4337**: 스마트 컨트랙트로 구현 (지금 사용 가능)

EIP-4337은 이더리움 프로토콜을 변경하지 않고도 Account Abstraction을 구현합니다.

### Q2: 기존 EOA에서 Smart Account로 마이그레이션 가능한가?

**A:** 직접적인 마이그레이션은 불가능하지만, 다음 방법을 사용할 수 있습니다:

```javascript
// 1. Smart Account 생성
const smartAccount = await accountFactory.createAccount(eoaAddress, salt);

// 2. EOA에서 Smart Account로 자산 이동
await erc20.connect(eoaSigner).transfer(smartAccount.address, balance);

// 3. 이후 Smart Account 사용
```

### Q3: 가스비는 누가 지불하나?

**A:** 3가지 옵션:
1. **계정 자체**: 계정에 ETH 보유
2. **Paymaster**: DApp이나 스폰서가 대신 지불
3. **Token Paymaster**: ERC-20 토큰으로 지불

### Q4: 모든 DApp에서 사용 가능한가?

**A:** 네! Smart Account도 일반 주소처럼 작동합니다:

```javascript
// DApp 입장에서는 차이 없음
const balance = await token.balanceOf(smartAccountAddress);
await nft.transferFrom(from, smartAccountAddress, tokenId);

// Smart Account가 받은 후 내부에서 처리
```

### Q5: EntryPoint를 여러 개 사용할 수 있나?

**A:** 가능하지만, 표준 EntryPoint (v0.6) 사용을 권장합니다:

```
표준 EntryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
→ 모든 지갑과 호환
→ Bundler 인프라 공유
```

### Q6: 보안은 안전한가?

**A:**
- **장점**: EOA의 단일 실패 지점 제거
- **주의**: 스마트 컨트랙트 버그 가능성
- **권장**: 감사받은 구현 사용 (OpenZeppelin, Safe 등)

```solidity
// ✅ 감사받은 구현 사용
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts-upgradeable/...";
```

### Q7: Bundler는 신뢰해도 되나?

**A:** Bundler는 신뢰가 필요 없습니다 (Trustless):

```
Bundler가 할 수 있는 것:
✅ UserOperation 제출
✅ 순서 변경

Bundler가 할 수 없는 것:
❌ 서명 위조
❌ 계정 자금 탈취
❌ 검증 우회

→ EntryPoint가 모든 검증 수행
```

### Q8: 비용이 얼마나 더 드나?

**A:**
```
일반 EOA 트랜잭션: ~21,000 gas
Smart Account:      ~42,000 gas (약 2배)

But:
✅ 배치 실행으로 절약
✅ Paymaster로 사용자는 0원
✅ 편의성 >> 비용
```

### Q9: 계정 주소를 미리 알 수 있나?

**A:** 네! CREATE2 사용:

```javascript
// Factory로 주소 계산
const predictedAddress = await factory.getAddress(owner, salt);

// 아직 배포 안 됨
console.log(await provider.getCode(predictedAddress));  // '0x'

// 미리 입금 가능
await token.transfer(predictedAddress, amount);

// 첫 UserOperation에서 배포 + 실행
```

### Q10: 업그레이드는 어떻게?

**A:** Proxy 패턴 사용:

```
User ─→ Proxy Account ─→ Implementation V1
                      ↓
                      └─→ Implementation V2 (업그레이드)

→ 주소 불변
→ 버그 수정 가능
→ 새 기능 추가 가능
```

## 참고 자료

### 공식 문서
- [EIP-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [Account Abstraction 공식 사이트](https://www.erc4337.io/)
- [Ethereum Foundation 가이드](https://ethereum.org/en/roadmap/account-abstraction/)

### SDK 및 도구
- [Alchemy Account Kit](https://accountkit.alchemy.com/)
- [ZeroDev SDK](https://docs.zerodev.app/)
- [Biconomy SDK](https://docs.biconomy.io/)
- [userop](https://github.com/stackup-wallet/userop)

### Bundler
- [Stackup Bundler](https://www.stackup.sh/)
- [Alchemy Rundler](https://github.com/alchemyplatform/rundler)
- [Skandha](https://github.com/etherspot/skandha)
- [Infinitism Bundler](https://github.com/eth-infinitism/bundler)

### 구현 예제
- [eth-infinitism/account-abstraction](https://github.com/eth-infinitism/account-abstraction)
- [Safe Modules](https://github.com/safe-global/safe-modules)
- [OpenZeppelin Account Abstraction](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/account)

### 튜토리얼
- [EIP-4337 Deep Dive](https://www.alchemy.com/blog/account-abstraction)
- [Building with Account Abstraction](https://docs.zerodev.app/build-with-zerodev)
- [Stackup Guides](https://docs.stackup.sh/docs)

### 블로그 & 아티클
- [Vitalik: The Road to Account Abstraction](https://notes.ethereum.org/@vbuterin/account_abstraction_roadmap)
- [Account Abstraction 완전정복 (한글)](https://medium.com/decipher-media/account-abstraction-완전정복-1-eip-4337-소개-4b9b3b2f7e5d)

---

**작성일**: 2025년 1월
**EIP 상태**: Final
**사용 가능 여부**: ✅ 현재 사용 가능 (v0.6)

Account Abstraction은 이더리움 사용자 경험을 혁신적으로 개선할 핵심 기술입니다! 🚀
