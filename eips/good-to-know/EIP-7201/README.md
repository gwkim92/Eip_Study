# EIP-7201 - Namespaced Storage Layout

##
       

##

### :
```solidity
contract Logic {
    uint256 public value;     // slot 0
    address public owner;     // slot 1
    //     
}
```

### : Namespaced Storage
```solidity
// EIP-7201   
// keccak256(abi.encode(uint256(keccak256("example.storage")) - 1)) & ~bytes32(uint256(0xff))

struct ExampleStorage {
    uint256 value;
    address owner;
    mapping(address => uint256) balances;
}

function getExampleStorage() private pure returns (ExampleStorage storage $) {
    assembly {
        $.slot := 0x... // EIP-7201  
    }
}

function setValue(uint256 newValue) external {
    ExampleStorage storage $ = getExampleStorage();
    $.value = newValue;
}
```

##

### 1.
-   OK
-   OK  
-  / OK

### 2.
```solidity
struct TokenStorage { ... }
struct GovernanceStorage { ... }
struct StakingStorage { ... }

//   namespace
function getTokenStorage() private pure returns (TokenStorage storage $) { ... }
function getGovernanceStorage() private pure returns (GovernanceStorage storage $) { ... }
```

##

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyContract {
    // @custom:storage-location erc7201:example.main
    struct MainStorage {
        uint256 value;
        address owner;
        mapping(address => uint256) balances;
    }

    // keccak256(abi.encode(uint256(keccak256("example.main")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MAIN_STORAGE_LOCATION = 
        0x...;

    function _getMainStorage() private pure returns (MainStorage storage $) {
        assembly {
            $.slot := MAIN_STORAGE_LOCATION
        }
    }

    function deposit() external payable {
        MainStorage storage $ = _getMainStorage();
        $.balances[msg.sender] += msg.value;
    }
}
```

##

|  | EIP-1967 | EIP-7201 |
|------|----------|----------|
|  | Proxy  |   |
|  |   |  |
|  |  |  |

##
- [EIP-7201 Specification](https://eips.ethereum.org/EIPS/eip-7201)
- [OpenZeppelin Storage Namespaces](https://docs.openzeppelin.com/contracts/5.x/api/utils#StorageSlot)
