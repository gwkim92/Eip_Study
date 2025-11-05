# EIP-7702: Set EOA Account Code (EOA 코드 위임)

> **EOA의 진화** - 기존 계정을 스마트 컨트랙트처럼 사용하기

## 📋 목차

- [개요](#개요)
- [문제점: EOA의 한계](#문제점-eoa의-한계)
- [해결책: EOA 코드 위임](#해결책-eoa-코드-위임)
- [핵심 개념](#핵심-개념)
- [작동 원리](#작동-원리)
- [구현 방법](#구현-방법)
- [실전 예제](#실전-예제)
- [EIP-3074 vs EIP-7702](#eip-3074-vs-eip-7702)
- [보안 고려사항](#보안-고려사항)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

## 개요

### EIP-7702란?

**EIP-7702**는 EOA(Externally Owned Account)가 트랜잭션 실행 중에 **일시적으로** 스마트 컨트랙트 코드를 실행할 수 있게 해주는 제안입니다.

트랜잭션 내에서만 컨트랙트처럼 동작하고, 트랜잭션이 끝나면 다시 일반 EOA로 돌아옵니다.

### 왜 중요한가?

```
기존 EOA 문제:
❌ 개인키 하나로만 제어
❌ 배치 트랜잭션 불가능
❌ 가스리스 트랜잭션 불가능
❌ 멀티시그 불가능
❌ 소셜 복구 불가능

EIP-7702 (EOA + 코드):
✅ 트랜잭션 내에서 스마트 컨트랙트 기능 사용
✅ 기존 EOA 주소 유지
✅ 트랜잭션 후 다시 일반 EOA
✅ Account Abstraction보다 간단
✅ 즉시 사용 가능
```

### 핵심 특징

1. **Authorization List**: 트랜잭션에 "이 코드를 실행하겠다"는 서명된 승인 포함
2. **일시적 위임**: 트랜잭션 내에서만 코드 실행, 종료 후 복원
3. **기존 주소 유지**: EOA 주소와 잔액 그대로 유지
4. **Account Abstraction 호환**: EIP-4337과 함께 사용 가능
5. **역호환성**: 기존 EOA로 언제든 되돌아갈 수 있음

## 문제점: EOA의 한계

### EOA (Externally Owned Account)란?

이더리움의 기본 계정 타입으로, 개인키로 제어되는 계정입니다.

```
EOA:
- 주소: 개인키의 공개키에서 파생
- 코드: 없음 (코드 없는 계정)
- 스토리지: 없음
- 제어: 개인키 서명으로만 트랜잭션 시작 가능
```

### EOA의 한계

#### 1. 단일 개인키 의존

```
문제: 개인키 하나로만 계정 제어
→ 개인키 분실 = 계정 영구 손실
→ 개인키 탈취 = 자산 전부 도난
→ 멀티시그 불가능
```

#### 2. 배치 트랜잭션 불가능

```javascript
// ❌ EOA는 한 번에 하나씩만 실행
await token.approve(spender, amount);  // Tx 1
await spender.deposit(amount);         // Tx 2
await spender.stake(amount);           // Tx 3
// → 3번의 서명, 3배의 가스비
```

#### 3. 가스리스 트랜잭션 불가능

```
문제: 트랜잭션 시작자가 반드시 ETH 보유해야 함
→ 새 사용자는 먼저 ETH 구매 필요
→ USDC만 보유해도 ETH 필요
→ 진입 장벽
```

#### 4. 고급 기능 불가능

```
불가능한 기능들:
❌ 소셜 복구
❌ 세션 키
❌ 지출 한도
❌ 시간 잠금
❌ 조건부 실행
```

### Account Abstraction의 대안

EIP-4337 Account Abstraction으로 해결 가능하지만:

```
EIP-4337 단점:
❌ 새 주소 생성 필요 (기존 EOA 주소 버려야 함)
❌ 자산 이전 필요
❌ 복잡한 설정
❌ Bundler, EntryPoint 등 인프라 필요
❌ 즉시 사용 어려움
```

## 해결책: EOA 코드 위임

### EIP-7702의 접근

**"EOA가 트랜잭션 실행 중에만 스마트 컨트랙트처럼 동작하게 하자!"**

```
핵심 아이디어:
1. EOA 소유자가 "이 코드를 실행하겠다"고 서명
2. 트랜잭션에 authorization list 포함
3. 트랜잭션 실행 중에만 해당 코드로 동작
4. 트랜잭션 종료 후 다시 일반 EOA
```

### 작동 방식

```
┌──────────┐
│   EOA    │ (일반 상태)
│ 0x123... │
│ Code: ❌ │
└────┬─────┘
     │
     │ 1. Authorization 서명
     │    "DelegationContract를 실행하겠다"
     │
     ↓
┌─────────────────┐
│  Transaction    │
│ + Authorization │
└────┬────────────┘
     │
     │ 2. 트랜잭션 실행 중
     ↓
┌──────────────────┐
│   EOA (임시)     │
│   0x123...       │
│   Code: ✅       │ ← DelegationContract 코드
│   (배치 실행 등) │
└────┬─────────────┘
     │
     │ 3. 트랜잭션 종료
     ↓
┌──────────┐
│   EOA    │ (다시 일반 상태)
│ 0x123... │
│ Code: ❌ │
└──────────┘
```

### Authorization List

트랜잭션에 포함되는 새로운 필드:

```javascript
const tx = {
    to: myEOA,  // 또는 다른 주소
    value: 0,
    data: '0x...',

    // Authorization List (새로운 필드!)
    authorizationList: [
        {
            chainId: 1,
            address: delegationContractAddress,  // 실행할 코드
            nonce: 0,
            yParity: 1,
            r: '0x...',
            s: '0x...'
        }
    ]
};
```

**Authorization 서명:**

```javascript
// EOA 소유자가 서명
const authorization = {
    chainId: 1,
    address: delegationContractAddress,
    nonce: 0
};

const authHash = keccak256(
    abi.encode(
        MAGIC,
        chainId,
        nonce,
        address
    )
);

const signature = sign(authHash, privateKey);
// → yParity, r, s
```

## 핵심 개념

### 1. Set Code Transaction (Type 4)

EIP-7702는 새로운 트랜잭션 타입을 도입합니다:

```
Type 0: Legacy
Type 1: EIP-2930 (Access List)
Type 2: EIP-1559 (Dynamic Fee)
Type 3: EIP-4844 (Blob Transaction)
Type 4: EIP-7702 (Set Code Transaction) ← 신규!
```

**Type 4 트랜잭션 형식:**

```
0x04 || rlp([
    chain_id,
    nonce,
    max_priority_fee_per_gas,
    max_fee_per_gas,
    gas_limit,
    to,
    value,
    data,
    access_list,
    authorization_list,  // 새로운 필드!
    signature_y_parity,
    signature_r,
    signature_s
])
```

### 2. Authorization 구조

```
Authorization = (chain_id, address, nonce, y_parity, r, s)

chain_id: 체인 ID
address: 위임할 컨트랙트 주소
nonce: EOA의 nonce (재사용 방지)
y_parity, r, s: EOA 소유자의 서명
```

**Authorization 생성:**

```python
def create_authorization(signer, delegation_address, chain_id, nonce):
    # 1. Authorization 해시
    auth_hash = keccak256(
        MAGIC +
        encode_uint(chain_id) +
        encode_uint(nonce) +
        encode_address(delegation_address)
    )

    # 2. 서명
    signature = sign(auth_hash, signer.private_key)

    # 3. Authorization 생성
    return Authorization(
        chain_id=chain_id,
        address=delegation_address,
        nonce=nonce,
        y_parity=signature.v - 27,
        r=signature.r,
        s=signature.s
    )
```

### 3. 코드 위임 메커니즘

**실행 흐름:**

```python
def process_transaction_with_authorization(tx):
    # 1. Authorization list 처리
    for auth in tx.authorization_list:
        # 1.1. 서명 검증
        signer = recover_signer(auth)

        # 1.2. Nonce 확인
        if get_nonce(signer) != auth.nonce:
            continue  # 실패, 다음으로

        # 1.3. 코드 설정 (임시)
        set_code(signer, auth.address)

    # 2. 트랜잭션 실행
    execute_transaction(tx)

    # 3. 코드 제거 (자동)
    # → 트랜잭션 종료 시 원래 상태로 복원
```

### 4. Delegation Designator

위임된 계정을 표시하는 특수 바이트:

```
일반 EOA 코드:
→ 빈 바이트열 (0 bytes)

위임된 EOA 코드:
→ 0xef0100 || address (23 bytes)
   ↑        ↑
   MAGIC    위임 대상 주소
```

**코드 확인:**

```solidity
function isDelegated(address account) public view returns (bool) {
    bytes memory code = account.code;

    if (code.length != 23) return false;
    if (code[0] != 0xef) return false;
    if (code[1] != 0x01) return false;
    if (code[2] != 0x00) return false;

    return true;
}

function getDelegationTarget(address account) public view returns (address) {
    bytes memory code = account.code;
    require(code.length == 23, "Not delegated");

    address target;
    assembly {
        target := mload(add(code, 23))
    }

    return target;
}
```

### 5. 실행 컨텍스트

위임된 코드는 **EOA의 컨텍스트**에서 실행됩니다:

```solidity
// DelegationContract가 EOA 컨텍스트에서 실행

contract DelegationContract {
    function execute(address target, bytes calldata data) external {
        // msg.sender: 트랜잭션 시작자
        // address(this): EOA 주소! (DelegationContract가 아님)
        // this.balance: EOA의 잔액

        (bool success,) = target.call(data);
        require(success);
    }
}
```

### 6. 스토리지 처리

위임된 코드는 EOA의 스토리지를 사용합니다:

```solidity
// DelegationContract가 EOA 주소의 스토리지 사용
contract DelegationContract {
    uint256 public counter;  // EOA 주소의 slot 0에 저장

    function increment() external {
        counter++;  // EOA의 스토리지 수정
    }
}

// EOA 주소: 0x123...
// DelegationContract를 위임 후 increment() 호출
// → 0x123...의 slot 0에 값 저장
```

## 작동 원리

### 전체 흐름

```
1. 준비 단계
   ├─ DelegationContract 배포
   └─ EOA 소유자가 Authorization 서명

2. 트랜잭션 생성
   ├─ Authorization list 포함
   └─ Type 4 트랜잭션 생성

3. 트랜잭션 실행
   ├─ Authorization 검증
   ├─ EOA에 코드 임시 설정
   ├─ 위임된 코드 실행
   └─ 트랜잭션 종료 (코드 자동 제거)

4. 결과
   └─ EOA는 다시 일반 상태
```

### 단계별 상세

#### 1. DelegationContract 배포

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DelegationContract {
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        // 실행 권한 확인
        require(msg.sender == address(this), "Not authorized");

        // 실행
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");

        return result;
    }

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

#### 2. Authorization 서명

```javascript
const { ethers } = require('ethers');

// EOA 소유자
const eoaSigner = new ethers.Wallet(privateKey);

// DelegationContract 주소
const delegationAddress = '0xDelegationContract...';

// Authorization 데이터
const chainId = 1;
const nonce = await provider.getTransactionCount(eoaSigner.address);

// Authorization 해시
const MAGIC = '0x05';  // EIP-7702 magic
const authHash = ethers.utils.keccak256(
    ethers.utils.concat([
        MAGIC,
        ethers.utils.defaultAbiCoder.encode(
            ['uint256', 'uint256', 'address'],
            [chainId, nonce, delegationAddress]
        )
    ])
);

// 서명
const signature = await eoaSigner.signMessage(
    ethers.utils.arrayify(authHash)
);

const { v, r, s } = ethers.utils.splitSignature(signature);

const authorization = {
    chainId: chainId,
    address: delegationAddress,
    nonce: nonce,
    yParity: v - 27,
    r: r,
    s: s
};
```

#### 3. Type 4 트랜잭션 생성

```javascript
// Type 4 트랜잭션
const tx = {
    type: 4,  // EIP-7702
    chainId: 1,
    nonce: nonce + 1,  // 트랜잭션 nonce
    to: eoaSigner.address,  // EOA 주소
    value: 0,
    data: encodeFunctionCall('executeBatch', [...]),  // DelegationContract 함수 호출
    gasLimit: 300000,
    maxFeePerGas: ethers.utils.parseUnits('50', 'gwei'),
    maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei'),

    // Authorization list
    authorizationList: [authorization]
};

// 서명 & 전송
const signedTx = await eoaSigner.signTransaction(tx);
const receipt = await provider.sendTransaction(signedTx);
```

#### 4. 실행

```python
# 노드가 트랜잭션 처리

def execute_eip7702_transaction(tx):
    # 1. Authorization list 처리
    for auth in tx.authorization_list:
        # 서명자 복구
        signer = ecrecover(auth.hash(), auth.yParity, auth.r, auth.s)

        # Nonce 확인
        if signer.nonce != auth.nonce:
            continue  # 실패

        # 체인 ID 확인
        if auth.chain_id not in [0, current_chain_id]:
            continue

        # 코드 설정 (임시)
        signer.code = DELEGATION_DESIGNATOR + auth.address
        signer.nonce += 1

    # 2. 트랜잭션 실행
    # EOA가 이제 DelegationContract 코드로 동작
    result = evm_execute(tx)

    # 3. 트랜잭션 종료
    # → 코드 자동 제거 (다시 일반 EOA)

    return result
```

## 구현 방법

### 1. 기본 Delegation Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleDelegation {
    event Executed(
        address indexed target,
        uint256 value,
        bytes data,
        bytes result
    );

    // 단일 실행
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        // msg.sender == address(this) 확인
        // (위임된 EOA 주소)
        require(msg.sender == address(this), "Not authorized");

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");

        emit Executed(target, value, data, result);
        return result;
    }

    // 배치 실행
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
            require(success);
            results[i] = result;

            emit Executed(targets[i], values[i], datas[i], result);
        }

        return results;
    }

    receive() external payable {}
}
```

### 2. 세션 키 Delegation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SessionDelegation {
    struct Session {
        address key;
        uint256 validUntil;
        uint256 gasLimit;
        uint256 gasUsed;
        bool active;
    }

    // EOA 주소별 세션 (스토리지에 저장)
    mapping(bytes32 => Session) public sessions;

    event SessionCreated(
        bytes32 indexed sessionId,
        address indexed key,
        uint256 validUntil
    );
    event SessionExecuted(bytes32 indexed sessionId, uint256 gasUsed);

    // 세션 생성 (EOA 소유자가 호출)
    function createSession(
        address key,
        uint256 duration,
        uint256 gasLimit
    ) external returns (bytes32) {
        require(msg.sender == address(this), "Not authorized");

        bytes32 sessionId = keccak256(
            abi.encodePacked(key, block.timestamp, block.number)
        );

        sessions[sessionId] = Session({
            key: key,
            validUntil: block.timestamp + duration,
            gasLimit: gasLimit,
            gasUsed: 0,
            active: true
        });

        emit SessionCreated(sessionId, key, block.timestamp + duration);
        return sessionId;
    }

    // 세션 키로 실행
    function executeWithSession(
        bytes32 sessionId,
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        Session storage session = sessions[sessionId];

        require(session.active, "Session not active");
        require(block.timestamp <= session.validUntil, "Session expired");

        // 실제 호출은 누구나 가능 (세션 키 검증은 오프체인)
        uint256 gasBefore = gasleft();

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success);

        uint256 gasUsed = gasBefore - gasleft();
        session.gasUsed += gasUsed;

        require(session.gasUsed <= session.gasLimit, "Gas limit exceeded");

        emit SessionExecuted(sessionId, gasUsed);
        return result;
    }

    // 세션 취소
    function revokeSession(bytes32 sessionId) external {
        require(msg.sender == address(this), "Not authorized");
        sessions[sessionId].active = false;
    }

    receive() external payable {}
}
```

### 3. 멀티시그 Delegation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigDelegation {
    address[] public signers;
    uint256 public requiredSignatures;

    mapping(address => bool) public isSigner;
    mapping(bytes32 => mapping(address => bool)) public confirmations;
    mapping(bytes32 => uint256) public confirmationCount;
    mapping(bytes32 => bool) public executed;

    event TransactionProposed(bytes32 indexed txHash);
    event TransactionConfirmed(bytes32 indexed txHash, address indexed signer);
    event TransactionExecuted(bytes32 indexed txHash);

    constructor(address[] memory signers_, uint256 requiredSignatures_) {
        require(signers_.length >= requiredSignatures_);
        require(requiredSignatures_ > 0);

        for (uint256 i = 0; i < signers_.length; i++) {
            address signer = signers_[i];
            require(signer != address(0));
            require(!isSigner[signer]);

            isSigner[signer] = true;
            signers.push(signer);
        }

        requiredSignatures = requiredSignatures_;
    }

    // 트랜잭션 제안
    function proposeTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external returns (bytes32) {
        require(isSigner[msg.sender], "Not signer");

        bytes32 txHash = keccak256(
            abi.encodePacked(target, value, data, block.timestamp)
        );

        require(!executed[txHash], "Already executed");

        confirmations[txHash][msg.sender] = true;
        confirmationCount[txHash] = 1;

        emit TransactionProposed(txHash);
        emit TransactionConfirmed(txHash, msg.sender);

        return txHash;
    }

    // 트랜잭션 승인
    function confirmTransaction(bytes32 txHash) external {
        require(isSigner[msg.sender], "Not signer");
        require(!executed[txHash], "Already executed");
        require(!confirmations[txHash][msg.sender], "Already confirmed");

        confirmations[txHash][msg.sender] = true;
        confirmationCount[txHash]++;

        emit TransactionConfirmed(txHash, msg.sender);
    }

    // 트랜잭션 실행
    function executeTransaction(
        bytes32 txHash,
        address target,
        uint256 value,
        bytes memory data
    ) external {
        require(!executed[txHash], "Already executed");
        require(
            confirmationCount[txHash] >= requiredSignatures,
            "Not enough confirmations"
        );

        executed[txHash] = true;

        (bool success,) = target.call{value: value}(data);
        require(success, "Execution failed");

        emit TransactionExecuted(txHash);
    }

    receive() external payable {}
}
```

### 4. 소셜 복구 Delegation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RecoveryDelegation {
    address public owner;
    address[] public guardians;
    mapping(address => bool) public isGuardian;

    address public proposedOwner;
    mapping(address => bool) public recoveryApprovals;
    uint256 public recoveryApprovalsCount;
    uint256 public requiredApprovals;

    event RecoveryProposed(address indexed newOwner);
    event RecoveryApproved(address indexed guardian);
    event RecoveryExecuted(address indexed oldOwner, address indexed newOwner);

    constructor(
        address owner_,
        address[] memory guardians_,
        uint256 requiredApprovals_
    ) {
        require(guardians_.length >= requiredApprovals_);

        owner = owner_;
        requiredApprovals = requiredApprovals_;

        for (uint256 i = 0; i < guardians_.length; i++) {
            address guardian = guardians_[i];
            require(guardian != address(0));
            require(!isGuardian[guardian]);

            isGuardian[guardian] = true;
            guardians.push(guardian);
        }
    }

    // 복구 제안 (Guardian만)
    function proposeRecovery(address newOwner) external {
        require(isGuardian[msg.sender], "Not guardian");
        require(newOwner != address(0));

        proposedOwner = newOwner;
        recoveryApprovalsCount = 0;

        // 기존 승인 초기화
        for (uint256 i = 0; i < guardians.length; i++) {
            recoveryApprovals[guardians[i]] = false;
        }

        emit RecoveryProposed(newOwner);
    }

    // 복구 승인 (Guardian들)
    function approveRecovery() external {
        require(isGuardian[msg.sender], "Not guardian");
        require(proposedOwner != address(0), "No recovery proposed");
        require(!recoveryApprovals[msg.sender], "Already approved");

        recoveryApprovals[msg.sender] = true;
        recoveryApprovalsCount++;

        emit RecoveryApproved(msg.sender);

        // 충분한 승인이 모이면 자동 실행
        if (recoveryApprovalsCount >= requiredApprovals) {
            address oldOwner = owner;
            owner = proposedOwner;

            proposedOwner = address(0);
            recoveryApprovalsCount = 0;

            emit RecoveryExecuted(oldOwner, owner);
        }
    }

    // 실행 (Owner만)
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory) {
        // Delegation 컨텍스트에서는 msg.sender == address(this)
        // 하지만 원래 호출자 확인 필요 → storage의 owner 사용
        require(msg.sender == owner || msg.sender == address(this));

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success);

        return result;
    }

    receive() external payable {}
}
```

## 실전 예제

### 1. 배치 트랜잭션 실행

```javascript
const { ethers } = require('ethers');

// 1. DelegationContract 배포
const DelegationContract = await ethers.getContractFactory('SimpleDelegation');
const delegation = await DelegationContract.deploy();

// 2. Authorization 서명
const eoaSigner = new ethers.Wallet(privateKey, provider);
const authorization = await createAuthorization(
    eoaSigner,
    delegation.address,
    1,  // chainId
    await provider.getTransactionCount(eoaSigner.address)
);

// 3. 배치 트랜잭션 데이터
const calls = [
    {
        target: token.address,
        value: 0,
        data: token.interface.encodeFunctionData('approve', [
            spender.address,
            ethers.utils.parseEther('100')
        ])
    },
    {
        target: spender.address,
        value: 0,
        data: spender.interface.encodeFunctionData('deposit', [
            ethers.utils.parseEther('100')
        ])
    },
    {
        target: spender.address,
        value: 0,
        data: spender.interface.encodeFunctionData('stake', [])
    }
];

// 4. Type 4 트랜잭션 생성
const tx = {
    type: 4,
    chainId: 1,
    nonce: authorization.nonce + 1,
    to: eoaSigner.address,  // EOA 주소
    value: 0,

    // DelegationContract의 executeBatch 호출
    data: delegation.interface.encodeFunctionData('executeBatch', [
        calls.map(c => c.target),
        calls.map(c => c.value),
        calls.map(c => c.data)
    ]),

    gasLimit: 500000,
    maxFeePerGas: ethers.utils.parseUnits('50', 'gwei'),
    maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei'),

    // Authorization list
    authorizationList: [authorization]
};

// 5. 서명 & 전송
const signedTx = await eoaSigner.signTransaction(tx);
const receipt = await provider.sendTransaction(signedTx);

console.log('Batch executed:', receipt.transactionHash);
// → 한 번의 트랜잭션으로 3개 실행!
```

### 2. 세션 키 사용

```javascript
// 1. 세션 키 생성
const sessionKey = ethers.Wallet.createRandom();

// 2. Authorization 서명 (EOA 소유자)
const authorization = await createAuthorization(
    eoaSigner,
    sessionDelegation.address,
    1,
    await provider.getTransactionCount(eoaSigner.address)
);

// 3. 세션 생성 트랜잭션
const createSessionTx = {
    type: 4,
    to: eoaSigner.address,
    data: sessionDelegation.interface.encodeFunctionData('createSession', [
        sessionKey.address,
        86400,  // 24시간
        1000000  // 가스 한도
    ]),
    authorizationList: [authorization]
};

const receipt1 = await eoaSigner.sendTransaction(createSessionTx);
const sessionId = receipt1.logs[0].data;  // SessionCreated 이벤트

// 4. 이제 세션 키로 실행 (EOA 소유자 서명 불필요!)
async function playGame(action) {
    // Authorization 다시 필요
    const auth = await createAuthorization(
        eoaSigner,
        sessionDelegation.address,
        1,
        await provider.getTransactionCount(eoaSigner.address)
    );

    const gameTx = {
        type: 4,
        to: eoaSigner.address,
        data: sessionDelegation.interface.encodeFunctionData(
            'executeWithSession',
            [
                sessionId,
                gameContract.address,
                0,
                gameContract.interface.encodeFunctionData('play', [action])
            ]
        ),
        authorizationList: [auth]
    };

    // 세션 키로 서명 (또는 제3자가 대신 실행)
    return await sessionKey.sendTransaction(gameTx);
}

// 게임 플레이
await playGame('move_left');
await playGame('jump');
// → 빠르고 편리!
```

### 3. 가스리스 트랜잭션

```javascript
// 1. 사용자는 메타 트랜잭션 서명만
const user = new ethers.Wallet(userPrivateKey);
const metaTxSignature = await user.signMessage(
    ethers.utils.arrayify(metaTxHash)
);

// 2. Relayer가 대신 실행
async function relayTransaction(userAddress, target, data, signature) {
    // Authorization 필요 (사용자가 사전에 서명)
    const authorization = getUserAuthorization(userAddress);

    // Type 4 트랜잭션
    const tx = {
        type: 4,
        to: userAddress,  // 사용자 EOA
        data: gaslessDelegation.interface.encodeFunctionData(
            'executeMetaTransaction',
            [userAddress, target, 0, data, nonce, signature]
        ),
        authorizationList: [authorization]
    };

    // Relayer가 가스비 지불
    return await relayer.sendTransaction(tx);
}

// 사용자는 ETH 없어도 트랜잭션 실행!
await relayTransaction(
    user.address,
    token.address,
    token.interface.encodeFunctionData('transfer', [recipient, amount]),
    metaTxSignature
);
```

## EIP-3074 vs EIP-7702

두 제안 모두 EOA에 고급 기능을 추가하려는 시도입니다.

### EIP-3074

```solidity
// AUTH + AUTHCALL opcodes 추가

// 1. AUTH: EOA 권한 부여
AUTH(commitment, yParity, r, s)
→ EOA가 "이 컨트랙트에 권한을 준다"고 서명

// 2. AUTHCALL: EOA 대신 호출
AUTHCALL(gas, addr, value, argsOffset, argsLength, retOffset, retLength)
→ EOA의 권한으로 호출 실행
```

**특징:**
- Opcode 레벨 변경
- Invoker Contract 필요
- EOA 권한을 컨트랙트에 위임
- 영구적 권한 부여 가능

### EIP-7702

```
// Authorization List로 코드 위임

// EOA가 트랜잭션 내에서만 코드 실행
authorizationList: [
    { chainId, address, nonce, signature }
]
→ EOA가 일시적으로 해당 코드로 동작
```

**특징:**
- 트랜잭션 레벨 변경
- 트랜잭션 내에서만 유효
- 트랜잭션 종료 후 자동 복원
- 더 안전 (일시적)

### 비교표

| 특징 | EIP-3074 | EIP-7702 |
|------|----------|----------|
| 방식 | AUTH + AUTHCALL opcode | Authorization List |
| 권한 | 영구적 (명시적 취소 필요) | 일시적 (트랜잭션 내) |
| 복잡도 | 복잡 (Invoker 필요) | 간단 (트랜잭션만) |
| 안전성 | 낮음 (영구 권한) | 높음 (일시적) |
| EIP-4337 호환 | 어려움 | 쉬움 |
| 채택 가능성 | 낮음 (보안 우려) | 높음 |

### 왜 EIP-7702가 선호되는가?

```
EIP-3074 문제:
❌ 영구적 권한 부여 → 보안 위험
❌ Invoker Contract 신뢰 필요
❌ 권한 취소 메커니즘 복잡
❌ EIP-4337과 충돌 가능

EIP-7702 장점:
✅ 트랜잭션 내에서만 유효 → 안전
✅ 자동 복원 → 간단
✅ EIP-4337과 호환
✅ 기존 EOA 주소 유지
```

## 보안 고려사항

### 1. Delegation Contract 검증

```
❌ 위험: 검증되지 않은 컨트랙트 위임
→ 악의적 코드가 EOA 제어
→ 자산 탈취 가능

✅ 안전: 감사받은 컨트랙트만 위임
→ OpenZeppelin, Safe 등
→ 커뮤니티 검증
```

**모범 사례:**

```solidity
// 허용된 Delegation Contract 목록
mapping(address => bool) public approvedDelegations;

function setApprovedDelegation(address delegation, bool approved)
    external
    onlyGovernance
{
    approvedDelegations[delegation] = approved;
}

// 사용자는 승인된 것만 사용
function createAuthorization(address delegation) external view {
    require(approvedDelegations[delegation], "Not approved");
    // ...
}
```

### 2. Nonce 관리

```solidity
// ❌ 위험: Nonce 재사용
authorization1 = { chainId: 1, address: A, nonce: 5 }
authorization2 = { chainId: 1, address: A, nonce: 5 }  // 동일!
→ 둘 다 유효하면 문제

// ✅ 안전: Nonce 자동 증가
// EIP-7702는 Authorization 사용 시 자동으로 nonce 증가
→ 재사용 불가능
```

### 3. Chain ID 확인

```solidity
// ❌ 위험: Chain ID 0 허용
authorization = { chainId: 0, address: A, nonce: 5 }
→ 모든 체인에서 유효!
→ 리플레이 공격

// ✅ 안전: 특정 체인만 지정
authorization = { chainId: 1, address: A, nonce: 5 }  // 메인넷만
```

### 4. 권한 범위 제한

```solidity
// DelegationContract는 최소 권한만

contract SafeDelegation {
    // ✅ 특정 기능만 제공
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external {
        require(msg.sender == address(this));

        // 허용된 타겟만 호출
        for (uint256 i = 0; i < targets.length; i++) {
            require(isAllowedTarget(targets[i]), "Target not allowed");
            // ...
        }
    }

    mapping(address => bool) public allowedTargets;
}
```

### 5. 스토리지 충돌 방지

```solidity
// ❌ 위험: DelegationContract와 EOA 스토리지 충돌

contract BadDelegation {
    uint256 public value;  // slot 0

    function setValue(uint256 _value) external {
        value = _value;  // EOA의 slot 0에 저장!
    }
}
// → EOA가 다른 용도로 slot 0 사용 중이면 충돌

// ✅ 안전: 네임스페이스 사용 (EIP-7201)
contract SafeDelegation {
    bytes32 constant STORAGE_POSITION = keccak256("safe.delegation.storage");

    struct Storage {
        uint256 value;
    }

    function getStorage() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function setValue(uint256 _value) external {
        getStorage().value = _value;
    }
}
```

### 6. 재진입 공격 방지

```solidity
// ✅ ReentrancyGuard 사용
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SafeDelegation is ReentrancyGuard {
    function execute(address target, uint256 value, bytes calldata data)
        external
        nonReentrant  // 재진입 방지
        returns (bytes memory)
    {
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success);
        return result;
    }
}
```

## FAQ

### Q1: EIP-7702는 언제 활성화되나?

**A:** 2024-2025년 Pectra 하드포크 예정입니다:

```
현재 상태: Draft → Review
예상 일정: 2024년 말 - 2025년 초
포함 하드포크: Pectra (Prague + Electra)
```

### Q2: 기존 EIP-4337과 어떻게 다른가?

**A:** 보완 관계입니다:

```
EIP-4337:
→ 새 Smart Account 생성
→ 복잡하지만 강력
→ 완전한 Account Abstraction

EIP-7702:
→ 기존 EOA 사용
→ 간단하지만 제한적
→ 일시적 Account Abstraction

함께 사용:
→ EIP-7702로 EOA를 EIP-4337 호환하게 만들기 가능!
```

### Q3: 트랜잭션마다 Authorization이 필요한가?

**A:** 네, 매 트랜잭션마다 필요합니다:

```
문제로 보일 수 있지만:
✅ 보안성 향상 (일시적)
✅ Nonce 자동 증가로 재사용 방지
✅ 사용자가 명확히 제어

개선책:
→ Wallet UI에서 자동화
→ 세션 키로 반복 승인 줄이기
```

### Q4: EOA 주소가 변경되나?

**A:** 아니요, 주소는 그대로입니다:

```
Before:
→ EOA: 0x123...
→ Balance: 10 ETH

After (트랜잭션 실행 중):
→ EOA: 0x123...  (주소 동일)
→ Balance: 10 ETH  (잔액 동일)
→ Code: DelegationContract (임시)

After (트랜잭션 종료):
→ EOA: 0x123...
→ Balance: 10 ETH
→ Code: 없음 (다시 일반 EOA)
```

### Q5: 여러 Delegation을 동시에 사용할 수 있나?

**A:** 아니요, 하나의 Authorization만 유효합니다:

```javascript
// ❌ 여러 Delegation은 마지막 것만 적용됨
authorizationList: [
    { address: delegationA },
    { address: delegationB }  // 이것만 적용
]

// ✅ 필요하면 Delegation 내부에서 다른 Delegation 호출
contract DelegationA {
    function execute() external {
        // DelegationB의 기능 사용
        DelegationB(delegationB).someFunction();
    }
}
```

### Q6: 스토리지는 어디에 저장되나?

**A:** EOA 주소의 스토리지에 저장됩니다:

```
DelegationContract를 0x123...에 위임 시:
→ DelegationContract의 storage 변수들이
→ 0x123...의 storage에 저장됨

주의:
→ 다른 Delegation으로 변경 시 storage 충돌 가능
→ 네임스페이스 storage (EIP-7201) 사용 권장
```

### Q7: 가스 비용은 얼마나 되나?

**A:**

```
Authorization 검증: ~3,000 gas
코드 설정: ~20,000 gas (SSTORE)
총 추가 비용: ~23,000 gas

일반 트랜잭션: 21,000 gas
EIP-7702 트랜잭션: 44,000 gas (+23,000)

But:
✅ 배치 실행으로 절약 가능
✅ 한 번에 여러 작업 → 전체적으로 저렴
```

### Q8: 악의적 Delegation Contract 위험은?

**A:** 사용자 책임입니다:

```
위험:
❌ 악의적 코드에 Authorization 서명
→ 트랜잭션 내에서 자산 탈취 가능

방어:
✅ 검증된 Delegation만 사용
✅ Wallet UI에서 경고
✅ 커뮤니티 리뷰
✅ 감사받은 컨트랙트

메타마스크 등은:
→ 허용된 Delegation 화이트리스트
→ 사용자에게 명확한 경고
```

### Q9: EIP-7702는 EIP-3074를 대체하나?

**A:** 네, EIP-7702가 선호됩니다:

```
EIP-3074:
→ 영구적 권한 부여
→ 보안 우려로 채택 어려움

EIP-7702:
→ 일시적 권한 부여
→ 더 안전하고 간단
→ Pectra 하드포크에 포함 예정
```

### Q10: 기존 EOA를 Smart Account로 완전 전환 가능한가?

**A:** 아니요, 일시적입니다:

```
EIP-7702:
→ 트랜잭션 내에서만 Smart Account처럼 동작
→ 트랜잭션 종료 후 다시 EOA

완전 전환하려면:
→ EIP-4337 사용
→ 새 Smart Account 생성
→ 자산 이전 필요
```

## 참고 자료

### 공식 문서
- [EIP-7702 Specification](https://eips.ethereum.org/EIPS/eip-7702)
- [Ethereum Magicians Discussion](https://ethereum-magicians.org/t/eip-7702-set-eoa-account-code/19923)
- [Vitalik's Post](https://vitalik.eth.limo/general/2023/06/09/three_transitions.html)

### 관련 EIP
- [EIP-3074](https://eips.ethereum.org/EIPS/eip-3074) - AUTH and AUTHCALL
- [EIP-4337](https://eips.ethereum.org/EIPS/eip-4337) - Account Abstraction
- [EIP-7201](https://eips.ethereum.org/EIPS/eip-7201) - Namespaced Storage

### 구현 예제
- [Geth Implementation](https://github.com/ethereum/go-ethereum)
- [Solidity Examples](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7702.md#examples)

### 블로그 & 아티클
- [EIP-7702 Deep Dive](https://www.alchemy.com/blog/eip-7702)
- [Account Abstraction Evolution](https://ethereum.org/en/roadmap/account-abstraction/)

---

**작성일**: 2025년 1월
**EIP 상태**: Draft
**예상 활성화**: 2024-2025년 (Pectra 하드포크)

EIP-7702는 기존 EOA 사용자들이 Account Abstraction의 혜택을 누릴 수 있게 해주는 중요한 진전입니다! 🚀
