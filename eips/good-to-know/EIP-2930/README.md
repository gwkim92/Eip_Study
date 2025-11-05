# EIP-2930: Optional Access Lists

> **미리 선언하는 스토리지 접근 목록으로 가스 비용 예측 가능** 📋⛽

## 📚 목차

- [개요](#개요)
- [핵심 개념](#핵심-개념)
- [작동 원리](#작동-원리)
- [Access List 구조](#access-list-구조)
- [가스 비용 분석](#가스-비용-분석)
- [생성 방법](#생성-방법)
- [사용 사례](#사용-사례)
- [장단점](#장단점)
- [구현 예제](#구현-예제)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

### EIP-2930이란?

EIP-2930은 **Access List**라는 개념을 도입하여, 트랜잭션이 접근할 주소와 스토리지 키를 **미리 선언**할 수 있게 합니다. 이를 통해 **cold/warm access** 패턴을 명시적으로 관리하고 가스 비용을 최적화할 수 있습니다.

```
┌─────────────────────────────────────────────┐
│       EIP-2930: Access Lists                │
├─────────────────────────────────────────────┤
│                                             │
│  트랜잭션 전송 전:                           │
│  ↓                                          │
│  접근할 주소/스토리지 미리 선언               │
│  ↓                                          │
│  Cold → Warm 변환 (가스 절감)                │
│  ↓                                          │
│  가스 비용 예측 가능                         │
│                                             │
│  📋 Type 1 Transaction                      │
│  ⛽ 가스 비용 최적화                         │
│  🔮 비용 예측 가능                           │
│                                             │
└─────────────────────────────────────────────┘
```

### 왜 필요한가?

EIP-2929 (Berlin 하드포크)에서 **cold/warm access** 개념이 도입되면서, 처음 접근하는 주소/스토리지는 비용이 높고 두 번째부터는 저렴해졌습니다. EIP-2930은 이를 **사전에 warm 상태로 만들어** 가스 비용을 예측 가능하게 합니다.

```solidity
// EIP-2929 이전 (일정한 가스 비용)
contract Before {
    mapping(address => uint256) public balances;

    function getBalance(address user) external view returns (uint256) {
        return balances[user];  // 항상 같은 가스 비용
    }
}

// EIP-2929 이후 (cold/warm 구분)
contract After {
    mapping(address => uint256) public balances;

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
        // 첫 접근 (cold): 2,600 gas
        // 재접근 (warm): 100 gas
    }
}

// EIP-2930 Access List 사용
const tx = {
    to: contractAddress,
    data: contract.interface.encodeFunctionData('getBalance', [user]),
    accessList: [
        {
            address: contractAddress,
            storageKeys: [
                // balances[user]의 스토리지 키
                ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
                    ['address', 'uint256'],
                    [user, 0]  // 0 = balances 슬롯
                ))
            ]
        }
    ]
};
// 첫 접근부터 warm: 100 gas + access list 비용
```

### 주요 특징

| 특징 | 설명 |
|-----|------|
| **Type 1 Transaction** | 새로운 트랜잭션 타입 (0x01) |
| **선택적** | Access list는 선택사항 (없어도 됨) |
| **가스 최적화** | Cold access를 warm으로 변환 |
| **예측 가능성** | 가스 비용을 사전에 계산 가능 |
| **하위 호환** | 기존 트랜잭션과 호환 |

### 활성화 시기

- **하드포크**: Berlin (2021년 4월 15일)
- **블록 번호**: 12,244,000 (Mainnet)
- **EIP-2929와 함께 도입**: Cold/warm access 비용 구분

---

## 핵심 개념

### 1. Cold vs Warm Access

EIP-2929에서 도입된 개념으로, **처음 접근과 재접근의 가스 비용이 다릅니다**:

```
┌────────────────────────────────────────────┐
│       Cold vs Warm Access                 │
├────────────────────────────────────────────┤
│                                            │
│  Cold Access (첫 접근):                    │
│  - 주소: 2,600 gas                         │
│  - 스토리지: 2,100 gas                     │
│                                            │
│  Warm Access (재접근):                     │
│  - 주소: 100 gas                           │
│  - 스토리지: 100 gas                       │
│                                            │
│  절감: 2,500~2,000 gas (96%)               │
│                                            │
└────────────────────────────────────────────┘
```

**예제**:

```solidity
contract ColdWarmExample {
    mapping(address => uint256) public balances;

    function firstAccess(address user) external view returns (uint256) {
        return balances[user];
        // Cold access: 2,100 gas (SLOAD)
    }

    function doubleAccess(address user) external view returns (uint256, uint256) {
        uint256 a = balances[user];  // Cold: 2,100 gas
        uint256 b = balances[user];  // Warm: 100 gas
        return (a, b);
        // 총: 2,200 gas
    }
}
```

### 2. Access List 구조

Access list는 **주소와 스토리지 키의 배열**입니다:

```javascript
accessList = [
    {
        address: "0x1234...",  // 컨트랙트 주소
        storageKeys: [         // 접근할 스토리지 슬롯
            "0x0000...",
            "0x0001..."
        ]
    },
    {
        address: "0x5678...",  // 다른 컨트랙트
        storageKeys: []        // 주소만 (스토리지 없음)
    }
]
```

### 3. Type 1 Transaction

EIP-2930은 **Type 1 트랜잭션**을 도입합니다:

```javascript
// Type 0 (Legacy)
const legacyTx = {
    to: "0x...",
    data: "0x...",
    gasPrice: 50000000000,  // Wei
    nonce: 0
};

// Type 1 (EIP-2930)
const type1Tx = {
    type: 1,  // 명시적으로 Type 1
    to: "0x...",
    data: "0x...",
    gasPrice: 50000000000,
    nonce: 0,
    accessList: [  // 새로운 필드!
        {
            address: "0x...",
            storageKeys: ["0x..."]
        }
    ]
};

// Type 2 (EIP-1559)
const type2Tx = {
    type: 2,
    to: "0x...",
    data: "0x...",
    maxFeePerGas: 50000000000,
    maxPriorityFeePerGas: 2000000000,
    nonce: 0,
    accessList: [  // Type 2에서도 사용 가능!
        {
            address: "0x...",
            storageKeys: ["0x..."]
        }
    ]
};
```

---

## 작동 원리

### 트랜잭션 실행 흐름

```
1. 트랜잭션 전송
   ↓
   [Access List 파싱]

2. Access List의 주소/스토리지를 "warm" 상태로 변경
   ↓
   Address: 0x1234...  → warm
   Storage: 0x0000...  → warm
   Storage: 0x0001...  → warm

3. 트랜잭션 실행
   ↓
   Access List에 포함된 항목:
   - 첫 접근부터 warm 가스 비용 (100 gas)

   Access List에 없는 항목:
   - 첫 접근: cold 가스 비용 (2,600 or 2,100 gas)
   - 재접근: warm 가스 비용 (100 gas)

4. 트랜잭션 종료
   ↓
   [모든 warm 상태 초기화]
```

### 가스 비용 계산

Access list를 사용하면 **사전 비용이 추가**됩니다:

```
Access List 비용:
- 주소당: 2,400 gas
- 스토리지 키당: 1,900 gas

예시:
accessList = [
    {
        address: "0x1234...",      // 2,400 gas
        storageKeys: [
            "0x0000...",           // 1,900 gas
            "0x0001..."            // 1,900 gas
        ]
    }
]
총 Access List 비용: 2,400 + 1,900 + 1,900 = 6,200 gas

하지만 실행 중:
- Cold access (2,600 gas) → Warm access (100 gas)
- 절감: 2,500 gas × 접근 횟수

손익분기점:
- 1회 접근: 6,200 - 2,500 = +3,700 gas (손해)
- 2회 접근: 6,200 - 5,000 = +1,200 gas (손해)
- 3회 접근: 6,200 - 7,500 = -1,300 gas (이득!)
```

---

## Access List 구조

### JavaScript/TypeScript

```typescript
interface AccessList {
    address: string;        // 0x로 시작하는 20바이트 주소
    storageKeys: string[];  // 0x로 시작하는 32바이트 해시 배열
}

// 예제
const accessList: AccessList[] = [
    {
        address: "0x1234567890123456789012345678901234567890",
        storageKeys: [
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000000000000000000000000001"
        ]
    }
];
```

### Solidity (생성은 불가, 읽기만 가능)

Solidity에서는 access list를 직접 생성할 수 없지만, 트랜잭션이 access list를 포함하면 가스 비용이 최적화됩니다:

```solidity
contract AccessListAware {
    mapping(address => uint256) public balances;

    // Access list를 사용한 트랜잭션으로 호출하면 가스 절감
    function transferBatch(address[] calldata recipients, uint256[] calldata amounts) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            balances[recipients[i]] += amounts[i];
            // Access list에 포함된 경우:
            // - 첫 접근: 100 gas (warm)
            // Access list에 없는 경우:
            // - 첫 접근: 2,100 gas (cold)
            // - 재접근: 100 gas (warm)
        }
    }
}
```

---

## 가스 비용 분석

### 상세 비용 표

| 항목 | Cold Access | Warm Access | Access List 사전 비용 |
|------|-------------|-------------|-----------------------|
| **주소 (EXTCODESIZE 등)** | 2,600 gas | 100 gas | 2,400 gas |
| **스토리지 (SLOAD)** | 2,100 gas | 100 gas | 1,900 gas |

### 손익분기점 분석

#### 주소 접근

```
Access list 비용: 2,400 gas
Cold → Warm 절감: 2,600 - 100 = 2,500 gas

손익분기점:
- 1회 접근: 2,400 - 2,500×1 = -100 gas (약간 이득)
- 2회 접근: 2,400 - 2,500×2 = -2,600 gas (이득!)
```

#### 스토리지 접근

```
Access list 비용: 1,900 gas
Cold → Warm 절감: 2,100 - 100 = 2,000 gas

손익분기점:
- 1회 접근: 1,900 - 2,000×1 = -100 gas (약간 이득)
- 2회 접근: 1,900 - 2,000×2 = -2,100 gas (이득!)
```

### 실제 예제 비교

```javascript
// 예제: 10개 주소에서 잔액 조회
const addresses = [...]; // 10개 주소

// 1. Access List 없이
const tx1 = await contract.getBatchBalances(addresses);
// Cold access (첫 10개): 2,100 × 10 = 21,000 gas

// 2. Access List 사용
const storageKeys = addresses.map(addr =>
    ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256'],
        [addr, 0]  // balances 슬롯 = 0
    ))
);

const accessList = [{
    address: contractAddress,
    storageKeys: storageKeys
}];

const tx2 = await contract.getBatchBalances(addresses, { accessList });
// Access list 비용: 2,400 + 1,900×10 = 21,400 gas
// Warm access: 100 × 10 = 1,000 gas
// 총: 22,400 gas

// 비교:
// Access List 없음: 21,000 gas
// Access List 있음: 22,400 gas
// → 1회 접근에서는 손해 (-1,400 gas)

// 하지만 2회 접근 시:
// Access List 없음: 21,000 + 1,000 = 22,000 gas (1회 cold + 1회 warm)
// Access List 있음: 22,400 + 1,000 = 23,400 gas (전부 warm)
// → 여전히 약간 손해...

// 3회 접근 시:
// Access List 없음: 21,000 + 2,000 = 23,000 gas
// Access List 있음: 22,400 + 2,000 = 24,400 gas
// → 여전히 손해...
```

**결론**: 단순 조회에서는 access list가 항상 유리한 것은 아닙니다. **복잡한 트랜잭션**에서 여러 번 접근할 때 유리합니다.

---

## 생성 방법

### 1. eth_createAccessList RPC (자동 생성)

가장 간편한 방법은 **`eth_createAccessList` RPC**를 사용하는 것입니다:

```javascript
const { ethers } = require('ethers');

const provider = new ethers.providers.JsonRpcProvider('https://...');

// 트랜잭션 시뮬레이션 및 access list 생성
const accessListResponse = await provider.send("eth_createAccessList", [{
    from: sender,
    to: contractAddress,
    data: contract.interface.encodeFunctionData('myFunction', [arg1, arg2]),
    gas: "0x100000"  // 충분한 가스
}]);

console.log(accessListResponse);
// {
//     "accessList": [
//         {
//             "address": "0x...",
//             "storageKeys": ["0x...", "0x..."]
//         }
//     ],
//     "gasUsed": "0x5208"
// }

// Access list를 사용한 트랜잭션 전송
const tx = await signer.sendTransaction({
    to: contractAddress,
    data: contract.interface.encodeFunctionData('myFunction', [arg1, arg2]),
    accessList: accessListResponse.accessList,
    type: 1  // Type 1 transaction
});
```

### 2. 수동 계산 (Storage Key)

스토리지 키를 수동으로 계산하는 방법:

```javascript
const { ethers } = require('ethers');

// Mapping 스토리지 키 계산: mapping(address => uint256) public balances (slot 0)
function getMappingStorageKey(address, mappingSlot) {
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['address', 'uint256'],
            [address, mappingSlot]
        )
    );
}

const userAddress = "0x1234...";
const balancesSlot = 0;  // balances 변수가 slot 0에 있다고 가정

const storageKey = getMappingStorageKey(userAddress, balancesSlot);

const accessList = [
    {
        address: contractAddress,
        storageKeys: [storageKey]
    }
];

// 트랜잭션 전송
const tx = await signer.sendTransaction({
    to: contractAddress,
    data: contract.interface.encodeFunctionData('getBalance', [userAddress]),
    accessList: accessList,
    type: 1
});
```

### 3. ethers.js 통합

```javascript
const { ethers } = require('ethers');

// 1. 컨트랙트 인스턴스 생성
const contract = new ethers.Contract(contractAddress, abi, signer);

// 2. Access list 자동 생성 (ethers.js 내장 기능)
const populatedTx = await contract.populateTransaction.myFunction(arg1, arg2);

// 3. eth_createAccessList로 access list 생성
const accessListResponse = await provider.send("eth_createAccessList", [{
    from: await signer.getAddress(),
    to: populatedTx.to,
    data: populatedTx.data
}]);

// 4. Type 1 트랜잭션으로 전송
const tx = await signer.sendTransaction({
    ...populatedTx,
    accessList: accessListResponse.accessList,
    type: 1
});

await tx.wait();
console.log('Transaction mined:', tx.hash);
```

---

## 사용 사례

### 1. 배치 작업 (Batch Operations)

여러 주소/스토리지에 반복적으로 접근하는 경우:

```solidity
contract BatchTransfer {
    mapping(address => uint256) public balances;

    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            balances[recipients[i]] += amounts[i];
            // Access list 사용 시: 모두 warm access (100 gas)
            // Access list 미사용 시: 첫 접근 cold (2,100 gas), 재접근 warm (100 gas)
        }
    }
}
```

**Access List 생성**:

```javascript
const recipients = [...];  // 수신자 주소 배열
const amounts = [...];     // 금액 배열

// 스토리지 키 계산
const storageKeys = recipients.map(addr =>
    ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256'],
        [addr, 0]  // balances의 slot = 0
    ))
);

const accessList = [{
    address: contractAddress,
    storageKeys: storageKeys
}];

const tx = await contract.batchTransfer(recipients, amounts, { accessList });
```

### 2. 복잡한 DeFi 작업

여러 프로토콜과 상호작용하는 경우:

```solidity
contract DeFiAggregator {
    function swapAndStake(
        address tokenA,
        address tokenB,
        address dexRouter,
        address stakingPool,
        uint256 amount
    ) external {
        // 1. TokenA 승인
        IERC20(tokenA).approve(dexRouter, amount);

        // 2. DEX에서 Swap
        IDEXRouter(dexRouter).swap(tokenA, tokenB, amount);

        // 3. TokenB를 Staking Pool에 입금
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        IERC20(tokenB).approve(stakingPool, balanceB);
        IStakingPool(stakingPool).stake(balanceB);

        // 많은 컨트랙트 호출 → Access list로 최적화
    }
}
```

**Access List 생성**:

```javascript
const accessListResponse = await provider.send("eth_createAccessList", [{
    from: userAddress,
    to: aggregatorAddress,
    data: aggregator.interface.encodeFunctionData('swapAndStake', [
        tokenA,
        tokenB,
        dexRouter,
        stakingPool,
        amount
    ])
}]);

const tx = await aggregator.swapAndStake(tokenA, tokenB, dexRouter, stakingPool, amount, {
    accessList: accessListResponse.accessList,
    type: 2  // Type 2 (EIP-1559)에서도 사용 가능
});
```

### 3. 가스 비용 예측

프론트엔드에서 정확한 가스 비용을 표시:

```javascript
// 1. Access list 없이 가스 추정
const estimateWithoutAccessList = await contract.estimateGas.myFunction(arg1, arg2);

// 2. Access list 생성
const accessListResponse = await provider.send("eth_createAccessList", [{
    from: userAddress,
    to: contractAddress,
    data: contract.interface.encodeFunctionData('myFunction', [arg1, arg2])
}]);

// 3. Access list 포함 가스 추정
const estimateWithAccessList = await contract.estimateGas.myFunction(arg1, arg2, {
    accessList: accessListResponse.accessList
});

console.log('Without access list:', estimateWithoutAccessList.toString());
console.log('With access list:', estimateWithAccessList.toString());

// 사용자에게 더 나은 옵션 제시
if (estimateWithAccessList.lt(estimateWithoutAccessList)) {
    console.log('Access list recommended!');
}
```

---

## 장단점

### ✅ 장점

1. **가스 비용 예측 가능**
   ```
   Access list를 사용하면 트랜잭션 실행 전에
   정확한 가스 비용을 계산할 수 있습니다.
   ```

2. **복잡한 트랜잭션 최적화**
   ```
   여러 컨트랙트/스토리지에 반복 접근하는 경우
   전체 가스 비용 절감 가능
   ```

3. **선택적 사용**
   ```
   필요한 경우에만 사용하면 되므로
   하위 호환성 유지
   ```

4. **EIP-1559와 호환**
   ```
   Type 2 트랜잭션에서도 access list 사용 가능
   ```

### ❌ 단점

1. **항상 절감되는 것은 아님**
   ```
   Access list 자체에도 비용이 듭니다:
   - 주소: 2,400 gas
   - 스토리지 키: 1,900 gas

   1~2회 접근에서는 오히려 손해 가능
   ```

2. **수동 계산 복잡**
   ```
   스토리지 키를 수동으로 계산하려면
   컨트랙트의 스토리지 레이아웃을 정확히 알아야 함
   ```

3. **RPC 의존성**
   ```
   eth_createAccessList는 모든 노드에서
   지원하지 않을 수 있음
   ```

4. **트랜잭션 크기 증가**
   ```
   Access list가 커지면
   트랜잭션 calldata 비용 증가
   ```

---

## 구현 예제

### 예제 1: 기본 사용법 (ethers.js)

```javascript
const { ethers } = require('ethers');

async function sendWithAccessList() {
    const provider = new ethers.providers.JsonRpcProvider('https://mainnet.infura.io/v3/YOUR_KEY');
    const wallet = new ethers.Wallet(privateKey, provider);

    // 컨트랙트 인스턴스
    const contract = new ethers.Contract(contractAddress, abi, wallet);

    // 1. Access list 자동 생성
    const txData = contract.interface.encodeFunctionData('transfer', [recipient, amount]);

    const accessListResponse = await provider.send("eth_createAccessList", [{
        from: wallet.address,
        to: contractAddress,
        data: txData
    }]);

    console.log('Access List:', JSON.stringify(accessListResponse.accessList, null, 2));

    // 2. Type 1 트랜잭션 전송
    const tx = await wallet.sendTransaction({
        to: contractAddress,
        data: txData,
        accessList: accessListResponse.accessList,
        type: 1,  // Type 1 (EIP-2930)
        gasLimit: 100000
    });

    console.log('Transaction hash:', tx.hash);

    const receipt = await tx.wait();
    console.log('Transaction mined:', receipt.transactionHash);
    console.log('Gas used:', receipt.gasUsed.toString());
}

sendWithAccessList().catch(console.error);
```

### 예제 2: 스토리지 키 수동 계산

```javascript
const { ethers } = require('ethers');

// Mapping 스토리지 키 계산
function getMappingKey(address, slot) {
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['address', 'uint256'],
            [address, slot]
        )
    );
}

// Nested mapping: mapping(address => mapping(address => uint256))
function getNestedMappingKey(address1, address2, slot) {
    const innerKey = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['address', 'uint256'],
            [address2, slot]
        )
    );

    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['address', 'bytes32'],
            [address1, innerKey]
        )
    );
}

// Array 스토리지 키 계산
function getArrayElementKey(arraySlot, index) {
    const arrayStart = ethers.BigNumber.from(
        ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(['uint256'], [arraySlot])
        )
    );

    return arrayStart.add(index).toHexString();
}

// 사용 예
const userAddress = "0x1234...";
const tokenAddress = "0x5678...";

// ERC20 allowances: mapping(address => mapping(address => uint256)) (slot 1)
const allowanceKey = getNestedMappingKey(userAddress, tokenAddress, 1);

// Access list 생성
const accessList = [
    {
        address: erc20Address,
        storageKeys: [allowanceKey]
    }
];

const tx = await contract.approve(tokenAddress, amount, { accessList });
```

### 예제 3: 배치 트랜잭션 최적화

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OptimizedBatch {
    mapping(address => uint256) public balances;

    event BatchProcessed(uint256 count);

    // 배치 처리 (Access list 권장)
    function processBatch(
        address[] calldata users,
        uint256[] calldata amounts
    ) external {
        require(users.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            balances[users[i]] += amounts[i];
            // Access list 사용 시: 모두 warm (100 gas)
            // 미사용 시: 첫 번째만 cold (2,100 gas), 나머지 warm (100 gas)
        }

        emit BatchProcessed(users.length);
    }

    // 단일 처리 (Access list 불필요)
    function processSingle(address user, uint256 amount) external {
        balances[user] += amount;
        // 1회만 접근하므로 access list 비효율적
    }
}
```

```javascript
// JavaScript (ethers.js)
const { ethers } = require('ethers');

async function optimizedBatchTransfer() {
    const users = [...];  // 100개 주소
    const amounts = [...];  // 100개 금액

    // 1. Access list 생성
    const storageKeys = users.map(user =>
        ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
            ['address', 'uint256'],
            [user, 0]  // balances slot = 0
        ))
    );

    const accessList = [{
        address: contractAddress,
        storageKeys: storageKeys
    }];

    // 2. 가스 비교
    const gasWithoutAccessList = await contract.estimateGas.processBatch(users, amounts);
    const gasWithAccessList = await contract.estimateGas.processBatch(users, amounts, { accessList });

    console.log('Gas without access list:', gasWithoutAccessList.toString());
    console.log('Gas with access list:', gasWithAccessList.toString());

    // 3. 최적화된 옵션 선택
    if (gasWithAccessList.lt(gasWithoutAccessList)) {
        const tx = await contract.processBatch(users, amounts, { accessList });
        console.log('Sent with access list:', tx.hash);
    } else {
        const tx = await contract.processBatch(users, amounts);
        console.log('Sent without access list:', tx.hash);
    }
}

optimizedBatchTransfer().catch(console.error);
```

### 예제 4: Hardhat 통합

```javascript
// hardhat.config.js
module.exports = {
    solidity: "0.8.20",
    networks: {
        hardhat: {
            hardfork: "berlin"  // EIP-2930 포함
        }
    }
};

// test/AccessList.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Access List", function () {
    it("should use access list for batch operations", async function () {
        const [owner] = await ethers.getSigners();

        // 컨트랙트 배포
        const OptimizedBatch = await ethers.getContractFactory("OptimizedBatch");
        const contract = await OptimizedBatch.deploy();
        await contract.deployed();

        // 배치 데이터
        const users = Array(10).fill(0).map(() => ethers.Wallet.createRandom().address);
        const amounts = Array(10).fill(ethers.utils.parseEther("1"));

        // Access list 생성
        const storageKeys = users.map(user =>
            ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
                ['address', 'uint256'],
                [user, 0]
            ))
        );

        const accessList = [{
            address: contract.address,
            storageKeys: storageKeys
        }];

        // 가스 측정
        const gasWithoutAccessList = await contract.estimateGas.processBatch(users, amounts);
        const gasWithAccessList = await contract.estimateGas.processBatch(users, amounts, { accessList });

        console.log('Gas without access list:', gasWithoutAccessList.toString());
        console.log('Gas with access list:', gasWithAccessList.toString());

        // Access list 사용 트랜잭션 전송
        const tx = await contract.processBatch(users, amounts, { accessList, type: 1 });
        const receipt = await tx.wait();

        console.log('Gas used:', receipt.gasUsed.toString());

        // 검증
        for (let i = 0; i < users.length; i++) {
            const balance = await contract.balances(users[i]);
            expect(balance).to.equal(amounts[i]);
        }
    });
});
```

---

## FAQ

### Q1: Access list는 언제 사용해야 하나요?

**A:**

✅ **사용하면 좋은 경우**:
- 배치 작업으로 여러 주소/스토리지에 반복 접근
- 복잡한 DeFi 작업 (여러 프로토콜 호출)
- 정확한 가스 비용 예측이 중요한 경우
- 3회 이상 같은 스토리지에 접근

❌ **사용하지 않아도 되는 경우**:
- 단순한 트랜잭션 (1~2회 접근)
- 가스 비용이 중요하지 않은 경우
- Access list 생성이 복잡한 경우

### Q2: Type 0/1/2 트랜잭션의 차이는?

**A:**

| 타입 | 이름 | 특징 |
|-----|------|------|
| **Type 0** | Legacy | 기존 방식, `gasPrice` 사용 |
| **Type 1** | EIP-2930 | Access list 포함, `gasPrice` 사용 |
| **Type 2** | EIP-1559 | `maxFeePerGas`/`maxPriorityFeePerGas`, access list 선택사항 |

**Type 2에서도 Access list 사용 가능**:

```javascript
const tx = {
    type: 2,  // EIP-1559
    to: contractAddress,
    data: calldata,
    maxFeePerGas: ethers.utils.parseUnits('50', 'gwei'),
    maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei'),
    accessList: [...]  // 선택사항
};
```

### Q3: eth_createAccessList를 지원하지 않는 노드는?

**A:** **수동으로 스토리지 키를 계산**하거나, **다른 RPC 제공자를 사용**해야 합니다:

```javascript
// Infura, Alchemy 등은 대부분 지원
const provider = new ethers.providers.JsonRpcProvider(
    'https://mainnet.infura.io/v3/YOUR_KEY'
);

try {
    const accessList = await provider.send("eth_createAccessList", [txData]);
} catch (error) {
    console.error('eth_createAccessList not supported:', error);
    // 수동 계산으로 fallback
}
```

### Q4: Access list 비용은 항상 동일한가요?

**A:** **예**, access list 항목당 비용은 고정입니다:

```
- 주소: 2,400 gas
- 스토리지 키: 1,900 gas

예시:
{
    address: "0x...",      // 2,400 gas
    storageKeys: [
        "0x...",           // 1,900 gas
        "0x..."            // 1,900 gas
    ]
}
총: 6,200 gas
```

### Q5: Nested mapping의 스토리지 키는 어떻게 계산하나요?

**A:**

```javascript
// mapping(address => mapping(address => uint256)) allowances (slot 1)

function getNestedMappingKey(owner, spender, slot) {
    // 1. 내부 mapping 키 계산
    const innerKey = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['address', 'uint256'],
            [spender, slot]
        )
    );

    // 2. 외부 mapping 키 계산
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['address', 'bytes32'],
            [owner, innerKey]
        )
    );
}

