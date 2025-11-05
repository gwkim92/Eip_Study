# EIP-1967 Cheat Sheet

> **빠른 참조** - 프록시 스토리지 슬롯 표준

## 🎯 핵심 (5초)

```
문제: 프록시 패턴에서 스토리지 충돌 💥
해결: 예측 불가능한 위치에 저장

→ keccak256("eip1967.proxy.xxx") - 1
```

## 📝 3가지 표준 슬롯

```solidity
// 1. Implementation Slot
bytes32 private constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
// = keccak256("eip1967.proxy.implementation") - 1

// 2. Admin Slot
bytes32 private constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
// = keccak256("eip1967.proxy.admin") - 1

// 3. Beacon Slot
bytes32 private constant BEACON_SLOT =
    0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
// = keccak256("eip1967.proxy.beacon") - 1
```

## 💻 기본 Proxy 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EIP1967Proxy {
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    constructor(address _logic, address _admin, bytes memory _data) payable {
        _setImplementation(_logic);
        _setAdmin(_admin);

        if (_data.length > 0) {
            (bool success,) = _logic.delegatecall(_data);
            require(success);
        }
    }

    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {}

    function _delegate(address impl) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly { impl := sload(slot) }
    }

    function _setImplementation(address newImpl) private {
        require(newImpl.code.length > 0);
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly { sstore(slot, newImpl) }
    }

    function _getAdmin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly { adm := sload(slot) }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly { sstore(slot, newAdmin) }
    }
}
```

## 🔧 Logic 컨트랙트 (V1)

```solidity
contract LogicV1 {
    // 스토리지 레이아웃
    bool private initialized;
    address public owner;
    uint256 public counter;

    // ❌ constructor 사용 금지!
    // ✅ initialize 함수 사용
    function initialize(address _owner) external {
        require(!initialized, "Already initialized");
        initialized = true;
        owner = _owner;
        counter = 0;
    }

    function increment() external {
        counter += 1;
    }
}
```

## 🔄 Logic 컨트랙트 (V2)

```solidity
contract LogicV2 {
    // ⚠️ 기존 레이아웃 유지 필수!
    bool private initialized;    // slot 0 - 유지
    address public owner;        // slot 1 - 유지
    uint256 public counter;      // slot 2 - 유지

    // ✅ 새 변수는 끝에 추가
    uint256 public multiplier;   // slot 3

    function initialize(address _owner) external {
        require(!initialized);
        initialized = true;
        owner = _owner;
        counter = 0;
    }

    // V2 초기화
    function initializeV2(uint256 _multiplier) external {
        require(initialized);
        require(multiplier == 0);
        multiplier = _multiplier;
    }

    function increment() external {
        counter += 1;
    }

    // V2 새 기능
    function multiply() external {
        counter *= multiplier;
    }
}
```

## 🚀 배포 (Hardhat)

```javascript
const { ethers } = require('hardhat');

async function deploy() {
    // 1. Logic 배포
    const LogicV1 = await ethers.getContractFactory('LogicV1');
    const logic = await LogicV1.deploy();

    // 2. 초기화 데이터
    const initData = LogicV1.interface.encodeFunctionData('initialize', [
        owner
    ]);

    // 3. Proxy 배포
    const Proxy = await ethers.getContractFactory('EIP1967Proxy');
    const proxy = await Proxy.deploy(
        logic.address,
        admin.address,
        initData
    );

    // 4. Proxy를 Logic 인터페이스로 사용
    const instance = LogicV1.attach(proxy.address);
    await instance.increment();

    return proxy.address;
}

// 업그레이드
async function upgrade(proxyAddress) {
    const LogicV2 = await ethers.getContractFactory('LogicV2');
    const logicV2 = await LogicV2.deploy();

    const initData = LogicV2.interface.encodeFunctionData('initializeV2', [2]);

    const admin = await ethers.getContractAt('ProxyAdmin', adminAddress);
    await admin.upgradeAndCall(proxyAddress, logicV2.address, initData);
}
```

## 🌐 OpenZeppelin 사용

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

```javascript
// 배포
const { ethers, upgrades } = require('hardhat');

const MyContract = await ethers.getContractFactory('MyContractV1');
const proxy = await upgrades.deployProxy(MyContract, [owner]);

// 업그레이드
const MyContractV2 = await ethers.getContractFactory('MyContractV2');
const upgraded = await upgrades.upgradeProxy(proxy.address, MyContractV2);
```

## ⚠️ 업그레이드 체크리스트

### ✅ 해야 할 것

```solidity
contract SafeUpgrade {
    // 1. 기존 변수 순서 유지
    bool private initialized;
    address public owner;
    uint256 public counter;

    // 2. 새 변수는 끝에 추가
    uint256 public newVar;

    // 3. 함수는 자유롭게 수정
    function newFunction() external {}

    // 4. V2 초기화 함수
    function initializeV2() external {}
}
```

### ❌ 하면 안 되는 것

```solidity
contract DangerousUpgrade {
    // ❌ 1. 순서 변경
    address public owner;   // 원래 slot 1
    bool private initialized;  // 원래 slot 0

    // ❌ 2. 타입 변경
    address public counter;  // 원래 uint256

    // ❌ 3. 변수 삭제
    // bool private initialized;

    // ❌ 4. 중간 삽입
    bool private initialized;
    uint256 public newVar;  // ❌
    address public owner;

    // ❌ 5. selfdestruct 사용
    function destroy() external {
        selfdestruct(payable(msg.sender));  // 절대 금지!
    }
}
```

## 🔒 보안 패턴

### Storage 읽기/쓰기

```solidity
// 읽기
function _getImplementation() internal view returns (address impl) {
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
        impl := sload(slot)
    }
}

