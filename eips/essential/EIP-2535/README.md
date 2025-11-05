# EIP-2535: Diamond Standard (Multi-Facet Proxy)

> **모듈형 업그레이드 가능한 스마트 컨트랙트 표준**

## 📋 목차

- [개요](#개요)
- [문제점](#문제점)
- [해결책](#해결책)
- [핵심 개념](#핵심-개념)
- [구현 방법](#구현-방법)
- [AppStorage 패턴](#appstorage-패턴)
- [DiamondCut 작업](#diamondcut-작업)
- [실전 예제](#실전-예제)
- [보안 고려사항](#보안-고려사항)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

**EIP-2535 Diamond Standard**는 **24KB 컨트랙트 크기 제한**을 우회하고 **모듈식 업그레이드**를 가능하게 하는 프록시 패턴입니다.

### 🎯 핵심 목적

```
문제: Ethereum 24KB 컨트랙트 크기 제한

해결: 여러 Facet(모듈)로 분리
     → 각 Facet은 24KB 미만
     → Diamond가 함수별로 적절한 Facet으로 라우팅
```

### ⚡ 5초 요약

```
Diamond (프록시)
  ├─ Facet A (ERC20 기본 기능)
  ├─ Facet B (ERC20 고급 기능)
  ├─ Facet C (거버넌스)
  ├─ Facet D (스테이킹)
  └─ Facet E (...)

→ 함수 selector → Facet 매핑
→ delegatecall로 실행
→ 무제한 확장 가능!
```

---

## 문제점

### 1. 24KB 컨트랙트 크기 제한

**Ethereum의 근본적인 제약:**

```solidity
// ❌ 문제: 하나의 거대한 컨트랙트
contract HugeContract {
    // ERC20 기능
    function transfer(...) {}
    function approve(...) {}
    // ERC721 기능
    function safeTransferFrom(...) {}
    // 거버넌스 기능
    function propose(...) {}
    function vote(...) {}
    // 스테이킹 기능
    function stake(...) {}
    function unstake(...) {}
    // ... 수십 개의 함수들

    // 컴파일 에러: Contract code size exceeds 24576 bytes
}
```

### 2. 기존 해결책의 한계

#### 방법 1: 여러 컨트랙트로 분리

```solidity
contract ERC20Module {}
contract GovernanceModule {}
contract StakingModule {}

// ❌ 문제:
// - 상태(state) 분산
// - 복잡한 상호작용
// - 여러 주소 관리
```

#### 방법 2: 일반 Proxy 패턴

```solidity
contract Proxy {
    address implementation;
    // ❌ 문제:
    // - 하나의 implementation만 가능
    // - 여전히 24KB 제한
}
```

### 3. Diamond가 필요한 이유

```
요구사항:
1. 대규모 기능 (> 24KB)
2. 모듈식 업그레이드 (일부만 교체)
3. 단일 주소 (사용자 친화적)
4. 공유 상태 (모든 모듈이 같은 데이터 접근)

→ Diamond Pattern!
```

---

## 해결책

### Diamond 아키텍처

```
┌─────────────────────────────────────────┐
│           Diamond (0x123...)            │
│         (단일 프록시 주소)               │
└─────────────┬───────────────────────────┘
              │
              │ Function Selector Mapping
              │
    ┌─────────┼─────────┬─────────┬─────────┐
    │         │         │         │         │
    ▼         ▼         ▼         ▼         ▼
┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
│Facet A ││Facet B ││Facet C ││Facet D ││Facet E │
│ERC20   ││ERC20   ││Govern  ││Staking ││Admin   │
│Basic   ││Advanced││ance    ││        ││        │
└────────┘└────────┘└────────┘└────────┘└────────┘

모든 Facet이 같은 Diamond Storage에 접근
```

### 작동 방식

```
1. 사용자: diamond.transfer(to, 100)

2. Diamond fallback():
   - msg.sig = 0xa9059cbb (transfer의 selector)
   - DiamondStorage에서 조회:
     selectorToFacet[0xa9059cbb] = ERC20Facet 주소

3. delegatecall(ERC20Facet, msg.data)

4. ERC20Facet.transfer() 실행
   - Diamond의 storage 사용
   - msg.sender는 원래 사용자

5. 결과를 사용자에게 반환
```

---

## 핵심 개념

### 1. Diamond Storage

**모든 Facet이 공유하는 중앙 저장소:**

```solidity
library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;           // Facet 주소
        uint96 functionSelectorPosition; // selector 위치
    }

    struct DiamondStorage {
        // 함수 selector → Facet 주소 매핑
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;

        // Facet 주소 → 함수 selector 배열
        mapping(address => bytes4[]) facetFunctionSelectors;

        // 모든 Facet 주소 목록
        address[] facetAddresses;

        // 소유자
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
```

### 2. Facet (모듈)

**독립적인 기능 단위:**

```solidity
// Facet A: ERC20 기본 기능
contract ERC20Facet {
    AppStorage internal s;

    function transfer(address to, uint256 amount) external returns (bool) {
        s.balances[msg.sender] -= amount;
        s.balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return s.balances[account];
    }
}

// Facet B: ERC20 고급 기능
contract ERC20AdvancedFacet {
    AppStorage internal s;

    function mint(address to, uint256 amount) external {
        require(msg.sender == s.owner, "Not owner");
        s.balances[to] += amount;
        s.totalSupply += amount;
    }

    function burn(uint256 amount) external {
        s.balances[msg.sender] -= amount;
        s.totalSupply -= amount;
    }
}
```

### 3. Function Selector

**함수 시그니처의 4바이트 해시:**

```solidity
// transfer(address,uint256)
bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));
// = 0xa9059cbb

// Diamond에서 사용:
mapping(bytes4 => address) selectorToFacet;
selectorToFacet[0xa9059cbb] = address(erc20Facet);
```

### 4. DiamondCut

**Facet 추가/교체/제거:**

```solidity
enum FacetCutAction {
    Add,        // 새 함수 추가
    Replace,    // 기존 함수 교체
    Remove      // 함수 제거
}

struct FacetCut {
    address facetAddress;           // Facet 주소
    FacetCutAction action;          // 작업 유형
    bytes4[] functionSelectors;     // 대상 함수들
}

function diamondCut(
    FacetCut[] calldata _diamondCut,
    address _init,
    bytes calldata _calldata
) external;
```

### 5. Diamond Loupe

**Diamond 상태 조회 (EIP-2535 필수):**

```solidity
interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    // 모든 Facet 정보 조회
    function facets() external view returns (Facet[] memory);

    // 특정 Facet의 함수들 조회
    function facetFunctionSelectors(address _facet)
        external view returns (bytes4[] memory);

    // 모든 Facet 주소 조회
    function facetAddresses() external view returns (address[] memory);

    // 특정 함수의 Facet 주소 조회
    function facetAddress(bytes4 _functionSelector)
        external view returns (address);
}
```

---

## 구현 방법

### 패턴 1: Diamond 메인 컨트랙트

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "./LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

contract Diamond {
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibDiamond.setContractOwner(_contractOwner);

        // DiamondCut Facet 등록
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;
        LibDiamond.addFunctions(_diamondCutFacet, selectors);
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly { ds.slot := position }

        // 함수 selector로 Facet 조회
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Function does not exist");

        // Facet으로 delegatecall
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

### 패턴 2: LibDiamond (핵심 라이브러리)

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
        assembly { ds.slot := position }
    }

    // 소유자 설정
    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.contractOwner = _newOwner;
    }

    // 함수 추가
    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "No selectors");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "Invalid facet");

        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].length);

        // 새 Facet인 경우 목록에 추가
        if (selectorPosition == 0) {
            ds.facetAddresses.push(_facetAddress);
        }

        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;

            require(oldFacet == address(0), "Function already exists");

            // selector → Facet 매핑
            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition(
                _facetAddress,
                selectorPosition
            );

            // Facet → selectors 매핑
            ds.facetFunctionSelectors[_facetAddress].push(selector);
            selectorPosition++;
        }
    }

    // 함수 교체
    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "No selectors");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "Invalid facet");

        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].length);

        if (selectorPosition == 0) {
            ds.facetAddresses.push(_facetAddress);
        }

        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;

            require(oldFacet != _facetAddress, "Same function");
            require(oldFacet != address(0), "Function doesn't exist");

            // 이전 매핑 제거 및 새 매핑 추가
            removeFunction(oldFacet, selector);
            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition(
                _facetAddress,
                selectorPosition
            );
            ds.facetFunctionSelectors[_facetAddress].push(selector);
            selectorPosition++;
        }
    }

    // 함수 제거
    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "No selectors");
        DiamondStorage storage ds = diamondStorage();

        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;

            require(oldFacet != address(0), "Function doesn't exist");
            removeFunction(oldFacet, selector);
        }
    }

    function removeFunction(address _facetAddress, bytes4 _selector) internal {
        DiamondStorage storage ds = diamondStorage();
        FacetAddressAndPosition memory oldFacetAddressAndPosition =
            ds.selectorToFacetAndPosition[_selector];

        require(oldFacetAddressAndPosition.facetAddress == _facetAddress, "Wrong facet");

        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].length - 1;
        uint256 selectorPosition = oldFacetAddressAndPosition.functionSelectorPosition;

        // 마지막이 아니면 마지막과 교체
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress][lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress][selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition =
                uint96(selectorPosition);
        }

        ds.facetFunctionSelectors[_facetAddress].pop();
        delete ds.selectorToFacetAndPosition[_selector];
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "Not owner");
    }
}
```

### 패턴 3: DiamondCutFacet

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {LibDiamond} from "./LibDiamond.sol";

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
                LibDiamond.addFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == FacetCutAction.Replace) {
                LibDiamond.replaceFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == FacetCutAction.Remove) {
                LibDiamond.removeFunctions(cut.facetAddress, cut.functionSelectors);
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);

        // 초기화 함수 실행
        if (_init != address(0)) {
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    revert(string(error));
                } else {
                    revert("Init function reverted");
                }
            }
        }
    }
}
```