// ERC20 allowance 스토리지 키
const allowanceKey = getNestedMappingKey(ownerAddress, spenderAddress, 1);
```

### Q6: Access list가 틀리면 어떻게 되나요?

**A:** **트랜잭션은 정상 실행**되지만, 가스 최적화가 제대로 적용되지 않습니다:

```javascript
// 잘못된 access list (존재하지 않는 스토리지 키)
const wrongAccessList = [{
    address: contractAddress,
    storageKeys: ["0x0000..."]  // 잘못된 키
}];

const tx = await contract.myFunction({ accessList: wrongAccessList });
// ✅ 트랜잭션 성공
// ❌ 가스 최적화 효과 없음 (warm 상태 아님)
// 💸 Access list 비용만 낭비
```

### Q7: Access list의 최대 크기는?

**A:** **명시적인 제한은 없지만**, 트랜잭션 가스 한도(Block gas limit)에 의해 제한됩니다:

```
Block gas limit: ~30,000,000 gas (Ethereum Mainnet)

Access list 비용:
- 주소: 2,400 gas
- 스토리지 키: 1,900 gas

이론적 최대:
~15,789개 항목 (주소만)
~30,000,000 / 1,900 ≈ 15,789개 스토리지 키

실제로는 트랜잭션 실행 비용도 포함되므로
수천 개 정도가 현실적 한계
```

### Q8: Access list와 EIP-1153 (Transient Storage)의 관계는?

**A:** **독립적**입니다:

- **EIP-2930 (Access List)**: 영구 스토리지(Storage)의 cold/warm 접근 최적화
- **EIP-1153 (Transient Storage)**: 트랜잭션 내 임시 저장소, 별도의 TSTORE/TLOAD opcodes

```solidity
contract Combined {
    uint256 public permanent;  // Storage (Access list 적용 가능)

    function example() external {
        // 1. Storage 접근 (Access list로 최적화 가능)
        permanent += 1;  // Cold: 2,100 gas → Warm: 100 gas (access list 사용 시)

        // 2. Transient storage 접근 (Access list 무관)
        assembly {
            tstore(0, 123)  // 항상 100 gas
        }
    }
}
```

### Q9: 프론트엔드에서 access list를 사용자에게 보여줘야 하나요?

**A:** **대부분의 경우 자동 처리**하면 됩니다:

```javascript
// 백그라운드에서 자동으로 access list 생성 및 적용
async function sendOptimizedTransaction() {
    // 1. Access list 생성
    const accessListResponse = await provider.send("eth_createAccessList", [txData]);

    // 2. 가스 비교
    const gasWithout = await estimateGas(txData);
    const gasWith = await estimateGas({ ...txData, accessList: accessListResponse.accessList });

    // 3. 더 저렴한 옵션 자동 선택
    if (gasWith.lt(gasWithout)) {
        return sendTransaction({ ...txData, accessList: accessListResponse.accessList });
    } else {
        return sendTransaction(txData);
    }
}
```

### Q10: 실제 프로젝트에서 사용 사례는?

**A:**

1. **Uniswap**: 배치 스왑 작업
2. **Aave**: 다중 토큰 입금/출금
3. **1inch**: 복잡한 라우팅 최적화
4. **Gnosis Safe**: 다중 서명 트랜잭션

```javascript
// 1inch 스타일 최적화
const swapData = await oneInchAPI.getSwapData(...);
const accessList = await provider.send("eth_createAccessList", [{
    to: oneInchRouter,
    data: swapData
}]);

