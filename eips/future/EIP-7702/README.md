# EIP-7702 - Set Code for EOAs

##
 EOA(Externally Owned Account)      Account Abstraction  

##

###
- EOA   EIP-4337  
-        
-    

### EIP-7702
```
 "authorization" 
- EOA   
-    
```

##

### Authorization List
```javascript
//  authorization 
const tx = {
    to: myEOA,
    authorizationList: [
        {
            chainId: 1,
            address: "0x...",  // delegate  
            nonce: 0,
            v, r, s  // EOA 
        }
    ]
};
```

###
```
1.  EOA authorization 
2.  
3.  EOA   
4.  
5.   EOA 
```

##

### 1.
```solidity
//  EOA  
authorization: MultiSigWallet
-     2-of-3  
-    EOA 
```

### 2.
```solidity
//  Paymaster  
authorization: PaymasterWallet
-  USDC 
-   
```

### 3.
```solidity
//  Batch Executor 
authorization: BatchExecutor
-     
-   
```

## EIP-3074 vs EIP-7702

|  | EIP-3074 | EIP-7702 |
|------|----------|----------|
|  | AUTHCALL opcode | Authorization List |
|  |  |  |
|  |  () |  |
|  |  |  |

##

###
```solidity
// :      
authorization: unknownContract

// :   
authorization: verifiedWallet (OpenZeppelin, Safe )
```

###
```solidity
//   approval 
//     
```

##

### AA
```
1: EOA 
2:  EIP-7702 AA  
3:     
```

###
```
-  EOA   
-  AA  
-   
```

##

- ****: 2024 2
- ****: Draft → Review
- ****: Pectra  (2024-2025)

##
- [EIP-7702 Specification](https://eips.ethereum.org/EIPS/eip-7702)
- [Vitalik's Blog Post](https://vitalik.eth.limo/)
- [EIP-3074 Comparison](https://ethereum-magicians.org/)
