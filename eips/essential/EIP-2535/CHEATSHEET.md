# EIP-2535 Cheat Sheet

> **빠른 참조** - Diamond 표준 (다이아몬드 패턴)

## 🎯 핵심 (5초)

```
문제: 24KB 컨트랙트 크기 제한 💥
해결: 여러 Facet으로 기능 분산

→ Diamond (프록시) + Facets (로직)
→ 무제한 확장 가능!
```

## 📝 핵심 개념

```
Diamond (프록시)
    ├── Facet A (기능 1-10)
    ├── Facet B (기능 11-20)
    ├── Facet C (기능 21-30)
    └── ...

fallback() → selector 조회 → Facet으로 delegatecall
```

## 💻 기본 Diamond 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        mapping(address => bytes4[]) facetFunctionSelectors;
        address[] facetAddresses;
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.contractOwner = _newOwner;
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "Not owner");
    }
}

contract Diamond {
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibDiamond.setContractOwner(_contractOwner);

        // DiamondCut Facet 추가
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.selectorToFacetAndPosition[IDiamondCut.diamondCut.selector]
            .facetAddress = _diamondCutFacet;
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Function does not exist");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
```

## 🔧 기본 Facet 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// AppStorage 패턴
struct AppStorage {
    address owner;
    uint256 counter;
    mapping(address => uint256) balances;
}

contract FacetA {
    AppStorage internal s;

    function increment() external {
        s.counter += 1;
    }

    function getCounter() external view returns (uint256) {
        return s.counter;
    }
}

contract FacetB {
    AppStorage internal s;

    function deposit() external payable {
        s.balances[msg.sender] += msg.value;
    }

    function getBalance(address user) external view returns (uint256) {
        return s.balances[user];
    }
}
```

## 🔄 DiamondCut (업그레이드)

```solidity
interface IDiamondCut {
    enum FacetCutAction { Add, Replace, Remove }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}

contract DiamondCutFacet is IDiamondCut {
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamond.enforceIsContractOwner();

        for (uint256 i = 0; i < _diamondCut.length; i++) {
            FacetCut memory cut = _diamondCut[i];

            if (cut.action == FacetCutAction.Add) {
                addFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == FacetCutAction.Replace) {
                replaceFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == FacetCutAction.Remove) {
                removeFunctions(cut.facetAddress, cut.functionSelectors);
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);

        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _selectors) internal {
        require(_selectors.length > 0, "No selectors");
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(_facetAddress != address(0), "Zero address");

        for (uint256 i = 0; i < _selectors.length; i++) {
            bytes4 selector = _selectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacet == address(0), "Function exists");

            ds.selectorToFacetAndPosition[selector] = LibDiamond.FacetAddressAndPosition({
                facetAddress: _facetAddress,
                functionSelectorPosition: uint96(ds.facetFunctionSelectors[_facetAddress].length)
            });

            ds.facetFunctionSelectors[_facetAddress].push(selector);
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _selectors) internal {
        // 구현...
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _selectors) internal {
        // 구현...
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) return;

        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        require(success, string(error));
    }
}
```

## 🔍 DiamondLoupe (조회)

```solidity
interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    function facets() external view returns (Facet[] memory);
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory);
    function facetAddresses() external view returns (address[] memory);
    function facetAddress(bytes4 _selector) external view returns (address);
}

contract DiamondLoupeFacet is IDiamondLoupe {
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);

        for (uint256 i = 0; i < numFacets; i++) {
            address facetAddr = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddr;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddr];
        }
    }

    function facetAddress(bytes4 _selector) external view override returns (address) {
        return LibDiamond.diamondStorage().selectorToFacetAndPosition[_selector].facetAddress;
    }

    function facetAddresses() external view override returns (address[] memory) {
        return LibDiamond.diamondStorage().facetAddresses;
    }

    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory)
    {
        return LibDiamond.diamondStorage().facetFunctionSelectors[_facet];
    }
}
```

## 🚀 배포 & 사용 (Hardhat)

```javascript
const { ethers } = require('hardhat');

async function deployDiamond() {
    const [owner] = await ethers.getSigners();

    // 1. Facet 배포
    const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
    const diamondCutFacet = await DiamondCutFacet.deploy();

    const DiamondLoupeFacet = await ethers.getContractFactory('DiamondLoupeFacet');
    const diamondLoupeFacet = await DiamondLoupeFacet.deploy();

    const FacetA = await ethers.getContractFactory('FacetA');
    const facetA = await FacetA.deploy();

    // 2. Diamond 배포
    const Diamond = await ethers.getContractFactory('Diamond');
    const diamond = await Diamond.deploy(owner.address, diamondCutFacet.address);

    // 3. DiamondCut으로 Facet 추가
    const cut = [
        {
            facetAddress: diamondLoupeFacet.address,
            action: 0, // Add
            functionSelectors: getSelectors(diamondLoupeFacet)
        },
        {
            facetAddress: facetA.address,
            action: 0, // Add
            functionSelectors: getSelectors(facetA)
        }
    ];

    const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address);
    await diamondCut.diamondCut(cut, ethers.constants.AddressZero, '0x');

    console.log('Diamond deployed:', diamond.address);
    return diamond.address;
}

// Selector 추출
function getSelectors(contract) {
    const signatures = Object.keys(contract.interface.functions);
    return signatures.reduce((acc, val) => {
        if (val !== 'init(bytes)') {
            acc.push(contract.interface.getSighash(val));
        }
        return acc;
    }, []);
}

// 사용 예제
async function useDiamond(diamondAddress) {
    // Diamond를 FacetA 인터페이스로 사용
    const facetA = await ethers.getContractAt('FacetA', diamondAddress);

    await facetA.increment();
    const counter = await facetA.getCounter();
    console.log('Counter:', counter);

    // Diamond Loupe로 조회
    const loupe = await ethers.getContractAt('IDiamondLoupe', diamondAddress);
    const facets = await loupe.facets();
    console.log('Facets:', facets);
}
```

## 📊 AppStorage 패턴

```solidity
// shared/AppStorage.sol
struct AppStorage {
    // Facet 간 공유되는 상태
    address owner;
    uint256 counter;
    mapping(address => uint256) balances;
    mapping(address => bool) admins;

    // Facet별 상태를 구조체로 관리
    struct UserData {
        string name;
        uint256 level;
    }
    mapping(address => UserData) users;
}

// FacetA.sol
import { AppStorage } from "../shared/AppStorage.sol";

contract FacetA {
    AppStorage internal s;

    function increment() external {
        s.counter += 1;
    }
}

// FacetB.sol
import { AppStorage } from "../shared/AppStorage.sol";

contract FacetB {
    AppStorage internal s;

    function getCounter() external view returns (uint256) {
        return s.counter;  // FacetA와 동일한 storage
    }
}
```

## ⚠️ 보안 체크리스트

### ✅ 해야 할 것

```solidity
// 1. 소유자 권한 체크
function diamondCut(...) external {
    LibDiamond.enforceIsContractOwner();  // ✅
    // ...
}

// 2. Selector 중복 체크
function addFunctions(...) internal {
    require(oldFacet == address(0), "Function exists");  // ✅
}

// 3. AppStorage 순서 유지
struct AppStorage {
    address owner;      // slot 0 - 절대 변경 금지
    uint256 counter;    // slot 1 - 절대 변경 금지
    // 새 변수는 끝에 추가 ✅
    uint256 newVar;     // slot 2
}

// 4. Diamond Storage 사용
bytes32 constant DIAMOND_STORAGE_POSITION =
    keccak256("diamond.standard.diamond.storage");  // ✅

// 5. 초기화 함수 보호
function init() external {
    require(!s.initialized, "Already initialized");  // ✅
    s.initialized = true;
}
```

### ❌ 하면 안 되는 것

```solidity
// ❌ 1. 일반 storage 사용
contract BadDiamond {
    address public implementation;  // ❌ 충돌 위험!
}

// ❌ 2. AppStorage 순서 변경
struct AppStorage {
    uint256 counter;    // 원래 slot 1
    address owner;      // 원래 slot 0 - ❌
}

// ❌ 3. Selector 중복
function addFunctions(...) internal {
    // 중복 체크 없음 - ❌
    ds.selectorToFacetAndPosition[selector] = ...;
}

// ❌ 4. 권한 체크 누락
function diamondCut(...) external {
    // 권한 체크 없음 - ❌ 누구나 업그레이드 가능!
}

// ❌ 5. selfdestruct 사용
function destroy() external {
    selfdestruct(payable(msg.sender));  // ❌ 절대 금지!
}
```

## 🎓 실전 패턴

### 1. Facet 버전 관리

```solidity
contract FacetV1 {
    AppStorage internal s;

    function getValue() external view returns (uint256) {
        return s.counter;
    }
}

contract FacetV2 {
    AppStorage internal s;

    // 기존 함수 개선
    function getValue() external view returns (uint256) {
        return s.counter * 2;  // 로직 변경
    }

    // 새 함수 추가
    function getDoubleValue() external view returns (uint256) {
        return s.counter * 2;
    }
}

// DiamondCut으로 교체
const cut = [{
    facetAddress: facetV2.address,
    action: 1,  // Replace
    functionSelectors: [getSelector('getValue')]
}, {
    facetAddress: facetV2.address,
    action: 0,  // Add
    functionSelectors: [getSelector('getDoubleValue')]
}];

await diamondCut.diamondCut(cut, ethers.constants.AddressZero, '0x');
```

### 2. 초기화 패턴

```solidity
contract DiamondInit {
    AppStorage internal s;

    function init() external {
        require(!s.initialized, "Already initialized");
        s.initialized = true;
        s.owner = msg.sender;
        s.counter = 100;
    }
}

// 배포 시
const initContract = await DiamondInit.deploy();
const initData = initContract.interface.encodeFunctionData('init');

await diamondCut.diamondCut(
    cuts,
    initContract.address,
    initData  // 초기화 실행
);
```

### 3. Modular Facet 구성

```solidity
// Diamond
//   ├── OwnershipFacet   (권한 관리)
//   ├── ERC20Facet       (토큰 기능)
//   ├── StakingFacet     (스테이킹)
//   ├── GovernanceFacet  (거버넌스)
//   └── LoupeFacet       (조회)

// 각 Facet은 독립적으로 개발/테스트/업그레이드 가능
```

## 💡 일반적인 실수

### 실수 1: Storage 충돌

```solidity
// ❌ 틀림
contract FacetA {
    uint256 public counter;  // slot 0
}

contract FacetB {
    address public owner;    // slot 0 - 충돌!
}

// ✅ 맞음
struct AppStorage {
    uint256 counter;  // slot 0
    address owner;    // slot 1
}

contract FacetA {
    AppStorage internal s;
}

contract FacetB {
    AppStorage internal s;
}
```

### 실수 2: Selector 충돌

```solidity
// ❌ 틀림
contract FacetA {
    function transfer(address to) external {}
}

contract FacetB {
    function transfer(address to) external {}  // 같은 selector!
}

// ✅ 맞음: 함수명 변경
contract FacetA {
    function transferTokens(address to) external {}
}

contract FacetB {
    function transferOwnership(address to) external {}
}
```

### 실수 3: Diamond Storage 미사용

```solidity
// ❌ 틀림
contract Diamond {
    mapping(bytes4 => address) public selectors;  // 충돌 위험!
}

// ✅ 맞음
library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct DiamondStorage {
        mapping(bytes4 => address) selectors;
    }
}
```

## 📈 Gas 비용

```
Diamond 배포:        ~3,000,000 gas
Facet 배포 (1개):    ~500,000 gas
DiamondCut (Add):    ~200,000 gas
DiamondCut (Replace): ~150,000 gas
DiamondCut (Remove):  ~100,000 gas

함수 호출:
- 일반 컨트랙트:     ~21,000 gas
- Diamond 경유:      ~24,000 gas (+3,000)

✅ 초기 배포 비용은 높지만
✅ 업그레이드/확장 비용은 매우 낮음
✅ 24KB 제한 없음
```

## 🔍 디버깅

### Facet 조회

```javascript
// 모든 Facet 조회
const loupe = await ethers.getContractAt('IDiamondLoupe', diamond.address);
const facets = await loupe.facets();

console.log('Facets:');
facets.forEach(facet => {
    console.log(`  ${facet.facetAddress}:`);
    facet.functionSelectors.forEach(selector => {
        console.log(`    ${selector}`);
    });
});

// 특정 함수의 Facet 조회
const selector = '0x12345678';
const facetAddr = await loupe.facetAddress(selector);
console.log(`Function ${selector} → ${facetAddr}`);
```

### Hardhat 검증

```javascript
const hre = require('hardhat');

// Diamond 검증
await hre.run('verify:verify', {
    address: diamond.address,
    constructorArguments: [owner.address, diamondCutFacet.address]
});

// Facet 검증
await hre.run('verify:verify', {
    address: facetA.address,
    constructorArguments: []
});
```

## 🎯 사용 사례

```
✅ Aavegotchi        - NFT 게임 (원조 사용 사례)
✅ Quickswap         - DEX
✅ Large dApps       - 복잡한 프로토콜
✅ Protocol Upgrades - 점진적 업그레이드
✅ Feature Flags     - 기능 on/off
✅ Multi-Token       - ERC20 + ERC721 + ERC1155
✅ DAO Governance    - 거버넌스 + 재무 + 투표
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 가이드
- [EIP-2535 Spec](https://eips.ethereum.org/EIPS/eip-2535)
- [Louper.dev](https://louper.dev) - Diamond 탐색기
- [Aavegotchi](https://github.com/aavegotchi/aavegotchi-contracts) - 실전 예제
- [Nick Mudge](https://github.com/mudgen/diamond) - 원저자 구현

---

**핵심 요약:**

```
Diamond = 무제한 확장 가능한 스마트 컨트랙트

구조:
→ Diamond (프록시) + Facets (로직들)
→ fallback → selector 조회 → delegatecall

핵심 패턴:
✅ Diamond Storage: keccak256("diamond.standard.diamond.storage")
✅ AppStorage: Facet 간 상태 공유
✅ DiamondCut: Add/Replace/Remove Facets
✅ DiamondLoupe: 조회 인터페이스

주의사항:
❌ Storage 충돌 방지
❌ Selector 충돌 방지
❌ AppStorage 순서 유지
✅ 권한 관리 필수
```

**마지막 업데이트: 2025**