const tx = await oneInchRouter.swap(..., { accessList: accessList.accessList });
```

---

## 참고 자료

### 공식 문서

- [EIP-2930 Specification](https://eips.ethereum.org/EIPS/eip-2930)
- [EIP-2929: Gas Cost Increases](https://eips.ethereum.org/EIPS/eip-2929) - Cold/warm access
- [Ethereum Berlin Upgrade](https://ethereum.org/en/history/#berlin)

### 관련 EIP

- [EIP-1559: Fee Market](https://eips.ethereum.org/EIPS/eip-1559) - Type 2 transaction
- [EIP-2718: Typed Transaction Envelope](https://eips.ethereum.org/EIPS/eip-2718) - Transaction types
- [EIP-155: Replay Protection](https://eips.ethereum.org/EIPS/eip-155)

### 도구 및 라이브러리

- [ethers.js Documentation](https://docs.ethers.io/)
- [Hardhat](https://hardhat.org/)
- [Alchemy API](https://docs.alchemy.com/) - `eth_createAccessList` 지원

---

## 요약

### 핵심 포인트

```
┌─────────────────────────────────────────────┐
│       EIP-2930 한눈에 보기                   │
├─────────────────────────────────────────────┤
│                                             │
│  📋 Access List 미리 선언                    │
│  ⛽ Cold → Warm 변환 (가스 절감)              │
│  🔮 가스 비용 예측 가능                       │
│  🔄 Type 1/2 트랜잭션 지원                   │
│  🎯 복잡한 트랜잭션 최적화                    │
│  📅 Berlin 하드포크 (2021년 4월)             │
│                                             │
└─────────────────────────────────────────────┘

비용:
- 주소: 2,400 gas
- 스토리지 키: 1,900 gas

절감:
- Cold access (2,600 gas) → Warm (100 gas)
- 스토리지 (2,100 gas) → Warm (100 gas)

손익분기점:
→ 1~2회 접근: 약간 이득
→ 3회 이상 접근: 명확한 이득

사용처:
✅ 배치 작업
✅ 복잡한 DeFi 트랜잭션
✅ 가스 비용 예측
✅ 반복적인 스토리지 접근

주의:
❌ 항상 절감되는 것은 아님
❌ 단순 트랜잭션에는 비효율적
❌ 스토리지 레이아웃 이해 필요
```

**EIP-2930은 가스 비용을 예측 가능하게 만들고, 복잡한 트랜잭션에서 최적화를 제공합니다!** 🚀

**마지막 업데이트: 2025**
