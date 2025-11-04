# EIP-1271: Contract Signature Validation (  )

## (Overview)

EIP-1271         .  (EOA) `ecrecover`     ,       .

EIP-1271 is a standard interface that allows smart contracts to verify signatures. While Externally Owned Accounts (EOA) can verify signatures using `ecrecover`, smart contract wallets require their own verification logic.

## (Problem)

### EOA
```solidity
// EOA ecrecover   
address signer = ecrecover(hash, v, r, s);
require(signer == expectedAddress, "Invalid signature");
```

###
1. ** **:    
2. **  **:    (Gnosis Safe, Account Abstraction)
3. ** **:    
4. **  **:    

  `ecrecover`   .

## (Solution)

### EIP-1271

```solidity
interface IERC1271 {
    /**
     * @dev    
     * @param hash   
     * @param signature  
     * @return magicValue  0x1626ba7e,   
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue);
}
```

### Magic Value
- ****: `0x1626ba7e` (bytes4(keccak256("isValidSignature(bytes32,bytes)")))
- ****:     revert

## (Key Use Cases)

### 1. Gnosis Safe ( )
```solidity
// Gnosis Safe EIP-1271   
//     (threshold)  
```

### 2. Account Abstraction (EIP-4337)
```solidity
//    UserOperation  
//  ,      
```

### 3. DAO
```solidity
// DAO      
```

### 4. NFT
```solidity
//    NFT    
```

## EIP-712  (Integration with EIP-712)

EIP-1271 EIP-712(Typed Structured Data Hashing)      .

```solidity
// EIP-712   
bytes32 structHash = keccak256(abi.encode(
    TYPE_HASH,
    data1,
    data2
));

bytes32 digest = keccak256(abi.encodePacked(
    "\x19\x01",
    DOMAIN_SEPARATOR,
    structHash
));

// EIP-1271  
bytes4 magicValue = IERC1271(wallet).isValidSignature(digest, signature);
require(magicValue == 0x1626ba7e, "Invalid signature");
```

## (Implementation Patterns)

### 1.   (Basic Implementation)
     

### 2.   (Multi-Signature)
    

### 3.    (Role-Based)
     

### 4.    (Session Keys)
      

## (Security Considerations)

### 1.   (Reentrancy)
```solidity
//  :     
function isValidSignature(bytes32 hash, bytes memory signature)
    external view returns (bytes4)
{
    // view    
    //    
}
```

### 2.    (Signature Replay)
```solidity
//  : nonce  ID 
struct Message {
    address to;
    uint256 value;
    uint256 nonce;
    uint256 chainId;
}
```

### 3.   (Signature Malleability)
```solidity
// ECDSA  s   
require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
    "Invalid s value");
```

### 4.   (Domain Separation)
```solidity
// EIP-712   
bytes32 DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes("MyContract")),
    keccak256(bytes("1")),
    block.chainid,
    address(this)
));
```

### 5.   (Gas Limits)
```solidity
// isValidSignature view      
//      
```

## (Practical Examples)

### 1: OpenSea
```solidity
// OpenSea    NFT   
function validateOrder(Order memory order, bytes memory signature) public view {
    bytes32 orderHash = _hashOrder(order);

    if (order.maker.code.length > 0) {
        //  : EIP-1271 
        require(
            IERC1271(order.maker).isValidSignature(orderHash, signature) == 0x1626ba7e,
            "Invalid contract signature"
        );
    } else {
        // EOA: ecrecover 
        address signer = ecrecover(orderHash, v, r, s);
        require(signer == order.maker, "Invalid EOA signature");
    }
}
```

### 2:
```solidity
// Gnosis Safe  
function executeTransaction(
    address to,
    uint256 value,
    bytes memory data,
    bytes memory signatures
) public {
    bytes32 txHash = keccak256(abi.encode(to, value, data, nonce));

    // EIP-1271  
    require(
        isValidSignature(txHash, signatures) == 0x1626ba7e,
        "Invalid signatures"
    );

    nonce++;
    (bool success,) = to.call{value: value}(data);
    require(success, "Transaction failed");
}
```

### 3:
```solidity
//     
struct SessionKey {
    address key;
    uint256 expiresAt;
    uint256 spendLimit;
}

function isValidSignature(bytes32 hash, bytes memory signature)
    external view returns (bytes4)
{
    address signer = recoverSigner(hash, signature);

    //  
    if (signer == owner) {
        return 0x1626ba7e;
    }

    //   
    SessionKey memory session = sessionKeys[signer];
    if (session.expiresAt > block.timestamp &&
        session.spendLimit > 0) {
        return 0x1626ba7e;
    }

    return 0xffffffff;
}
```

## (Test Scenarios)

### 1.
-   
-   
- Magic value 

### 2.
-   
-   
-   

### 3.
-   
-   
-   

### 4.
- EIP-712 
-   
-   

## (Best Practices)

### 1.
```solidity
// ERC-165  
function supportsInterface(bytes4 interfaceId) public view returns (bool) {
    return interfaceId == type(IERC1271).interfaceId ||
           interfaceId == type(IERC165).interfaceId;
}
```

### 2.
```solidity
//      
if (signatures.length < requiredSignatures) {
    revert("Insufficient signatures");
}
```

### 3.
```solidity
//     
event SignatureValidated(bytes32 indexed hash, address indexed validator);
```

### 4.
```solidity
//     
//      
```

##

### 1. **Gnosis Safe**
-     
- EIP-1271  
-  

### 2. **Argent Wallet**
-   
-  
- EIP-1271 

### 3. **Safe ( Gnosis Safe)**
- Account Abstraction 
-  
- EIP-1271 + EIP-712

### 4. **Ambire Wallet**
-  
-  
- EIP-1271  

##

### EOA
```solidity
// 1:    
function verifySignature(
    address account,
    bytes32 hash,
    bytes memory signature
) public view returns (bool) {
    if (account.code.length > 0) {
        // : EIP-1271
        try IERC1271(account).isValidSignature(hash, signature)
            returns (bytes4 magicValue) {
            return magicValue == 0x1626ba7e;
        } catch {
            return false;
        }
    } else {
        // EOA: ecrecover
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        return ecrecover(hash, v, r, s) == account;
    }
}

// 2:   
// 3:   
// 4:  
```

## (References)

- [EIP-1271  ](https://eips.ethereum.org/EIPS/eip-1271)
- [EIP-712: Typed Structured Data](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [Gnosis Safe ](https://github.com/safe-global/safe-contracts)

## (License)

MIT License

---

****: 2025-10-31
****: 1.0.0
