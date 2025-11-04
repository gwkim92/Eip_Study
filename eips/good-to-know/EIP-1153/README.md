# EIP-1153 - Transient Storage

##
     ( )

##

### Opcode
```solidity
// TSTORE:  
// TLOAD:  

// Solidity 0.8.24+ (    )
assembly {
    tstore(slot, value)  //  
    let temp := tload(slot)  //  
}
//    
```

##

### 1. Reentrancy Lock
```solidity
// Before:    ()
bool private locked;

modifier nonReentrant() {
    require(!locked);
    locked = true;
    _;
    locked = false;
}

// After: Transient Storage ()
modifier nonReentrantTransient() {
    assembly {
        if tload(0) { revert(0, 0) }
        tstore(0, 1)
    }
    _;
    assembly {
        tstore(0, 0)
    }
}
```

### 2.
```solidity
//       
contract A {
    function setTemp(uint256 value) external {
        assembly { tstore(0, value) }
    }
}

contract B {
    function getTemp() external view returns (uint256 value) {
        assembly { value := tload(0) }
    }
}
```

##

|  | SSTORE | TSTORE |  |
|------|--------|--------|--------|
|  | 20,000 | 100 | 99.5% |
|  | 2,100 | 100 | 95.2% |

##
-    
- View   
-  Solidity     (assembly )

##
- [EIP-1153 Specification](https://eips.ethereum.org/EIPS/eip-1153)