### 패턴 4: DiamondLoupeFacet

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "./LibDiamond.sol";
import {IDiamondLoupe} from "./interfaces/IDiamondLoupe.sol";

contract DiamondLoupeFacet is IDiamondLoupe {
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);

        for (uint256 i = 0; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddress_];
        }
    }

    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.facetFunctionSelectors[_facet];
    }

    function facetAddresses() external view override returns (address[] memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.facetAddresses;
    }

    function facetAddress(bytes4 _functionSelector)
        external
        view
        override
        returns (address)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }
}
```

---

## AppStorage 패턴

### AppStorage란?

**모든 Facet이 공유하는 애플리케이션 상태:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct AppStorage {
    // ERC20 상태
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    uint256 totalSupply;
    string name;
    string symbol;
    uint8 decimals;

    // 소유권
    address owner;

    // 거버넌스
    mapping(uint256 => Proposal) proposals;
    uint256 proposalCount;

    // 스테이킹
    mapping(address => StakeInfo) stakes;
    uint256 totalStaked;
}

struct Proposal {
    address proposer;
    string description;
    uint256 forVotes;
    uint256 againstVotes;
    uint256 deadline;
    bool executed;
}

struct StakeInfo {
    uint256 amount;
    uint256 timestamp;
    uint256 rewards;
}
```

