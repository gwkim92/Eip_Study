# EIP-1967: Proxy Storage Slots

> **업그레이드 가능한 프록시를 위한 표준 스토리지 슬롯**

## 📋 목차

- [개요](#개요)
- [문제점](#문제점)
- [해결책](#해결책)
- [핵심 개념](#핵심-개념)
- [구현 방법](#구현-방법)
- [실전 예제](#실전-예제)
- [업그레이드 패턴](#업그레이드-패턴)
- [보안 고려사항](#보안-고려사항)
- [OpenZeppelin 사용법](#openzeppelin-사용법)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

**EIP-1967**은 업그레이드 가능한 프록시 컨트랙트에서 **스토리지 충돌을 방지**하기 위한 표준 슬롯을 정의합니다.

### 🎯 핵심 목적

```
프록시 패턴의 가장 큰 문제:
스토리지 충돌! 🔥

해결:
예측 불가능한 위치에 프록시 데이터 저장
→ EIP-1967 표준 슬롯 사용
```

### ⚡ 5초 요약

```solidity
// 표준 슬롯 (충돌 방지)
IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
ADMIN_SLOT         = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
BEACON_SLOT        = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50

// 계산 방법
keccak256("eip1967.proxy.implementation") - 1
```

---

## 문제점

### 스토리지 충돌의 위험성

**프록시 패턴의 기본 원리:**

```
┌──────────────┐           ┌──────────────┐
│    Proxy     │ ─────────▶│  Logic (V1)  │
│              │ delegate  │              │
│ fallback()   │   call    │ functions    │
└──────────────┘           └──────────────┘
       │
       │ 스토리지는 Proxy에 저장됨!
       ▼
  Proxy Storage
```

**문제 발생:**

```solidity
// ❌ 위험한 패턴
contract BadProxy {
    address public implementation;  // slot 0
    address public admin;           // slot 1

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

contract Logic {
    uint256 public value;  // slot 0 - 충돌!
    address public owner;  // slot 1 - 충돌!

    function setValue(uint256 _value) external {
        value = _value;  // implementation 주소 덮어쓰기!
    }
}
```

### 무슨 일이 일어나는가?

```
1. Proxy 배포
   - slot 0: implementation 주소 (0x1234...)
   - slot 1: admin 주소 (0x5678...)

2. Logic.setValue(999) 호출 (delegatecall)
   - Logic은 slot 0에 999 저장하려 함
   - BUT! slot 0은 implementation 주소!
   - implementation = 999 (0x00...03e7)

3. 결과: 컨트랙트 완전 파괴 💥
   - 다음 호출 시 0x00...03e7로 delegatecall
   - 코드 없음 → 모든 함수 실패
```

### 시각화

```
Before setValue():
┌───────────────────┐
│ Proxy Storage     │
├───────────────────┤
│ slot 0: 0x1234... │ ← implementation
│ slot 1: 0x5678... │ ← admin
└───────────────────┘

After setValue(999):
┌───────────────────┐
│ Proxy Storage     │
├───────────────────┤
│ slot 0: 999       │ ← 💥 implementation 덮어쓰기!
│ slot 1: 0x5678... │ ← admin
└───────────────────┘
```

---

## 해결책

### EIP-1967 표준 슬롯

**핵심 아이디어: 예측 불가능한 위치에 저장!**

```solidity
contract SafeProxy {
    // EIP-1967 표준 슬롯
    // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
    bytes32 private constant BEACON_SLOT =
        0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
}
```

### 슬롯 계산 과정

```javascript
// 1. 문자열을 keccak256으로 해시
const hash = keccak256("eip1967.proxy.implementation");
// = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbd

// 2. 1을 뺌 (충돌 확률 더 낮춤)
const slot = hash - 1;
// = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

**왜 1을 빼는가?**

```
1. keccak256의 출력값은 이미 충분히 랜덤
2. 하지만 Solidity는 keccak256(bytes)를 다른 용도로 사용
3. -1을 해서 더 확실하게 분리
4. 공식 EIP 표준으로 명시됨
```

### 작동 원리

```
┌─────────────────────────────────────────┐
│ Proxy Storage Layout                    │
├─────────────────────────────────────────┤
│ slot 0: Logic variable 1                │
│ slot 1: Logic variable 2                │
│ slot 2: Logic variable 3                │
│ ...                                     │
│ slot 0x360894...: implementation        │ ← EIP-1967
│ slot 0xb53127...: admin                 │ ← EIP-1967
│ slot 0xa3f0ad...: beacon                │ ← EIP-1967
└─────────────────────────────────────────┘

✅ Logic 변수들이 slot 0x360894...에 도달할 확률 = 거의 0
```

---

## 핵심 개념

### 1. 세 가지 표준 슬롯

#### IMPLEMENTATION_SLOT

```solidity
// 구현 컨트랙트 주소 저장
bytes32 private constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

// 계산 방법
bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
```

**용도:**
- 현재 로직 컨트랙트 주소
- 업그레이드 시 변경됨
- fallback에서 delegatecall 대상

#### ADMIN_SLOT

```solidity
// 관리자 주소 저장
bytes32 private constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

// 계산 방법
bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
```

**용도:**
- 업그레이드 권한 주소
- 보통 ProxyAdmin 컨트랙트
- 권한 관리

#### BEACON_SLOT

```solidity
// Beacon 주소 저장 (Beacon Proxy 패턴)
bytes32 private constant BEACON_SLOT =
    0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

// 계산 방법
bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
```

**용도:**
- Beacon Proxy 패턴에서 사용
- Beacon에서 구현 주소 조회
- 여러 프록시가 하나의 Beacon 공유

### 2. Assembly 사용 패턴

**슬롯에서 읽기:**

```solidity
function _getImplementation() internal view returns (address impl) {
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
        impl := sload(slot)  // sload: 스토리지에서 로드
    }
}
```

**슬롯에 쓰기:**

```solidity
function _setImplementation(address newImplementation) private {
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
        sstore(slot, newImplementation)  // sstore: 스토리지에 저장
    }
}
```

**왜 Assembly를 사용하는가?**

```
1. Solidity는 임의의 슬롯에 직접 접근 불가
2. Assembly (Yul)로 sload/sstore 사용
3. 가스 최적화 효과도 있음
```

### 3. delegatecall 원리

```solidity
fallback() external payable {
    address impl = _getImplementation();

    assembly {
        // 1. calldata 복사
        calldatacopy(0, 0, calldatasize())

        // 2. delegatecall 실행
        let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

        // 3. 반환 데이터 복사
        returndatacopy(0, 0, returndatasize())

        // 4. 성공/실패 처리
        switch result
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}
```

**delegatecall의 특징:**

```
┌──────────────┐           ┌──────────────┐
│    Proxy     │ ─────────▶│  Logic (V1)  │
├──────────────┤           ├──────────────┤
│ msg.sender   │           │ Proxy의 msg.sender 사용
│ msg.value    │           │ Proxy의 msg.value 사용
│ storage      │◀──────────│ Proxy의 storage 사용
│ balance      │           │ Proxy의 balance 사용
└──────────────┘           └──────────────┘
              └─ Logic의 code만 실행
```

### 4. 이벤트 표준

```solidity
// 업그레이드 이벤트
event Upgraded(address indexed implementation);

// 관리자 변경 이벤트
event AdminChanged(address previousAdmin, address newAdmin);

// Beacon 변경 이벤트
event BeaconUpgraded(address indexed beacon);
```

---

## 구현 방법

### 패턴 1: 기본 EIP-1967 Proxy

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EIP1967Proxy {
    // EIP-1967 표준 슬롯
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // 이벤트
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    constructor(address _logic, address _admin, bytes memory _data) payable {
        _setImplementation(_logic);
        _setAdmin(_admin);
        emit Upgraded(_logic);
        emit AdminChanged(address(0), _admin);

        if (_data.length > 0) {
            (bool success,) = _logic.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    // fallback: 모든 호출을 로직 컨트랙트로 위임
    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {}

    // 업그레이드 (관리자만)
    function upgradeTo(address newImplementation) external {
        require(msg.sender == _getAdmin(), "Not admin");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    // 업그레이드 + 초기화
    function upgradeToAndCall(address newImplementation, bytes calldata data)
        external
        payable
    {
        require(msg.sender == _getAdmin(), "Not admin");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Upgrade call failed");
        }
    }

    // 관리자 변경
    function changeAdmin(address newAdmin) external {
        require(msg.sender == _getAdmin(), "Not admin");
        address previousAdmin = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(previousAdmin, newAdmin);
    }

    // 조회 함수
    function admin() external view returns (address) {
        return _getAdmin();
    }

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    // 내부 함수들
    function _delegate(address _implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "Not a contract");

        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _getAdmin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
}
```

### 패턴 2: Logic 컨트랙트 (V1)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LogicV1 {
    // 스토리지 레이아웃
    bool private initialized;
    address public owner;
    uint256 public counter;
    string public name;

    // 이벤트
    event Initialized(address indexed owner, string name);
    event CounterIncremented(uint256 newValue);

    // Modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // 초기화 (constructor 대신)
    function initialize(address _owner, string memory _name) external {
        require(!initialized, "Already initialized");
        require(_owner != address(0), "Zero address");

        initialized = true;
        owner = _owner;
        name = _name;
        counter = 0;

        emit Initialized(_owner, _name);
    }

    // 핵심 기능
    function increment() external returns (uint256) {
        counter += 1;
        emit CounterIncremented(counter);
        return counter;
    }

    function decrement() external returns (uint256) {
        require(counter > 0, "Already zero");
        counter -= 1;
        return counter;
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }

    function getInfo()
        external
        view
        returns (string memory, uint256, address)
    {
        return (name, counter, owner);
    }

    // 관리 기능
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}
```

### 패턴 3: Logic 컨트랙트 (V2 - 업그레이드)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LogicV2 {
    // ⚠️ 중요: 기존 스토리지 레이아웃 유지!
    bool private initialized;    // slot 0 - 유지
    address public owner;        // slot 1 - 유지
    uint256 public counter;      // slot 2 - 유지
    string public name;          // slot 3 - 유지

    // ✅ 새 변수는 끝에 추가
    uint256 public multiplier;   // slot 4 - 새로 추가
    mapping(address => uint256) public userCounters;  // slot 5

    // 이벤트
    event CounterIncremented(uint256 newValue);
    event CounterMultiplied(uint256 newValue);
    event MultiplierSet(uint256 multiplier);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // V2 초기화 (multiplier 설정)
    function initializeV2(uint256 _multiplier) external {
        require(initialized, "Not initialized");
        require(multiplier == 0, "V2 already initialized");

        multiplier = _multiplier;
        emit MultiplierSet(_multiplier);
    }

    // V1 함수 유지
    function increment() external returns (uint256) {
        counter += 1;
        emit CounterIncremented(counter);
        return counter;
    }

    function decrement() external returns (uint256) {
        require(counter > 0, "Already zero");
        counter -= 1;
        return counter;
    }

    // V2 새 기능
    function multiplyCounter() external returns (uint256) {
        require(multiplier > 0, "Multiplier not set");
        counter *= multiplier;
        emit CounterMultiplied(counter);
        return counter;
    }

    function setMultiplier(uint256 _multiplier) external onlyOwner {
        multiplier = _multiplier;
        emit MultiplierSet(_multiplier);
    }

    function incrementUserCounter() external {
        userCounters[msg.sender] += 1;
    }

    function getUserCounter(address user) external view returns (uint256) {
        return userCounters[user];
    }

    // V1 함수들
    function getCounter() external view returns (uint256) {
        return counter;
    }

    function getInfo()
        external
        view
        returns (string memory, uint256, address)
    {
        return (name, counter, owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}
```

### 패턴 4: ProxyAdmin 컨트랙트

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProxy {
    function admin() external view returns (address);
    function implementation() external view returns (address);
    function changeAdmin(address newAdmin) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract ProxyAdmin {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ProxyAdmin의 소유자 변경
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    // 프록시 조회
    function getProxyImplementation(IProxy proxy)
        external
        view
        returns (address)
    {
        return proxy.implementation();
    }

    function getProxyAdmin(IProxy proxy) external view returns (address) {
        return proxy.admin();
    }

    // 프록시 관리 (소유자만)
    function changeProxyAdmin(IProxy proxy, address newAdmin) external onlyOwner {
        proxy.changeAdmin(newAdmin);
    }

    function upgrade(IProxy proxy, address implementation) external onlyOwner {
        proxy.upgradeTo(implementation);
    }

    function upgradeAndCall(
        IProxy proxy,
        address implementation,
        bytes memory data
    ) external payable onlyOwner {
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
    }
}
```

---

## 실전 예제

### 예제 1: 전체 배포 플로우

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EIP1967Proxy.sol";
import "./LogicV1.sol";
import "./LogicV2.sol";
import "./ProxyAdmin.sol";

contract DeploymentExample {
    function deployFullStack() external returns (
        address proxyAddress,
        address adminAddress,
        address logicV1Address
    ) {
        // 1. ProxyAdmin 배포
        ProxyAdmin admin = new ProxyAdmin();
        adminAddress = address(admin);

        // 2. LogicV1 배포
        LogicV1 logic = new LogicV1();
        logicV1Address = address(logic);

        // 3. 초기화 데이터 준비
        bytes memory initData = abi.encodeWithSelector(
            LogicV1.initialize.selector,
            msg.sender,  // owner
            "MyContract V1"  // name
        );

        // 4. Proxy 배포
        EIP1967Proxy proxy = new EIP1967Proxy(
            address(logic),
            address(admin),
            initData
        );
        proxyAddress = address(proxy);

        return (proxyAddress, adminAddress, logicV1Address);
    }

    function upgradeToV2(
        address proxyAddress,
        address adminAddress
    ) external returns (address logicV2Address) {
        // 1. LogicV2 배포
        LogicV2 logicV2 = new LogicV2();
        logicV2Address = address(logicV2);

        // 2. V2 초기화 데이터
        bytes memory initData = abi.encodeWithSelector(
            LogicV2.initializeV2.selector,
            2  // multiplier
        );

        // 3. 업그레이드 실행
        ProxyAdmin(adminAddress).upgradeAndCall(
            IProxy(proxyAddress),
            address(logicV2),
            initData
        );

        return logicV2Address;
    }
}
```

### 예제 2: 사용자 관점

```solidity
function useProxy() external {
    address proxyAddr = 0x...; // 배포된 프록시 주소

    // 프록시를 LogicV1로 캐스팅해서 사용
    LogicV1 instance = LogicV1(proxyAddr);

    // V1 기능 사용
    instance.increment();
    uint256 count = instance.getCounter();
    console.log("Counter:", count);

    // --- 업그레이드 후 ---

    // 같은 주소, LogicV2로 캐스팅
    LogicV2 instanceV2 = LogicV2(proxyAddr);

    // 기존 데이터 유지됨
    count = instanceV2.getCounter();  // 이전 값 그대로

    // V2 새 기능 사용
    instanceV2.multiplyCounter();
    instanceV2.incrementUserCounter();
}
```

### 예제 3: Hardhat 배포 스크립트

```javascript
// scripts/deploy.js
const { ethers, upgrades } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log('Deploying with account:', deployer.address);

    // 1. Logic V1 배포
    const LogicV1 = await ethers.getContractFactory('LogicV1');
    const logicV1 = await LogicV1.deploy();
    await logicV1.deployed();
    console.log('LogicV1 deployed to:', logicV1.address);

    // 2. ProxyAdmin 배포
    const ProxyAdmin = await ethers.getContractFactory('ProxyAdmin');
    const admin = await ProxyAdmin.deploy();
    await admin.deployed();
    console.log('ProxyAdmin deployed to:', admin.address);

    // 3. 초기화 데이터 준비
    const initData = LogicV1.interface.encodeFunctionData('initialize', [
        deployer.address,
        'MyContract V1'
    ]);

    // 4. Proxy 배포
    const Proxy = await ethers.getContractFactory('EIP1967Proxy');
    const proxy = await Proxy.deploy(
        logicV1.address,
        admin.address,
        initData
    );
    await proxy.deployed();
    console.log('Proxy deployed to:', proxy.address);

    // 5. Proxy를 LogicV1 인터페이스로 사용
    const instance = LogicV1.attach(proxy.address);

    // 6. 테스트
    await instance.increment();
    const counter = await instance.getCounter();
    console.log('Counter:', counter.toString());

    return {
        proxy: proxy.address,
        admin: admin.address,
        logicV1: logicV1.address
    };
}

// 업그레이드 스크립트
async function upgrade(proxyAddress, adminAddress) {
    const [deployer] = await ethers.getSigners();

    // 1. LogicV2 배포
    const LogicV2 = await ethers.getContractFactory('LogicV2');
    const logicV2 = await LogicV2.deploy();
    await logicV2.deployed();
    console.log('LogicV2 deployed to:', logicV2.address);

    // 2. V2 초기화 데이터
    const initData = LogicV2.interface.encodeFunctionData('initializeV2', [2]);

    // 3. ProxyAdmin으로 업그레이드
    const admin = await ethers.getContractAt('ProxyAdmin', adminAddress);
    const tx = await admin.upgradeAndCall(proxyAddress, logicV2.address, initData);
    await tx.wait();

    console.log('Upgraded to V2');

    // 4. V2로 테스트
    const instanceV2 = LogicV2.attach(proxyAddress);
    await instanceV2.multiplyCounter();
    const counter = await instanceV2.getCounter();
    console.log('Counter after multiply:', counter.toString());

    return logicV2.address;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### 예제 4: Frontend 통합 (ethers.js)

```javascript
import { ethers } from 'ethers';
import LogicV1ABI from './abis/LogicV1.json';
import LogicV2ABI from './abis/LogicV2.json';
import ProxyABI from './abis/EIP1967Proxy.json';

const provider = new ethers.JsonRpcProvider('https://...');
const signer = provider.getSigner();

const PROXY_ADDRESS = '0x...';
const ADMIN_ADDRESS = '0x...';

// V1 사용
async function useV1() {
    const contract = new ethers.Contract(
        PROXY_ADDRESS,
        LogicV1ABI,
        signer
    );

    // 함수 호출
    const tx = await contract.increment();
    await tx.wait();

    const counter = await contract.getCounter();
    console.log('Counter:', counter.toString());

    const [name, count, owner] = await contract.getInfo();
    console.log('Name:', name);
    console.log('Counter:', count.toString());
    console.log('Owner:', owner);
}

// 프록시 정보 조회
async function getProxyInfo() {
    const proxy = new ethers.Contract(PROXY_ADDRESS, ProxyABI, provider);

    const implementation = await proxy.implementation();
    const admin = await proxy.admin();

    console.log('Implementation:', implementation);
    console.log('Admin:', admin);

    return { implementation, admin };
}

// V2로 업그레이드 후 사용
async function useV2() {
    const contract = new ethers.Contract(
        PROXY_ADDRESS,  // 같은 주소!
        LogicV2ABI,     // V2 ABI 사용
        signer
    );

    // V1 함수 (여전히 동작)
    await contract.increment();

    // V2 새 함수
    await contract.multiplyCounter();
    await contract.incrementUserCounter();

    const userCounter = await contract.getUserCounter(await signer.getAddress());
    console.log('User counter:', userCounter.toString());
}

// 업그레이드 모니터링 (이벤트 리스닝)
async function monitorUpgrades() {
    const proxy = new ethers.Contract(PROXY_ADDRESS, ProxyABI, provider);

    proxy.on('Upgraded', (implementation) => {
        console.log('Upgraded to:', implementation);
        // UI 업데이트, 사용자에게 알림 등
    });

    proxy.on('AdminChanged', (previousAdmin, newAdmin) => {
        console.log('Admin changed from', previousAdmin, 'to', newAdmin);
    });
}
```

---

## 업그레이드 패턴

### 안전한 업그레이드 체크리스트

#### ✅ 해야 할 것

```solidity
contract SafeUpgrade {
    // 1. 기존 변수 순서 유지
    bool private initialized;    // slot 0
    address public owner;        // slot 1
    uint256 public counter;      // slot 2

    // 2. 새 변수는 끝에 추가
    uint256 public newVariable;  // slot 3
    mapping(address => uint256) public newMapping;  // slot 4

    // 3. 함수는 자유롭게 수정
    function newFunction() external {}

    // 4. V2 초기화 함수 추가
    function initializeV2() external {
        require(initialized, "Not initialized");
        // V2 초기화 로직...
    }
}
```

#### ❌ 하면 안 되는 것

```solidity
contract DangerousUpgrade {
    // ❌ 1. 기존 변수 순서 변경
    address public owner;   // 원래 slot 1
    bool private initialized;  // 원래 slot 0 - 순서 바뀜!

    // ❌ 2. 기존 변수 타입 변경
    address public counter;  // 원래 uint256 - 타입 변경!

    // ❌ 3. 기존 변수 삭제/주석
    // bool private initialized;  // 삭제됨!

    // ❌ 4. 기존 변수 사이에 새 변수 삽입
    bool private initialized;
    uint256 public newVar;   // ❌ 중간 삽입!
    address public owner;
}
```

### 스토리지 레이아웃 검증

```javascript
// Hardhat 플러그인 사용
const { upgrades } = require('hardhat');

// 업그레이드 검증
await upgrades.upgradeProxy(proxyAddress, LogicV2Factory);
// ✅ 자동으로 스토리지 레이아웃 검증
// ❌ 충돌 발견 시 에러 발생
```

**수동 검증 도구:**

```javascript
// scripts/checkStorage.js
const { ethers } = require('hardhat');
const { getStorageLayout } = require('@openzeppelin/upgrades-core');

async function compareLayouts() {
    const V1 = await ethers.getContractFactory('LogicV1');
    const V2 = await ethers.getContractFactory('LogicV2');

    const layoutV1 = await getStorageLayout(V1);
    const layoutV2 = await getStorageLayout(V2);

    console.log('V1 Storage Layout:');
    console.log(JSON.stringify(layoutV1, null, 2));

    console.log('\nV2 Storage Layout:');
    console.log(JSON.stringify(layoutV2, null, 2));

    // 충돌 검사
    for (let i = 0; i < layoutV1.storage.length; i++) {
        const v1 = layoutV1.storage[i];
        const v2 = layoutV2.storage[i];

        if (!v2) {
            console.error(`⚠️ V2에서 ${v1.label} 삭제됨!`);
        } else if (v1.type !== v2.type) {
            console.error(`⚠️ ${v1.label} 타입 변경: ${v1.type} → ${v2.type}`);
        }
    }
}
```

### 업그레이드 패턴 비교

#### 패턴 1: Transparent Proxy (EIP-1967 기본)

```
장점:
✅ Admin/User 호출 명확히 분리
✅ 가장 안전하고 예측 가능
✅ OpenZeppelin 표준

단점:
❌ Admin 호출 시 gas 소비 (admin 체크)
❌ 복잡도 높음
```

#### 패턴 2: UUPS (Universal Upgradeable Proxy Standard)

```
장점:
✅ Gas 효율적 (업그레이드 로직이 구현 컨트랙트에)
✅ Proxy 단순함

단점:
❌ 구현 실수 시 업그레이드 불가능
❌ 모든 버전에 업그레이드 로직 필요
```

#### 패턴 3: Beacon Proxy

```
장점:
✅ 여러 프록시 동시 업그레이드
✅ 가스 효율적 (구현 주소 한 곳에만 저장)

단점:
❌ 추가 컨트랙트 필요 (Beacon)
❌ 개별 업그레이드 불가
```

---

## 보안 고려사항

### 1. Storage Collision

**문제:**

```solidity
// ❌ 위험: 일반 슬롯 사용
contract BadProxy {
    address public implementation;  // slot 0 - 충돌 위험!
}
```

**해결:**

```solidity
// ✅ 안전: EIP-1967 슬롯
contract SafeProxy {
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
}
```

### 2. Function Selector Clash

**문제:**

```solidity
// Proxy의 upgradeTo() vs Logic의 다른 함수
// 함수 시그니처 충돌 가능
```

**해결 (Transparent Proxy 패턴):**

```solidity
fallback() external payable {
    // Admin 호출: 프록시 함수 실행
    if (msg.sender == _getAdmin()) {
        // admin() 또는 upgradeTo() 등
        // 로직으로 위임하지 않음
    } else {
        // User 호출: 로직으로 위임
        _delegate(_getImplementation());
    }
}
```

### 3. Uninitialized Implementation

**문제:**

```solidity
// ❌ 위험: constructor 사용
contract BadLogic {
    address public owner;

    constructor() {
        owner = msg.sender;  // Proxy에서 무시됨!
    }
}
```

**해결:**

```solidity
// ✅ 안전: initialize 함수
contract SafeLogic {
    bool private initialized;
    address public owner;

    function initialize(address _owner) external {
        require(!initialized, "Already initialized");
        initialized = true;
        owner = _owner;
    }
}
```

### 4. Selfdestruct in Logic

**문제:**

```solidity
// ❌ 매우 위험!
contract DangerousLogic {
    function destroy() external {
        selfdestruct(payable(msg.sender));
        // Logic 컨트랙트 파괴
        // Proxy에서 호출 불가능해짐!
    }
}
```

**해결:**

```
1. selfdestruct 절대 사용 금지
2. delegatecall은 Logic의 코드만 사용
3. Logic 파괴 = 모든 프록시 파괴
```

### 5. Storage Layout Change

**문제:**

```solidity
// V1
contract V1 {
    uint256 public value;   // slot 0
    address public owner;   // slot 1
}

// ❌ V2: 순서 변경
contract V2 {
    address public owner;   // slot 0 - 문제!
    uint256 public value;   // slot 1 - 문제!
}

// V1의 value 값이 V2의 owner로 해석됨!
```

**해결:**

```solidity
// ✅ V2: 순서 유지
contract V2 {
    uint256 public value;   // slot 0 - 유지
    address public owner;   // slot 1 - 유지
    uint256 public newVar;  // slot 2 - 끝에 추가
}
```

### 6. Initialization Front-running

**문제:**

```javascript
// 1. Proxy 배포 (초기화 없이)
const proxy = await Proxy.deploy(logic, admin, '0x');

// 2. 나중에 초기화 (위험!)
await logic.initialize(owner);

// ⚠️ 공격자가 먼저 initialize() 호출 가능!
```

**해결:**

```javascript
// ✅ 배포 시 즉시 초기화
const initData = logic.interface.encodeFunctionData('initialize', [owner]);
const proxy = await Proxy.deploy(logic, admin, initData);
```

### 7. Admin Privilege

**문제:**

```
Admin이 악의적으로 행동하면?
→ 악성 로직으로 업그레이드
→ 모든 자금 탈취 가능
```

**해결:**

```solidity
// 1. Timelock 사용
ProxyAdmin + Timelock Controller

// 2. Multi-sig 사용
Gnosis Safe as ProxyAdmin

// 3. DAO 거버넌스
투표로 업그레이드 결정
```

---

## OpenZeppelin 사용법

### 설치

```bash
npm install @openzeppelin/contracts-upgradeable @openzeppelin/hardhat-upgrades
```

### 기본 사용

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyContractV1 is Initializable, OwnableUpgradeable {
    uint256 public counter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        counter = 0;
    }

    function increment() external {
        counter += 1;
    }
}
```

### Hardhat 배포

```javascript
// scripts/deploy.js
const { ethers, upgrades } = require('hardhat');

async function main() {
    // 1. 배포 (자동으로 Proxy + Admin 생성)
    const MyContract = await ethers.getContractFactory('MyContractV1');
    const proxy = await upgrades.deployProxy(
        MyContract,
        [ownerAddress],  // initializer 인자
        { initializer: 'initialize' }
    );
    await proxy.deployed();

    console.log('Proxy deployed to:', proxy.address);
    console.log('Implementation:', await upgrades.erc1967.getImplementationAddress(proxy.address));
    console.log('Admin:', await upgrades.erc1967.getAdminAddress(proxy.address));
}

// 업그레이드
async function upgrade(proxyAddress) {
    const MyContractV2 = await ethers.getContractFactory('MyContractV2');

    // 자동 스토리지 검증
    const upgraded = await upgrades.upgradeProxy(proxyAddress, MyContractV2);

    console.log('Upgraded:', upgraded.address);
}
```

### V2 작성

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyContractV2 is Initializable, OwnableUpgradeable {
    uint256 public counter;        // 기존 변수
    uint256 public multiplier;     // 새 변수

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        counter = 0;
    }

    // V2 초기화
    function initializeV2(uint256 _multiplier) public reinitializer(2) {
        multiplier = _multiplier;
    }

    // 기존 함수
    function increment() external {
        counter += 1;
    }

    // 새 함수
    function multiply() external {
        counter *= multiplier;
    }
}
```

### UUPS 패턴

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyUUPSContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        value = 0;
    }

    // UUPS 필수: 업그레이드 권한 체크
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function setValue(uint256 _value) external {
        value = _value;
    }
}
```

```javascript
// 배포
const proxy = await upgrades.deployProxy(MyUUPSContract, [owner], {
    kind: 'uups'
});
```

---

## FAQ

### Q1. EIP-1967과 EIP-1822(UUPS)의 차이는?

**A:**
```
EIP-1967: 스토리지 슬롯 표준
         → IMPLEMENTATION_SLOT, ADMIN_SLOT 등

EIP-1822 (UUPS): 업그레이드 패턴
         → 업그레이드 로직이 구현 컨트랙트에 있음

→ UUPS도 EIP-1967 슬롯을 사용함!
```

### Q2. 슬롯 계산에서 왜 -1을 하나요?

**A:**
```javascript
// 1. keccak256 출력은 이미 랜덤
const hash = keccak256("eip1967.proxy.implementation");

// 2. -1을 해서 더 확실하게 분리
const slot = hash - 1;

이유:
- Solidity는 keccak256(abi.encode(...))를 많이 사용
- 동적 배열, 매핑 등도 keccak256 사용
- -1로 추가 분리 → 충돌 확률 0에 가깝게
```

### Q3. constructor vs initialize의 차이?

**A:**
```solidity
// ❌ Proxy에서 constructor는 무시됨
contract BadLogic {
    address public owner;

    constructor() {
        owner = msg.sender;  // Logic 배포 시만 실행됨
        // Proxy를 통한 호출에서는 무시!
    }
}

// ✅ initialize 사용
contract GoodLogic {
    bool private initialized;
    address public owner;

    function initialize() external {
        require(!initialized);
        initialized = true;
        owner = msg.sender;  // Proxy 컨텍스트에서 실행됨
    }
}
```

### Q4. 업그레이드 시 데이터는 유지되나요?

**A:**
```
✅ 유지됨!

1. Storage는 Proxy에 저장됨
2. 업그레이드 = 구현 주소만 변경
3. Storage는 그대로

예:
V1: counter = 100
↓ 업그레이드
V2: counter = 100 (유지)
```

### Q5. 여러 프록시가 하나의 Logic을 공유할 수 있나요?

**A:**
```
✅ 가능하고 권장됨!

┌─────────┐
│ Logic   │◀─── delegatecall
└─────────┘
     ▲
     │
┌────┴─────┬─────────┬─────────┐
│ Proxy1   │ Proxy2  │ Proxy3  │
│ (data 1) │ (data 2)│ (data 3)│
└──────────┴─────────┴─────────┘

- Logic은 1번만 배포
- 각 Proxy는 독립적 storage
- 가스 절감!
```

### Q6. Admin을 잃어버리면?

**A:**
```
❌ 업그레이드 불가능!

예방:
1. Multi-sig 사용 (Gnosis Safe)
2. Timelock 사용
3. Admin을 다른 컨트랙트로 (복구 로직 포함)
4. 배포 직후 즉시 확인

만약 잃어버렸다면:
- 해당 프록시는 영원히 현재 버전
- 데이터 마이그레이션으로 새 프록시 배포
```

### Q7. selfdestruct를 Logic에 넣으면?

**A:**
```
💀 절대 금지!

contract DangerousLogic {
    function destroy() external {
        selfdestruct(payable(msg.sender));
    }
}

결과:
1. Logic 컨트랙트 파괴됨
2. 모든 Proxy에서 delegatecall 실패
3. 복구 불가능

→ Logic에는 selfdestruct 절대 사용 금지!
```

### Q8. Gas 비용은?

**A:**
```
추가 비용 (vs 일반 컨트랙트):
- delegatecall 오버헤드: ~700 gas
- Storage 로드 (implementation): ~2,100 gas
- 총 ~2,800 gas 추가

장점:
- 업그레이드 가능성
- 버그 수정 가능
- 새 기능 추가 가능

→ 대부분의 경우 trade-off 가치 있음
```

---

## 참고 자료

### 공식 문서
- [EIP-1967 Specification](https://eips.ethereum.org/EIPS/eip-1967)
- [EIP-1822: Universal Upgradeable Proxy Standard (UUPS)](https://eips.ethereum.org/EIPS/eip-1822)
- [OpenZeppelin Proxy Documentation](https://docs.openzeppelin.com/contracts/4.x/api/proxy)

### 구현 예제
- [OpenZeppelin ERC1967Proxy](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/ERC1967/ERC1967Proxy.sol)
- [OpenZeppelin TransparentUpgradeableProxy](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol)
- [OpenZeppelin UUPSUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/proxy/utils/UUPSUpgradeable.sol)

### 학습 자료
- [OpenZeppelin Upgrades Plugins](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [Proxy Patterns](https://blog.openzeppelin.com/proxy-patterns/)
- [Writing Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)

### 도구
- [@openzeppelin/hardhat-upgrades](https://www.npmjs.com/package/@openzeppelin/hardhat-upgrades)
- [@openzeppelin/truffle-upgrades](https://www.npmjs.com/package/@openzeppelin/truffle-upgrades)

---

## 라이센스

MIT License

---

**마지막 업데이트:** 2025
**버전:** 1.0.0

**핵심 포인트:**
- 🔒 스토리지 충돌 방지를 위한 표준 슬롯
- 🎯 keccak256("eip1967.proxy.xxx") - 1 방식
- 🔄 업그레이드 가능한 컨트랙트의 핵심
- ⚡ delegatecall로 코드 재사용
- 🛡️ 안전한 업그레이드 패턴 필수
