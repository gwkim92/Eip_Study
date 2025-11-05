# EIP-2535 빠른 시작 가이드 (Quick Start Guide)

## 5분 안에 EIP-2535 이해하기 (Get Started in 5 Minutes)

### 1. 핵심 개념 (Basic Concept)

```
일반 컨트랙트              Diamond (EIP-2535)
   |                          |
   | 24KB 제한               | 무제한 크기
   | 단일 컨트랙트            | 여러 Facet으로 분산
   v                          v
크기 제한 도달 →          Facet 추가/제거/교체
새로 배포                  주소 유지
```

**핵심**: Diamond = **여러 컨트랙트를 하나처럼 사용하는 고급 프록시 패턴**

---

## 2. Diamond 구조

```
Diamond (Proxy)
├── fallback() → selector 조회
├── Facet 1 (기능 A, B, C)
├── Facet 2 (기능 D, E, F)
├── Facet 3 (기능 G, H, I)
└── DiamondStorage (공유 데이터)

호출: contract.functionA()
→ Diamond fallback()
→ selector 조회: functionA → Facet 1
→ delegatecall(Facet 1)
```

---

## 3. 최소 Diamond 구현

### LibDiamond (핵심 라이브러리)

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
        // selector → facet 매핑
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // facet → selectors 매핑
        mapping(address => bytes4[]) facetFunctionSelectors;
        // facet 주소 목록
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

    // Facet 추가
    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "No selectors");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "Zero address");

        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].length);

        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacet == address(0), "Selector exists");

            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition(
                _facetAddress,
                selectorPosition
            );
            ds.facetFunctionSelectors[_facetAddress].push(selector);
            selectorPosition++;
        }

        if (selectorPosition == _functionSelectors.length) {
            ds.facetAddresses.push(_facetAddress);
        }
    }
}
```

### Diamond 컨트랙트

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LibDiamond.sol";

contract Diamond {
    constructor(address _owner) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.contractOwner = _owner;
    }

    // Fallback: selector 라우팅
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        
        // selector → facet 조회
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Function does not exist");

        // delegatecall
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

---

## 4. Facet 예제

### TokenFacet (ERC20 기능)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TokenFacet {
    // AppStorage 사용 (공유 스토리지)
    bytes32 constant APP_STORAGE_POSITION = keccak256("diamond.app.storage");

    struct AppStorage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
    }

    function appStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function mint(address to, uint256 amount) external {
        AppStorage storage s = appStorage();
        s.balances[to] += amount;
        s.totalSupply += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return appStorage().balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        AppStorage storage s = appStorage();
        require(s.balances[msg.sender] >= amount, "Insufficient balance");
        
        s.balances[msg.sender] -= amount;
        s.balances[to] += amount;
        
        return true;
    }
}
```

### SwapFacet (DEX 기능)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SwapFacet {
    bytes32 constant APP_STORAGE_POSITION = keccak256("diamond.app.storage");

    struct AppStorage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        // 추가 데이터
        uint256 swapFee;
        mapping(address => uint256) liquidityPool;
    }

    function appStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function swap(uint256 amountIn) external returns (uint256 amountOut) {
        AppStorage storage s = appStorage();
        
        // 간단한 swap 로직
        amountOut = (amountIn * (10000 - s.swapFee)) / 10000;
        
        s.balances[msg.sender] -= amountIn;
        s.balances[msg.sender] += amountOut;
        
        return amountOut;
    }

    function setSwapFee(uint256 newFee) external {
        appStorage().swapFee = newFee;
    }
}
```

---

## 5. DiamondCut (Facet 관리)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LibDiamond.sol";

contract DiamondCutFacet {
    enum FacetCutAction { Add, Replace, Remove }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    function diamondCut(FacetCut[] calldata _diamondCut) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(msg.sender == ds.contractOwner, "Not owner");

        for (uint256 i = 0; i < _diamondCut.length; i++) {
            FacetCut memory cut = _diamondCut[i];

            if (cut.action == FacetCutAction.Add) {
                LibDiamond.addFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == FacetCutAction.Replace) {
                // Replace 로직
            } else if (cut.action == FacetCutAction.Remove) {
                // Remove 로직
            }
        }
    }
}
```

---

## 6. 사용 방법

### 배포

```javascript
import { ethers } from 'hardhat';

async function deployDiamond() {
    const [owner] = await ethers.getSigners();

    // 1. Diamond 배포
    const Diamond = await ethers.getContractFactory("Diamond");
    const diamond = await Diamond.deploy(owner.address);
    console.log("Diamond:", await diamond.getAddress());

    // 2. DiamondCutFacet 배포
    const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
    const diamondCut = await DiamondCutFacet.deploy();

    // 3. TokenFacet 배포
    const TokenFacet = await ethers.getContractFactory("TokenFacet");
    const tokenFacet = await TokenFacet.deploy();

    // 4. SwapFacet 배포
    const SwapFacet = await ethers.getContractFactory("SwapFacet");
    const swapFacet = await SwapFacet.deploy();

    // 5. Facet 추가
    const cuts = [
        {
            facetAddress: await diamondCut.getAddress(),
            action: 0, // Add
            functionSelectors: getSelectors(diamondCut)
        },
        {
            facetAddress: await tokenFacet.getAddress(),
            action: 0,
            functionSelectors: getSelectors(tokenFacet)
        },
        {
            facetAddress: await swapFacet.getAddress(),
            action: 0,
            functionSelectors: getSelectors(swapFacet)
        }
    ];

    // DiamondCut 실행
    const diamondCutInterface = await ethers.getContractAt(
        "DiamondCutFacet",
        await diamond.getAddress()
    );
    await diamondCutInterface.diamondCut(cuts);

    return diamond;
}

// Function selector 추출
function getSelectors(contract) {
    const signatures = Object.keys(contract.interface.functions);
    return signatures.map(sig => contract.interface.getFunction(sig).selector);
}
```