### Facet에서 사용

```solidity
contract ERC20Facet {
    AppStorage internal s;  // slot 0에 위치

    function transfer(address to, uint256 amount) external returns (bool) {
        // AppStorage 접근
        s.balances[msg.sender] -= amount;
        s.balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return s.balances[account];
    }
}

contract GovernanceFacet {
    AppStorage internal s;  // 같은 slot 0

    function propose(string memory description) external returns (uint256) {
        uint256 proposalId = s.proposalCount++;
        s.proposals[proposalId] = Proposal({
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            deadline: block.timestamp + 7 days,
            executed: false
        });
        return proposalId;
    }
}
```

### 중요 규칙

```solidity
// ✅ 안전: 끝에 추가
struct AppStorage {
    uint256 value;      // slot 0
    address owner;      // slot 1
    uint256 newValue;   // slot 2 - 새로 추가
}

// ❌ 위험: 순서 변경
struct AppStorage {
    address owner;      // slot 0 (원래 slot 1)
    uint256 value;      // slot 1 (원래 slot 0)
    // 데이터 손상!
}

// ❌ 위험: 중간 삽입
struct AppStorage {
    uint256 value;      // slot 0
    uint256 newValue;   // slot 1 - 삽입!
    address owner;      // slot 2 (원래 slot 1)
    // 데이터 손상!
}
```

