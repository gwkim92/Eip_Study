# EIP-4337 - Account Abstraction

##
      ,  ,     

##

### EOA
```
-     
-  ETH  
-   
-    
```

### Account Abstraction
```solidity
//   
contract SmartAccount {
    // 1. 
    address[] public owners;
    
    // 2.  
    address[] public guardians;
    
    // 3.  
    mapping(address => bool) public sessionKeys;
    
    // 4.  ERC-20 
    function payWithToken() external;
    
    // 5.  
    function executeBatch(Call[] calldata calls) external;
}
```

##

###

```
User - UserOperation - Bundler - EntryPoint - Wallet Contract
```

1. **UserOperation**:    
2. **Bundler**: UserOp    
3. **EntryPoint**:      
4. **Wallet Contract**:   

### UserOperation
```solidity
struct UserOperation {
    address sender;              //  
    uint256 nonce;
    bytes initCode;             //    ( )
    bytes callData;             //   
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;     //   
    bytes signature;
}
```

##

### 1. Social Recovery ( )
```solidity
contract RecoverableWallet {
    address public owner;
    address[] public guardians;
    
    function recover(address newOwner) external {
        require(msg.sender == guardian);
        owner = newOwner;
    }
}
```

### 2. Paymaster ( )
```solidity
contract Paymaster {
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);
    
    //    
}
```

### 3. Batch Transactions
```solidity
function executeBatch(Call[] calldata calls) external {
    for (uint256 i = 0; i < calls.length; i++) {
        (bool success,) = calls[i].target.call(calls[i].data);
        require(success);
    }
}
```

### 4. Session Keys
```solidity
//  DApp 
mapping(address => SessionKey) public sessionKeys;

struct SessionKey {
    address key;
    uint256 spending Limit;
    uint256 expiresAt;
}
```

##

###
- **Safe (Gnosis Safe)**:  + EIP-4337
- **Argent**:   + 
- **Biconomy**:  
- **ZeroDev**:   

### EntryPoint  (v0.6)
```
0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
```

##

###
-   
-  
-  
-  
-   /DApp UX 

###
-  
-    ( )
- Bundler 

##

### SDK
```javascript
// @alchemy/aa-sdk
import { SimpleSmartContractAccount } from "@alchemy/aa-sdk";

const account = new SimpleSmartContractAccount({
    entryPointAddress: "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    chain: mainnet,
    owner: signer,
});

// UserOperation 
const result = await account.sendUserOperation({
    target: recipient,
    data: calldata,
});
```

##
- [EIP-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [Account Abstraction Official Site](https://www.erc4337.io/)
- [Alchemy AA SDK](https://accountkit.alchemy.com/)
- [Stackup](https://www.stackup.sh/)