### 사용

```javascript
async function useDiamond(diamondAddress) {
    // TokenFacet 인터페이스로 접근
    const token = await ethers.getContractAt("TokenFacet", diamondAddress);
    
    await token.mint(user.address, ethers.parseUnits('1000', 18));
    const balance = await token.balanceOf(user.address);
    console.log("Balance:", ethers.formatUnits(balance, 18));

    // SwapFacet 인터페이스로 접근 (같은 주소!)
    const swap = await ethers.getContractAt("SwapFacet", diamondAddress);
    
    await swap.setSwapFee(30); // 0.3%
    const amountOut = await swap.swap(ethers.parseUnits('100', 18));
    console.log("Swapped:", ethers.formatUnits(amountOut, 18));
}
```

---

## 7. AppStorage 패턴

```solidity
// 모든 Facet이 공유하는 스토리지
struct AppStorage {
    // Token 데이터
    mapping(address => uint256) balances;
    uint256 totalSupply;
    
    // Swap 데이터
    uint256 swapFee;
    mapping(address => uint256) liquidityPool;
    
    // Governance 데이터
    mapping(uint256 => Proposal) proposals;
    uint256 proposalCount;
    
    // 공통 데이터
    address owner;
    bool paused;
}

// 각 Facet에서 동일한 방식으로 접근
function appStorage() internal pure returns (AppStorage storage s) {
    bytes32 position = APP_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}
```

---

## 8. Diamond vs 다른 패턴

```
┌─────────────────┬──────────┬───────────┬──────────┐
│                 │ Diamond  │ Proxy     │ 일반     │
├─────────────────┼──────────┼───────────┼──────────┤
│ 크기 제한       │ 없음     │ 24KB      │ 24KB     │
│ 업그레이드      │ 가능     │ 가능      │ 불가     │
│ 모듈화          │ 완벽     │ 제한적    │ 없음     │
│ 가스비          │ 높음     │ 중간      │ 낮음     │
│ 복잡도          │ 매우 높음│ 중간      │ 낮음     │
│ 적합한 사용처   │ 대규모   │ 중규모    │ 소규모   │
└─────────────────┴──────────┴───────────┴──────────┘
```

---

## 9. 보안 체크리스트

```solidity
// ✅ 해야 할 것

// 1. Selector 충돌 확인
// 같은 selector를 여러 Facet에 등록하면 안 됨

// 2. 권한 관리
modifier onlyOwner() {
    require(msg.sender == LibDiamond.diamondStorage().contractOwner);
    _;
}

// 3. AppStorage 일관성
// 모든 Facet이 동일한 AppStorage 구조 사용

// 4. Initializer 보호
bool initialized;
function initialize() external {
    require(!initialized, "Already initialized");
    initialized = true;
    // ...
}

// ❌ 하지 말아야 할 것

// 1. 서로 다른 storage layout
// 2. Facet 간 직접 호출
// 3. Constructor 사용 (Facet에서)
// 4. Hardcoded facet 주소
```

---

## 10. 실전 예제: DeFi Protocol

```solidity
// TokenFacet: ERC20
// SwapFacet: DEX
// StakingFacet: 스테이킹
// GovernanceFacet: 거버넌스
// AdminFacet: 관리

// 모두 하나의 Diamond 주소에서 접근!

const diamond = await ethers.getContractAt("TokenFacet", diamondAddress);
await diamond.transfer(to, amount);

const swap = await ethers.getContractAt("SwapFacet", diamondAddress);
await swap.swap(amountIn);

const staking = await ethers.getContractAt("StakingFacet", diamondAddress);
await staking.stake(amount);

// 같은 주소, 다른 기능!
```

---

## 11. FAQ

**Q: Diamond는 언제 사용하나요?**
- 24KB 제한을 초과하는 대규모 시스템
- 모듈식 설계가 필요한 경우
- 일부 기능만 업그레이드하고 싶을 때

**Q: 가스비가 더 비싼가요?**
- 네, selector 조회 때문에 약간 더 비쌉니다.
- 하지만 대규모 시스템에서는 이점이 더 큽니다.

**Q: Facet을 동적으로 추가/제거할 수 있나요?**
- 네! DiamondCut으로 런타임에 가능합니다.

**Q: OpenZeppelin에 있나요?**
- 아니요. 복잡도 때문에 직접 구현해야 합니다.
- 하지만 여러 레퍼런스 구현이 있습니다.

**Q: 실제 사용 사례는?**
- Aavegotchi
- DiamondDAO
- 대규모 DeFi 프로토콜

---

## 12. 다음 단계

1. ✅ `contracts/Diamond.sol` 확인
2. ✅ `contracts/LibDiamond.sol` 이해
3. ✅ Facet 작성 연습
4. ✅ DiamondCut으로 업그레이드 테스트
5. ✅ AppStorage 패턴 숙지
6. ✅ [Diamond Standard 문서](https://eips.ethereum.org/EIPS/eip-2535) 읽기

---

**마지막 업데이트**: 2025-11-05  
**버전**: 1.0.0

**주의**: Diamond는 고급 패턴입니다. 작은 프로젝트에서는 일반 Proxy를 사용하세요! 🚀