---

## DiamondCut 작업

### Add (추가)

```solidity
// 새 Facet 배포
NewFeatureFacet newFacet = new NewFeatureFacet();

// FacetCut 생성
IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = IDiamondCut.FacetCut({
    facetAddress: address(newFacet),
    action: IDiamondCut.FacetCutAction.Add,
    functionSelectors: [
        NewFeatureFacet.newFunction1.selector,
        NewFeatureFacet.newFunction2.selector
    ]
});

// DiamondCut 실행
IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

### Replace (교체)

```solidity
// 업그레이드된 Facet 배포
ERC20FacetV2 upgradedFacet = new ERC20FacetV2();

// 교체할 함수 지정
bytes4[] memory selectors = new bytes4[](2);
selectors[0] = ERC20FacetV2.transfer.selector;
selectors[1] = ERC20FacetV2.transferFrom.selector;

IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = IDiamondCut.FacetCut({
    facetAddress: address(upgradedFacet),
    action: IDiamondCut.FacetCutAction.Replace,
    functionSelectors: selectors
});

IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

### Remove (제거)

```solidity
// 제거할 함수 지정
bytes4[] memory selectors = new bytes4[](1);
selectors[0] = bytes4(keccak256("deprecatedFunction()"));

IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = IDiamondCut.FacetCut({
    facetAddress: address(0),  // Remove는 주소 불필요
    action: IDiamondCut.FacetCutAction.Remove,
    functionSelectors: selectors
});

IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

### 초기화와 함께 실행

```solidity
// 초기화 컨트랙트
contract DiamondInit {
    AppStorage internal s;

    function init(string memory name, string memory symbol) external {
        s.name = name;
        s.symbol = symbol;
        s.decimals = 18;
    }
}

DiamondInit diamondInit = new DiamondInit();

// DiamondCut + 초기화
IDiamondCut(diamond).diamondCut(
    cuts,
    address(diamondInit),
    abi.encodeWithSelector(DiamondInit.init.selector, "MyToken", "MTK")
);
```

---

## 실전 예제

### 예제 1: 전체 배포

```javascript
// scripts/deploy.js
const { ethers } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();

    // 1. Facet 배포
    const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
    const diamondCut = await DiamondCutFacet.deploy();

    const DiamondLoupeFacet = await ethers.getContractFactory('DiamondLoupeFacet');
    const diamondLoupe = await DiamondLoupeFacet.deploy();

    const ERC20Facet = await ethers.getContractFactory('ERC20Facet');
    const erc20 = await ERC20Facet.deploy();

    // 2. Diamond 배포
    const Diamond = await ethers.getContractFactory('Diamond');
    const diamond = await Diamond.deploy(
        deployer.address,
        diamondCut.address
    );

    // 3. FacetCut 준비
    const cuts = [
        {
            facetAddress: diamondLoupe.address,
            action: 0, // Add
            functionSelectors: getSelectors(DiamondLoupeFacet)
        },
        {
            facetAddress: erc20.address,
            action: 0, // Add
            functionSelectors: getSelectors(ERC20Facet)
        }
    ];

    // 4. 초기화
    const DiamondInit = await ethers.getContractFactory('DiamondInit');
    const diamondInit = await DiamondInit.deploy();

    const initData = diamondInit.interface.encodeFunctionData('init', [
        'Diamond Token',
        'DMT'
    ]);

    // 5. DiamondCut 실행
    const diamondCutContract = await ethers.getContractAt('IDiamondCut', diamond.address);
    await diamondCutContract.diamondCut(cuts, diamondInit.address, initData);

    console.log('Diamond deployed to:', diamond.address);

    return diamond.address;
}

