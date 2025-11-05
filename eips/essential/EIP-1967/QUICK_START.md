# EIP-1967 빠른 시작 가이드 (Quick Start Guide)

## 5분 안에 EIP-1967 이해하기 (Get Started in 5 Minutes)

### 1. 핵심 개념 (Basic Concept)

```
일반 컨트랙트                 업그레이드 가능 (Proxy)
   |                              |
   | 배포 후 수정 불가            | 로직 교체 가능
   v                              v
버그 발견 → 새로 배포          버그 발견 → 업그레이드
(주소 변경, 데이터 손실)       (주소 유지, 데이터 유지)
```

**핵심**: EIP-1967 = **안전한 업그레이드를 위한 표준 스토리지 슬롯**

---

## 2. 표준 슬롯 (Standard Slots)

```solidity
// EIP-1967 표준 슬롯

// 1️⃣ Implementation 슬롯
bytes32 constant IMPLEMENTATION_SLOT = 
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
// = keccak256("eip1967.proxy.implementation") - 1

// 2️⃣ Admin 슬롯
bytes32 constant ADMIN_SLOT = 
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
// = keccak256("eip1967.proxy.admin") - 1

// 3️⃣ Beacon 슬롯
bytes32 constant BEACON_SLOT = 
    0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
// = keccak256("eip1967.proxy.beacon") - 1
```

---

## 3. 최소 Proxy 구현

