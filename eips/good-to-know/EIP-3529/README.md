# EIP-3529 - Gas Refund Reduction

##
SELFDESTRUCT SSTORE        

##

### Before EIP-3529
```solidity
// SSTORE: 0 -> non-zero -> 0
delete storage[key];  // 15,000 gas 

// SELFDESTRUCT
selfdestruct(payable(msg.sender));  // 24,000 gas 
```

### After EIP-3529
```solidity
// SSTORE : 
delete storage[key];  //   (4,800 gas )

// SELFDESTRUCT : 
selfdestruct(payable(msg.sender));  //  
```

##

### (GasToken)
```solidity
//    (    )
// 1.     
// 2.       
// EIP-3529  
```

###
- delete      
- SELFDESTRUCT   (EIP-6780  )
-    

##
- [EIP-3529 Specification](https://eips.ethereum.org/EIPS/eip-3529)