function getSelectors(contract) {
    const signatures = Object.keys(contract.interface.functions);
    return signatures.reduce((acc, val) => {
        if (val !== 'init(bytes)') {
            acc.push(contract.interface.getSighash(val));
        }
        return acc;
    }, []);
}
```

### 예제 2: 사용자 관점

```javascript
const diamond = await ethers.getContractAt('IERC20', diamondAddress);

// ERC20 기능 사용 (ERC20Facet)
await diamond.transfer(recipient, ethers.parseEther('100'));
const balance = await diamond.balanceOf(user);

// 거버넌스 기능 사용 (GovernanceFacet)
const governance = await ethers.getContractAt('GovernanceFacet', diamondAddress);
await governance.propose('Proposal description');
await governance.vote(proposalId, true);

// Loupe로 정보 조회
const loupe = await ethers.getContractAt('IDiamondLoupe', diamondAddress);
const facets = await loupe.facets();
console.log('All facets:', facets);
```

### 예제 3: 런타임 업그레이드

```javascript
async function upgradeFacet(diamondAddress) {
    // 1. 새 Facet 배포
    const ERC20FacetV2 = await ethers.getContractFactory('ERC20FacetV2');
    const erc20V2 = await ERC20FacetV2.deploy();

    // 2. 교체할 함수 선택
    const selectors = [
        erc20V2.interface.getSighash('transfer'),
        erc20V2.interface.getSighash('transferFrom')
    ];

    // 3. DiamondCut
    const diamondCut = await ethers.getContractAt('IDiamondCut', diamondAddress);
    await diamondCut.diamondCut(
        [{
            facetAddress: erc20V2.address,
            action: 1, // Replace
            functionSelectors: selectors
        }],
        ethers.ZeroAddress,
        '0x'
    );

    console.log('Upgraded ERC20 functions');
}
```

---

## 보안 고려사항

### 1. Selector 충돌

```solidity
// ❌ 위험: 같은 selector
contract FacetA {
    function getData() external view returns (uint256) {}
}

contract FacetB {
    function getData() external view returns (string memory) {}
    // 같은 이름, 다른 반환 타입
    // → 같은 selector!
}

// ✅ 해결: 다른 이름 사용
contract FacetB {
    function getDataString() external view returns (string memory) {}
}
```

### 2. Storage 충돌

```solidity
// ❌ 위험: 각 Facet에서 직접 storage 선언
contract FacetA {
    uint256 public value;   // slot 0
    address public owner;   // slot 1
}

contract FacetB {
    address public admin;   // slot 0 - 충돌!
    uint256 public count;   // slot 1 - 충돌!
}

// ✅ 해결: AppStorage 패턴
struct AppStorage {
    uint256 value;
    address owner;
    address admin;
    uint256 count;
}

contract FacetA {
    AppStorage internal s;
}

contract FacetB {
    AppStorage internal s;
}
```

### 3. 권한 관리

```solidity
// ✅ DiamondCut은 소유자만
function diamondCut(...) external {
    LibDiamond.enforceIsContractOwner();
    // ...
}

// ✅ Facet 함수도 권한 체크
contract AdminFacet {
    AppStorage internal s;

    function criticalFunction() external {
        require(msg.sender == s.owner, "Not owner");
        // ...
    }
}
```

### 4. Delegatecall 위험

```solidity
// ❌ 절대 금지: selfdestruct
contract MaliciousFacet {
    function destroy() external {
        selfdestruct(payable(msg.sender));
        // Diamond 파괴!
    }
}

// ✅ DiamondCut에서 검증
// 신뢰할 수 있는 Facet만 추가
```

### 5. 초기화 중복

```solidity
// ❌ 위험: 중복 초기화
contract DiamondInit {
    function init() external {
        // 보호 장치 없음
    }
}