### 기본 Proxy

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EIP1967Proxy {
    // Implementation 슬롯
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Admin 슬롯
    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor(address _implementation, address _admin) {
        _setImplementation(_implementation);
        _setAdmin(_admin);
    }

    // Implementation 설정
    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "Not a contract");

        assembly {
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    // Admin 설정
    function _setAdmin(address newAdmin) private {
        assembly {
            sstore(ADMIN_SLOT, newAdmin)
        }
    }

    // Implementation 조회
    function _getImplementation() private view returns (address implementation) {
        assembly {
            implementation := sload(IMPLEMENTATION_SLOT)
        }
    }

    // Admin 조회
    function _getAdmin() private view returns (address admin) {
        assembly {
            admin := sload(ADMIN_SLOT)
        }
    }

    // 업그레이드 (Admin만)
    function upgradeTo(address newImplementation) external {
        require(msg.sender == _getAdmin(), "Not admin");
        _setImplementation(newImplementation);
    }

    // Fallback: delegatecall
    fallback() external payable {
        address implementation = _getImplementation();

        assembly {
            // calldata 복사
            calldatacopy(0, 0, calldatasize())

            // delegatecall 실행
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            // 반환 데이터 복사
            returndatacopy(0, 0, returndatasize())

            // 결과에 따라 revert 또는 return
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
```

---

## 4. Implementation 컨트랙트

### V1 (초기 버전)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CounterV1 {
    // ⚠️ 스토리지 레이아웃 주의!
    uint256 public count;

    function increment() external {
        count++;
    }

    function getCount() external view returns (uint256) {
        return count;
    }
}
```

### V2 (업그레이드)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CounterV2 {
    // ⚠️ V1과 동일한 레이아웃 유지!
    uint256 public count;

    function increment() external {
        count++;
    }

    function decrement() external {
        count--;
    }

    function getCount() external view returns (uint256) {
        return count;
    }

    // 새 함수 추가 가능
    function reset() external {
        count = 0;
    }
}
```

---

## 5. 사용 방법

### 배포

```javascript
import { ethers } from 'hardhat';

async function deploy() {
    const [admin] = await ethers.getSigners();

    // 1. V1 배포
    const CounterV1 = await ethers.getContractFactory("CounterV1");
    const counterV1 = await CounterV1.deploy();
    console.log("CounterV1:", await counterV1.getAddress());

    // 2. Proxy 배포
    const Proxy = await ethers.getContractFactory("EIP1967Proxy");
    const proxy = await Proxy.deploy(
        await counterV1.getAddress(),
        admin.address
    );
    console.log("Proxy:", await proxy.getAddress());

    // 3. Proxy를 통해 사용
    const counter = CounterV1.attach(await proxy.getAddress());
    
    await counter.increment();
    console.log("Count:", await counter.getCount()); // 1

    return { proxy, counterV1, admin };
}
```

### 업그레이드

```javascript
async function upgrade(proxyAddress, adminSigner) {
    // 1. V2 배포
    const CounterV2 = await ethers.getContractFactory("CounterV2");
    const counterV2 = await CounterV2.deploy();
    console.log("CounterV2:", await counterV2.getAddress());

    // 2. Proxy 업그레이드
    const proxy = await ethers.getContractAt("EIP1967Proxy", proxyAddress);
    await proxy.connect(adminSigner).upgradeTo(await counterV2.getAddress());

    // 3. V2 인터페이스로 사용
    const counter = CounterV2.attach(proxyAddress);
    
    // 기존 데이터 유지!
    console.log("Count:", await counter.getCount()); // 여전히 1

    // 새 함수 사용 가능
    await counter.decrement();
    console.log("Count:", await counter.getCount()); // 0
}
```

---

## 6. OpenZeppelin Proxy 사용

### 더 쉬운 방법

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyContractV1 is Initializable, OwnableUpgradeable {
    uint256 public value;

    // constructor 대신 initialize
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        value = 0;
    }

    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }
}
```

### Hardhat 배포 스크립트

```javascript
import { ethers, upgrades } from 'hardhat';

async function main() {
    const [owner] = await ethers.getSigners();

    // V1 배포
    const MyContract = await ethers.getContractFactory("MyContractV1");
    const proxy = await upgrades.deployProxy(
        MyContract,
        [owner.address],  // initialize 인자
        { kind: 'uups' }
    );

    await proxy.waitForDeployment();
    console.log("Proxy deployed to:", await proxy.getAddress());

    // 사용
    await proxy.setValue(42);
    console.log("Value:", await proxy.value());
}

// 업그레이드
async function upgradeToV2(proxyAddress) {
    const MyContractV2 = await ethers.getContractFactory("MyContractV2");
    
    const upgraded = await upgrades.upgradeProxy(
        proxyAddress,
        MyContractV2
    );

    console.log("Upgraded to V2");
    console.log("Proxy address (same):", await upgraded.getAddress());
}
```

---

## 7. 스토리지 충돌 방지

### ❌ 잘못된 업그레이드

```solidity
// V1
contract CounterV1 {
    uint256 public count;     // slot 0
}

// V2 - ❌ 잘못됨!
contract CounterV2 {
    address public owner;     // slot 0 (충돌!)
    uint256 public count;     // slot 1 (이동됨!)
}

// 결과: count 값이 owner로 해석됨 → 데이터 손상!
```

### ✅ 올바른 업그레이드

```solidity
// V1
contract CounterV1 {
    uint256 public count;     // slot 0
}

// V2 - ✅ 올바름
contract CounterV2 {
    uint256 public count;     // slot 0 (유지!)
    address public owner;     // slot 1 (추가)
}

// 규칙:
// 1. 기존 변수 순서 유지
// 2. 새 변수는 맨 뒤에 추가
// 3. 기존 변수 타입 변경 금지
// 4. 기존 변수 삭제 금지
```

---

## 8. 보안 체크리스트

```solidity
// ✅ 해야 할 것

// 1. Admin 권한 확인
modifier onlyAdmin() {
    require(msg.sender == _getAdmin(), "Not admin");
    _;
}

// 2. Implementation 검증
function _setImplementation(address newImplementation) private {
    require(newImplementation.code.length > 0, "Not a contract");
    require(newImplementation != address(0), "Zero address");
}

// 3. Initialize 보호
function initialize(...) external initializer {
    // 한 번만 호출 가능
}

// 4. Selector 충돌 방지
// Admin 함수와 Implementation 함수의 selector가 겹치면 안 됨

// ❌ 하지 말아야 할 것

// 1. Constructor 사용 (Proxy에서 실행 안 됨)
constructor() {  // ❌
    owner = msg.sender;
}

// 2. 스토리지 순서 변경
// 3. Self-destruct 사용
// 4. delegatecall 내부에서 msg.sender 변경
```

---

## 9. 테스트

```javascript
describe("EIP1967 Proxy", function () {
    let proxy, v1, v2, admin, user;

    beforeEach(async function () {
        [admin, user] = await ethers.getSigners();

        // V1 배포
        const CounterV1 = await ethers.getContractFactory("CounterV1");
        v1 = await CounterV1.deploy();

        // Proxy 배포
        const Proxy = await ethers.getContractFactory("EIP1967Proxy");
        proxy = await Proxy.deploy(await v1.getAddress(), admin.address);
    });

    it("V1 동작 확인", async function () {
        const counter = await ethers.getContractAt("CounterV1", await proxy.getAddress());
        
        await counter.increment();
        expect(await counter.getCount()).to.equal(1);
    });

    it("V2로 업그레이드", async function () {
        // V2 배포
        const CounterV2 = await ethers.getContractFactory("CounterV2");
        v2 = await CounterV2.deploy();

        // Proxy 업그레이드
        await proxy.connect(admin).upgradeTo(await v2.getAddress());

        // V2 인터페이스로 접근
        const counter = await ethers.getContractAt("CounterV2", await proxy.getAddress());

        // 데이터 유지 확인
        expect(await counter.getCount()).to.equal(1);

        // 새 함수 사용
        await counter.decrement();
        expect(await counter.getCount()).to.equal(0);
    });

    it("Admin만 업그레이드 가능", async function () {
        const CounterV2 = await ethers.getContractFactory("CounterV2");
        v2 = await CounterV2.deploy();

        // User가 업그레이드 시도 → 실패
        await expect(
            proxy.connect(user).upgradeTo(await v2.getAddress())
        ).to.be.revertedWith("Not admin");
    });
});
```

---

## 10. FAQ

**Q: EIP-1967 슬롯은 왜 저런 값인가요?**
- 충돌을 피하기 위해 `keccak256("eip1967.proxy.implementation") - 1`로 계산
- 일반 스토리지 슬롯과 겹칠 확률이 거의 0

**Q: UUPS vs Transparent Proxy 차이는?**
- **Transparent**: 업그레이드 로직이 Proxy에 있음
- **UUPS**: 업그레이드 로직이 Implementation에 있음
- UUPS가 가스비 절감, Transparent가 더 안전

**Q: 업그레이드 시 데이터가 유지되나요?**
- 네! Proxy의 스토리지는 그대로 유지됩니다.
- Implementation만 바뀝니다.

**Q: Constructor는 왜 안 되나요?**
- Constructor는 배포 시 한 번만 실행됨
- Proxy에서 delegatecall할 때는 실행 안 됨
- 대신 `initialize()` 함수 사용

---

## 11. 다음 단계

1. ✅ `contracts/EIP1967Proxy.sol` 확인
2. ✅ `contracts/LogicContracts.sol` 업그레이드 테스트
3. ✅ OpenZeppelin Upgrades Plugin 사용
4. ✅ UUPS vs Transparent 비교
5. ✅ Storage Layout 검증 도구 사용
6. ✅ Aave, Compound 등의 실제 구현 분석

---

**마지막 업데이트**: 2025-11-05  
**버전**: 1.0.0

**시작하기**: `contracts/EIP1967Proxy.sol`로 시작하세요! 🚀