// 쓰기
function _setImplementation(address newImpl) private {
    require(newImpl.code.length > 0);
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
        sstore(slot, newImpl)
    }
}
```

### 초기화 Front-running 방지

```javascript
// ❌ 위험
const proxy = await Proxy.deploy(logic, admin, '0x');
await logic.initialize(owner);  // 공격자가 먼저 호출 가능!

// ✅ 안전
const initData = logic.interface.encodeFunctionData('initialize', [owner]);
const proxy = await Proxy.deploy(logic, admin, initData);  // 즉시 초기화
```

### Admin 권한 관리

```solidity
// 1. Multi-sig 사용
Gnosis Safe as ProxyAdmin

// 2. Timelock 사용
TimelockController + ProxyAdmin

// 3. DAO 거버넌스
투표로 업그레이드 결정
```

## 📊 슬롯 계산

```javascript
const { ethers } = require('ethers');

// Implementation Slot
const implSlot = ethers.BigNumber.from(
    ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('eip1967.proxy.implementation')
    )
).sub(1);

console.log(implSlot.toHexString());
// 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

// Admin Slot
const adminSlot = ethers.BigNumber.from(
    ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('eip1967.proxy.admin')
    )
).sub(1);

console.log(adminSlot.toHexString());
// 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
```

## 🎓 3가지 프록시 패턴

### 1. Transparent Proxy

```
장점:
✅ Admin/User 분리
✅ 가장 안전

단점:
❌ Gas 높음
```

### 2. UUPS

```
장점:
✅ Gas 효율적
✅ Proxy 단순

단점:
❌ 구현 실수 시 업그레이드 불가
```

### 3. Beacon Proxy

```
장점:
✅ 여러 프록시 동시 업그레이드
✅ Gas 효율적

단점:
❌ Beacon 컨트랙트 필요
```

## 💡 일반적인 실수

### 실수 1: constructor 사용

```solidity
// ❌ 틀림
contract BadLogic {
    address public owner;

    constructor() {
        owner = msg.sender;  // Proxy에서 무시됨!
    }
}

// ✅ 맞음
contract GoodLogic {
    bool private initialized;
    address public owner;

    function initialize() external {
        require(!initialized);
        initialized = true;
        owner = msg.sender;
    }
}
```

### 실수 2: 스토리지 순서 변경

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

// ✅ V2: 순서 유지
contract V2 {
    uint256 public value;   // slot 0
    address public owner;   // slot 1
    uint256 public newVar;  // slot 2 - 끝에 추가
}
```

### 실수 3: 일반 슬롯 사용

```solidity
// ❌ 위험
contract BadProxy {
    address public implementation;  // slot 0 - 충돌 위험!
}

// ✅ 안전
contract SafeProxy {
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
}
```

## 🔍 디버깅

### 프록시 정보 조회

```javascript
// Implementation 주소
const implSlot = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
const impl = await provider.getStorageAt(proxyAddress, implSlot);
console.log('Implementation:', ethers.utils.getAddress('0x' + impl.slice(-40)));

// Admin 주소
const adminSlot = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
const admin = await provider.getStorageAt(proxyAddress, adminSlot);
console.log('Admin:', ethers.utils.getAddress('0x' + admin.slice(-40)));
```

### OpenZeppelin Helper

```javascript
const { upgrades } = require('hardhat');

const impl = await upgrades.erc1967.getImplementationAddress(proxyAddress);
const admin = await upgrades.erc1967.getAdminAddress(proxyAddress);

console.log('Implementation:', impl);
console.log('Admin:', admin);
```

## 📈 Gas 비용

```
일반 컨트랙트 호출: ~21,000 gas
프록시를 통한 호출: ~24,000 gas (+3,000)

추가 비용:
- delegatecall: ~700 gas
- sload (implementation): ~2,100 gas
- 기타: ~200 gas
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 가이드
- [EIP-1967 Spec](https://eips.ethereum.org/EIPS/eip-1967)
- [OpenZeppelin Proxy](https://docs.openzeppelin.com/contracts/4.x/api/proxy)
- [Hardhat Upgrades Plugin](https://docs.openzeppelin.com/upgrades-plugins/1.x/)

---

**핵심 요약:**

```
스토리지 충돌 방지:
→ keccak256("eip1967.proxy.xxx") - 1

업그레이드 규칙:
✅ 기존 변수 순서 유지
✅ 새 변수는 끝에 추가
✅ initialize 함수 사용
❌ constructor 사용 금지
❌ selfdestruct 금지
```

**마지막 업데이트: 2025**