// ✅ 안전: 한 번만 초기화
contract DiamondInit {
    AppStorage internal s;

    function init() external {
        require(!s.initialized, "Already initialized");
        s.initialized = true;
        // ...
    }
}
```

---

## FAQ

### Q1. Diamond vs 일반 Proxy의 차이?

**A:**
```
일반 Proxy:
- 하나의 implementation
- 전체 교체만 가능
- 24KB 제한 존재

Diamond:
- 여러 Facet
- 함수별 교체 가능
- 무제한 크기
```

### Q2. AppStorage는 왜 필요한가?

**A:**
```
문제: 각 Facet이 독립적으로 storage 선언하면 충돌

해결: 모든 Facet이 같은 AppStorage 사용
     → slot 0에 위치
     → 모든 Facet이 같은 데이터 접근
```

### Q3. Gas 비용은?

**A:**
```
추가 비용 (vs 일반 컨트랙트):
- Selector 조회: ~2,600 gas
- delegatecall: ~700 gas
- 총: ~3,300 gas 추가

장점:
- 무제한 기능
- 모듈식 업그레이드
- 코드 재사용
```

### Q4. 업그레이드 시 데이터는?

**A:**
```
✅ 유지됨!

AppStorage는 Diamond에 저장
Facet 교체 = 코드만 교체
데이터는 그대로

V1: s.balances[user] = 100
↓ 업그레이드
V2: s.balances[user] = 100 (유지)
```

### Q5. 왜 24KB 제한이 있나?

**A:**
```
Ethereum Spurious Dragon (EIP-170):
- DOS 공격 방지
- 블록 가스 제한 보호
- 2016년부터 적용

24,576 bytes = 24KB
```

### Q6. Diamond는 언제 사용하나?

**A:**
```
✅ 사용:
- 대규모 DApp (> 24KB)
- 복잡한 기능 모음
- 점진적 업그레이드 필요
- 모듈식 개발

❌ 불필요:
- 단순한 토큰 (< 20KB)
- 업그레이드 불필요
- 단일 기능
```

### Q7. Facet 개수 제한은?

**A:**
```
이론적: 무제한

실무적 제한:
- 각 Facet 추가 시 gas 소비
- DiamondLoupe 조회 시 gas
- 권장: 10-20개 Facet
```

### Q8. 기존 프록시와 호환되나?

**A:**
```
부분 호환:
✅ EIP-1967 슬롯 사용 가능
✅ 기존 도구 일부 호환
❌ Diamond 전용 도구 필요 (Louper 등)
```

---

## 참고 자료

### 공식 문서
- [EIP-2535 Specification](https://eips.ethereum.org/EIPS/eip-2535)
- [Diamond Standard GitHub](https://github.com/mudgen/diamond)
- [Nick Mudge's Blog](https://eip2535diamonds.substack.com/)

### 구현 예제
- [Diamond-1 (Hardhat)](https://github.com/mudgen/diamond-1-hardhat)
- [Diamond-2 (Hardhat)](https://github.com/mudgen/diamond-2-hardhat)
- [Diamond-3 (Hardhat)](https://github.com/mudgen/diamond-3-hardhat)

### 실제 사용
- [Aavegotchi](https://github.com/aavegotchi/aavegotchi-contracts)
- [Louper.dev](https://louper.dev/) - Diamond Inspector
- [Realm.art](https://github.com/aavegotchi/gotchiverse-contracts)

### 도구
- [Louper Diamond Inspector](https://louper.dev/)
- [hardhat-diamond-abi](https://www.npmjs.com/package/hardhat-diamond-abi)
- [Diamond Deploy Scripts](https://github.com/mudgen/diamond-deploy)

---

## 라이센스

MIT License

---

**마지막 업데이트:** 2025
**버전:** 1.0.0

**핵심 포인트:**
- 💎 24KB 제한 우회 (무제한 기능)
- 🔧 모듈식 업그레이드 (함수별 교체)
- 📦 AppStorage 패턴 (공유 상태)
- 🎯 Function Selector 라우팅
- 🔄 DiamondCut (Add/Replace/Remove)
