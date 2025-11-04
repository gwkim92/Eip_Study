# EIP-2535: Diamond Pattern (Multi-Facet Proxy)

##
1. [](#)
2. [ ](#-)
3. [Diamond ](#diamond-)
4. [ ](#-)
5. [AppStorage Pattern](#appstorage-pattern)
6. [DiamondCut ](#diamondcut-)
7. [ ](#-)
8. [ ](#-)
9. [](#)
10. [](#)

---

##

EIP-2535 Diamond Pattern    **24KB  ** , ** **      .

###

```solidity
//  1: 24KB 
contract HugeContract {
    //   ...
    //  : Contract code size exceeds 24576 bytes
}

//  2:   
contract Module1 { }
contract Module2 { }
contract Module3 { }
// :  ,    ,  

//  3:   
contract Proxy {
    address implementation;  //   
}
```

### Diamond Pattern

```
Diamond (  )
    ↓ delegatecall
     FacetA (ERC20  )
     FacetB (ERC20  )
     FacetC ( )
     FacetD ( )
     FacetE ( )
```

** **:
-      (Facet)   
-  Facet 24KB  
-  Facet  
-     

---

##

### 1. Diamond ()
-    
-      Facet 
-     

### 2. Facet ()
-     
-  Facet   
-     

### 3. Function Selector ( )
-    4 (: `transfer(address,uint256)` → `0xa9059cbb`)
- Diamond selector   Facet  

### 4. DiamondCut ( )
- Facet // 
-     

### 5. Diamond Storage ( )
-  selector → Facet    
- EIP-2535     

### 6. AppStorage Pattern
-  Facet    
-    

---

## Diamond

### Diamond Storage

```solidity
library LibDiamond {
    //    
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;           // Facet  
        uint96 functionSelectorPosition; // selector  
    }

    struct DiamondStorage {
        //  selector → Facet  
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;

        // Facet  →  Facet  selector 
        mapping(address => bytes4[]) facetFunctionSelectors;

        //  Facet  
        address[] facetAddresses;

        //  
        address contractOwner;
    }

    // Diamond Storage  
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
```

###

```
 : diamond.transfer(to, amount)
    ↓
1. msg.sig = 0xa9059cbb (transfer  selector)
    ↓
2. DiamondStorage :
   selectorToFacetAndPosition[0xa9059cbb] = { facetAddress: 0xABC..., position: 0 }
    ↓
3. delegatecall(0xABC..., msg.data)
    ↓
4. ERC20Facet.transfer() 
```

---

##

### 1. LibDiamond.sol - Diamond Storage Library

Diamond    .

 :
- Diamond Storage 
- Facet // 
-  selector  

**  `contracts/LibDiamond.sol` **

### 2. Diamond.sol - Main Proxy Contract

     .

```solidity
contract Diamond {
    constructor(address _owner, address _diamondCutFacet) {
        LibDiamond.setContractOwner(_owner);

        // DiamondCut  
        LibDiamond.addFunctions(
            _diamondCutFacet,
            [IDiamondCut.diamondCut.selector]
        );
    }

    fallback() external payable {
        // 1.  selector Facet 
        address facet = LibDiamond.diamondStorage()
            .selectorToFacetAndPosition[msg.sig].facetAddress;

        require(facet != address(0), "Function does not exist");

        // 2. Facet delegatecall
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return (0, returndatasize()) }
        }
    }

    receive() external payable {}
}
```

### 3. DiamondCutFacet.sol - Facet Management

Facet    .

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
```

**  `contracts/DiamondCutFacet.sol` **

### 4. Example Facets -

```solidity
// ERC20  
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

// ERC20  
contract ERC20AdvancedFacet {
    AppStorage internal s;

    function mint(address to, uint256 amount) external {
        require(msg.sender == s.owner, "Not owner");
        s.balances[to] += amount;
        s.totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external {
        s.balances[msg.sender] -= amount;
        s.totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
```

**  `contracts/ExampleFacets.sol` **

---

## AppStorage Pattern

### AppStorage?

 Facet **  **   .

###

```solidity
// contracts/AppStorage.sol
struct AppStorage {
    // ERC20 
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    uint256 totalSupply;
    string name;
    string symbol;
    uint8 decimals;

    //  
    address owner;

    //  
    mapping(uint256 => Proposal) proposals;
    uint256 proposalCount;

    //  
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

### Facet

```solidity
contract SomeFacet {
    AppStorage internal s;  // slot 0  

    function someFunction() external {
        //    
        s.balances[msg.sender] += 100;
        s.totalSupply += 100;
    }
}
```

###

```solidity
// :     
struct AppStorage {
    uint256 value;      // slot 0
    address owner;      // slot 1
}

//     !
struct AppStorage {
    address owner;      // slot 0 ( value   )
    uint256 value;      // slot 1 ( owner   )
}

//  :  
struct AppStorage {
    uint256 value;      // slot 0 - 
    address owner;      // slot 1 - 
    uint256 newValue;   // slot 2 -  
    address newOwner;   // slot 3 -  
}
```

---

## DiamondCut

### FacetCut

```solidity
enum FacetCutAction {
    Add,        //   
    Replace,    //   
    Remove      //  
}

struct FacetCut {
    address facetAddress;           // Facet  (Remove  )
    FacetCutAction action;          //  
    bytes4[] functionSelectors;     //   selector 
}
```

###

```solidity
// 1.  Facet 
FacetCut memory addCut = FacetCut({
    facetAddress: address(newFacet),
    action: FacetCutAction.Add,
    functionSelectors: [
        NewFacet.newFunction1.selector,
        NewFacet.newFunction2.selector
    ]
});

// 2.    ()
FacetCut memory replaceCut = FacetCut({
    facetAddress: address(upgradedFacet),
    action: FacetCutAction.Replace,
    functionSelectors: [
        UpgradedFacet.existingFunction.selector
    ]
});

// 3.  
FacetCut memory removeCut = FacetCut({
    facetAddress: address(0),  // Remove   
    action: FacetCutAction.Remove,
    functionSelectors: [
        bytes4(keccak256("oldFunction()"))
    ]
});

// DiamondCut 
FacetCut[] memory cuts = new FacetCut[](3);
cuts[0] = addCut;
cuts[1] = replaceCut;
cuts[2] = removeCut;

IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

###

```solidity
//   
contract DiamondInit {
    function init(string memory name, string memory symbol) external {
        AppStorage storage s;
        assembly { s.slot := 0 }

        s.name = name;
        s.symbol = symbol;
        s.decimals = 18;
    }
}

// DiamondCut   
IDiamondCut(diamond).diamondCut(
    cuts,
    address(diamondInit),
    abi.encodeWithSelector(
        DiamondInit.init.selector,
        "MyToken",
        "MTK"
    )
);
```

---

##

### 1.  Selector

```solidity
// :  selector  
contract FacetA {
    function getData() external view returns (uint256) { }
}

contract FacetB {
    function getData() external view returns (string memory) { }
    // selector   !
}

// :   
contract FacetB {
    function getDataString() external view returns (string memory) { }
}
```

### 2. Storage

```solidity
// : Facet  storage 
contract FacetA {
    uint256 public value;  // slot 0
    address public owner;  // slot 1
}

contract FacetB {
    address public admin;  // slot 0 - FacetA value !
    uint256 public count;  // slot 1 - FacetA owner !
}

// : AppStorage  
contract FacetA {
    AppStorage internal s;
    // s.value, s.owner 
}

contract FacetB {
    AppStorage internal s;
    //   
}
```

### 3.

```solidity
// DiamondCutFacet   
function diamondCut(...) external {
    LibDiamond.enforceIsContractOwner();  //   
    // ...
}

//  Facet   
contract AdminFacet {
    AppStorage internal s;

    function setOwner(address newOwner) external {
        require(msg.sender == s.owner, "Not owner");
        s.owner = newOwner;
    }
}
```

### 4. Delegatecall

```solidity
// : selfdestruct 
contract MaliciousFacet {
    function destroy() external {
        selfdestruct(payable(msg.sender));  // Diamond !
    }
}

// : selfdestruct  
// DiamondCut        Facet 
```

### 5.

```solidity
contract DiamondInit {
    bool private initialized;

    function init() external {
        require(!initialized, "Already initialized");
        initialized = true;
        //  ...
    }
}
```

### 6. Function Selector

```solidity
// LibDiamond   
function addFunction(...) internal {
    require(selector != bytes4(0), "Invalid selector");
    require(
        ds.selectorToFacetAndPosition[selector].facetAddress == address(0),
        "Function already exists"
    );
    // ...
}
```

---

##

###

```solidity
// scripts/DeployDiamond.sol
contract DeployDiamond {
    function deploy() external returns (address) {
        // 1. Facet 
        DiamondCutFacet diamondCut = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownership = new OwnershipFacet();
        ERC20Facet erc20 = new ERC20Facet();
        ERC20AdvancedFacet erc20Advanced = new ERC20AdvancedFacet();

        // 2. Diamond 
        Diamond diamond = new Diamond(msg.sender, address(diamondCut));

        // 3. FacetCut 
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // DiamondLoupe Facet
        cuts[0] = createFacetCut(
            address(diamondLoupe),
            IDiamondCut.FacetCutAction.Add,
            getDiamondLoupeSelectors()
        );

        // Ownership Facet
        cuts[1] = createFacetCut(
            address(ownership),
            IDiamondCut.FacetCutAction.Add,
            getOwnershipSelectors()
        );

        // ERC20 Facet
        cuts[2] = createFacetCut(
            address(erc20),
            IDiamondCut.FacetCutAction.Add,
            getERC20Selectors()
        );

        // ERC20Advanced Facet
        cuts[3] = createFacetCut(
            address(erc20Advanced),
            IDiamondCut.FacetCutAction.Add,
            getERC20AdvancedSelectors()
        );

        // 4.  
        DiamondInit diamondInit = new DiamondInit();
        bytes memory initData = abi.encodeWithSelector(
            DiamondInit.init.selector,
            "Diamond Token",
            "DMT",
            18
        );

        // 5. DiamondCut 
        IDiamondCut(address(diamond)).diamondCut(
            cuts,
            address(diamondInit),
            initData
        );

        return address(diamond);
    }

    function createFacetCut(
        address facetAddress,
        IDiamondCut.FacetCutAction action,
        bytes4[] memory selectors
    ) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facetAddress,
            action: action,
            functionSelectors: selectors
        });
    }

    function getERC20Selectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = ERC20Facet.transfer.selector;
        selectors[1] = ERC20Facet.transferFrom.selector;
        selectors[2] = ERC20Facet.approve.selector;
        selectors[3] = ERC20Facet.balanceOf.selector;
        selectors[4] = ERC20Facet.allowance.selector;
        selectors[5] = ERC20Facet.totalSupply.selector;
        return selectors;
    }

    function getERC20AdvancedSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ERC20AdvancedFacet.mint.selector;
        selectors[1] = ERC20AdvancedFacet.burn.selector;
        return selectors;
    }

    function getDiamondLoupeSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;
        return selectors;
    }

    function getOwnershipSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = OwnershipFacet.owner.selector;
        selectors[1] = OwnershipFacet.transferOwnership.selector;
        return selectors;
    }
}
```

###

```solidity
//  ERC20Facet   
contract UpgradeDiamond {
    function upgradeERC20Facet(address diamond) external {
        // 1.  Facet 
        ERC20FacetV2 newERC20 = new ERC20FacetV2();

        // 2.   
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ERC20FacetV2.transfer.selector;
        selectors[1] = ERC20FacetV2.transferFrom.selector;

        // 3. FacetCut 
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newERC20),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });

        // 4.  
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }
}
```

###

```solidity
// Diamond ERC20 
contract UseDiamond {
    function useToken(address diamond) external {
        // Diamond  ERC20  
        IERC20 token = IERC20(diamond);

        //  ERC20 
        token.transfer(msg.sender, 100 ether);
        token.approve(address(this), 1000 ether);

        uint256 balance = token.balanceOf(msg.sender);

        //    
        ERC20AdvancedFacet(diamond).mint(msg.sender, 500 ether);
    }
}
```

---

##

###

**24KB  **
-  Facet 24KB      
-     (: Aavegotchi)

**  **
-      
-    
-      

** **
-  Facet 
-      
- delegatecall  

**  **
-     
-     
- UI/UX  

** **
-   / 
- A/B     
-    

** **
- EIP-2535   
- DiamondLoupe  
-    

###

** **
-   
-    
-    

** **
-    
-    
-   

** **
-     
-  selector  
-    

** **
- Storage  
- Function selector   
-     

**  **
- Etherscan    
-     
-    

### ?

** **:
-    (24KB )
-    
-    
-     

** **:
-   (< 20KB)
-    
-     
-    

---

## OpenZeppelin

Diamond Pattern OpenZeppelin   :

### 1. OpenZeppelin

```solidity
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERC20Facet is ReentrancyGuard {
    AppStorage internal s;

    function transfer(address to, uint256 amount)
        external
        nonReentrant
        returns (bool)
    {
        s.balances[msg.sender] -= amount;
        s.balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}
```

### 2.

```solidity
// : OpenZeppelin storage   
contract BadFacet is Ownable {
    // Ownable storage AppStorage !
}

// : AppStorage   
struct AppStorage {
    address owner;  // Ownable 
    // ...
}

//  LibOwnable   
library LibOwnable {
    function owner() internal view returns (address) {
        AppStorage storage s;
        assembly { s.slot := 0 }
        return s.owner;
    }
}
```

---

##

###
- [EIP-2535 Specification](https://eips.ethereum.org/EIPS/eip-2535)
- [Diamond Standard GitHub](https://github.com/mudgen/diamond)
- [Nick Mudge's Blog](https://dev.to/mudgen/ethereum-s-maximum-contract-size-limit-is-solved-with-the-diamond-standard-2189)

###
- [Diamond-1 Reference Implementation](https://github.com/mudgen/diamond-1-hardhat)
- [Diamond-2 Reference Implementation](https://github.com/mudgen/diamond-2-hardhat)
- [Diamond-3 Reference Implementation](https://github.com/mudgen/diamond-3-hardhat)

###
- [Aavegotchi](https://github.com/aavegotchi/aavegotchi-contracts) - NFT  
- [Louper.dev](https://louper.dev/) - Diamond  
- [Paladin](https://github.com/PaladinFinance) - DeFi 

###
- [Louper Diamond Inspector](https://louper.dev/) - Diamond  
- [Diamond-Deploy](https://github.com/Web3-Builders-Alliance/diamond-deploy) -  
- [Hardhat Diamond Plugin](https://www.npmjs.com/package/hardhat-diamond-abi) - Hardhat 

###
- [EIP-2535 Discussion](https://ethereum-magicians.org/t/eip-2535-diamond-standard-for-upgradeable-contracts/4091)
- [Discord Server](https://discord.gg/kQewPw2)

---

##

### EIP
- [EIP-1967](https://eips.ethereum.org/EIPS/eip-1967) - Proxy Storage Slots
- [EIP-1822](https://eips.ethereum.org/EIPS/eip-1822) - Universal Upgradeable Proxy
- [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535) - Diamond Standard

###
- [Understanding EIP-2535](https://medium.com/@mudgen/understanding-diamonds-eip-2535-3e03c7bbb6d1)
- [How to Share Functions Between Facets](https://eip2535diamonds.substack.com/p/how-to-share-functions-between-facets)
- [Diamond Storage](https://dev.to/mudgen/how-diamond-storage-works-90e)

---

  EIP-2535 Diamond Pattern     .
   `contracts/`    .
