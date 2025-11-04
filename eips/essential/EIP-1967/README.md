# EIP-1967 - Proxy Storage Slots

## 목적
업그레이드 가능한 프록시 컨트랙트에서 스토리지 충돌을 방지하기 위한 표준 슬롯 정의

## 핵심 문제: 스토리지 충돌

```solidity
// 위험한 프록시 패턴
contract BadProxy {
    address public implementation;  // slot 0

    fallback() external payable {
        address impl = implementation;
        // delegate call...
    }
}

contract Logic {
    uint256 public value;  // slot 0 - 충돌!

    function setValue(uint256 _value) external {
        value = _value;  // implementation 주소를 덮어씀!
    }
}
```

**무슨 일이 일어나는가?**
1. Logic 컨트랙트가 `value`를 slot 0에 저장하려 함
2. 하지만 Proxy의 slot 0에는 `implementation` 주소가 있음
3. `setValue()` 호출 시 implementation 주소가 변경됨
4. 컨트랙트 완전 파괴

## 해결책: EIP-1967 표준 슬롯

```solidity
// EIP-1967: 예측 불가능한 위치에 저장
contract EIP1967Proxy {
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

## 완전한 구현 예제

### 기본 EIP-1967 Proxy
```solidity
contract EIP1967Proxy {
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor(address _logic, address _admin, bytes memory _data) {
        _setImplementation(_logic);
        _setAdmin(_admin);

        if (_data.length > 0) {
            (bool success,) = _logic.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) private {
        require(
            newImplementation.code.length > 0,
            "Implementation is not a contract"
        );

        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }

        emit Upgraded(newImplementation);
    }

    fallback() external payable {
        address impl = _getImplementation();

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    event Upgraded(address indexed implementation);
}
```

## Logic 컨트랙트 작성 패턴

### V1: 초기 버전
```solidity
contract LogicV1 {
    uint256 public value;
    address public owner;

    function initialize(address _owner) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
        value = 0;
    }

    function setValue(uint256 _value) external {
        require(msg.sender == owner, "Not owner");
        value = _value;
    }
}
```

### V2: 업그레이드 버전
```solidity
contract LogicV2 {
    // 주의: 기존 스토리지 레이아웃 유지 필수!
    uint256 public value;      // slot 0 - 변경 금지
    address public owner;      // slot 1 - 변경 금지
    uint256 public newValue;   // slot 2 - 새로운 변수는 끝에 추가

    function setNewValue(uint256 _newValue) external {
        require(msg.sender == owner, "Not owner");
        newValue = _newValue;
    }

    function setValue(uint256 _value) external {
        require(msg.sender == owner, "Not owner");
        value = _value;
        emit ValueUpdated(_value);
    }

    event ValueUpdated(uint256 newValue);
}
```

## 스토리지 레이아웃 규칙

### 절대 하면 안 되는 것들
```solidity
contract BadUpgrade {
    // 1. 기존 변수 순서 변경
    address public owner;  // 원래 slot 1이었는데
    uint256 public value;  // slot 0으로 이동 - 위험!

    // 2. 기존 변수 타입 변경
    address public value;  // uint256에서 address로 변경 - 위험!

    // 3. 기존 변수 삭제
    // uint256 public value; 주석 처리 - 위험!
}
```

### 안전한 업그레이드
```solidity
contract GoodUpgrade {
    // 기존 변수들은 그대로
    uint256 public value;   // slot 0
    address public owner;   // slot 1

    // 새 변수는 끝에 추가
    mapping(address => uint256) public balances;  // slot 2
    uint256 public totalSupply;  // slot 3

    // 함수는 자유롭게 수정 가능
    function newFunction() external { }
}
```

## OpenZeppelin 사용법

```solidity
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Logic 컨트랙트
contract MyContractV1 is Initializable {
    uint256 public value;

    function initialize(uint256 _value) public initializer {
        value = _value;
    }
}

// 배포 스크립트
contract DeployScript {
    function deploy() external {
        // 1. Logic 배포
        LogicV1 logic = new LogicV1();

        // 2. 초기화 데이터 준비
        bytes memory initData = abi.encodeWithSelector(
            LogicV1.initialize.selector,
            msg.sender
        );

        // 3. Proxy 배포
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(logic),
            initData
        );

        // 4. Proxy를 Logic으로 캐스팅해서 사용
        LogicV1 instance = LogicV1(address(proxy));
        instance.setValue(42);
    }
}
```

## 슬롯 계산 방법

```javascript
// JavaScript로 슬롯 계산
const { ethers } = require('ethers');

// Implementation 슬롯
const implSlot = ethers.BigNumber.from(
    ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('eip1967.proxy.implementation')
    )
).sub(1);

console.log(implSlot.toHexString());
// 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

## 샘플 컨트랙트
- [EIP1967Proxy.sol](./contracts/EIP1967Proxy.sol) - 기본 프록시 구현
- [LogicContracts.sol](./contracts/LogicContracts.sol) - V1, V2 로직 예제
- [ProxyAdmin.sol](./contracts/ProxyAdmin.sol) - 관리자 컨트랙트

## 참고 자료
- [EIP-1967 Specification](https://eips.ethereum.org/EIPS/eip-1967)
- [OpenZeppelin Proxy Documentation](https://docs.openzeppelin.com/contracts/4.x/api/proxy)
