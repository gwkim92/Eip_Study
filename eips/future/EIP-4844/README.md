# EIP-4844 - Blob Transactions (Proto-Danksharding)

##
L2   (Data Availability)       

##

### : L2
```
L2   Ethereum 
→ CALLDATA  ( )
→ L2  90% L1  
```

### : Blob
```
Blob =   
- : 128KB (4096 field elements)
- : CALLDATA 1/10
- :  18  
- : L2  
```

##

### Type 3
```javascript
// Type 3: Blob Transaction
const tx = {
    to: rollupContract,
    maxFeePerGas: ...,
    maxPriorityFeePerGas: ...,
    maxFeePerBlobGas: ...,  //  !
    blobVersionedHashes: [  // Blob 
        "0x01...",
        "0x01..."
    ],
    type: 3
};

// Blob    
```

### Blob
```
- Base fee for blob gas
- EIP-1559  
-   
- :  3 blobs ( 6)
```

##

### CALLDATA vs Blob

|  | CALLDATA | Blob |
|------|----------|------|
|  |   | 128KB  |
|  | 16 gas/byte | ~1 gas/byte |
|  |  | ~18 |
|  |   |  |
|  |   | DA |

###
```
Optimism :
- Before: $0.50 per txn
- After: $0.05 per txn
- : 90%
```

##

### L2
```solidity
// L2 → L1  

// Before: CALLDATA
function postBatch(bytes calldata data) external {
    // data CALLDATA  ()
}

// After: Blob
function postBatchBlob(
    bytes32[] calldata blobVersionedHashes
) external {
    // Blob   ()
    //   Blob
}
```

### Blob
```
Blob = 4096 field elements
 field element = 32 bytes
 128 KB

KZG Commitment 
-   
```

##

###
```
L2 Sequencer
  | batch transactions
  | create blob
  v
Blob Transaction (Type 3)
  v
Ethereum L1 ()
  v
Blob stored temporarily (~18 days)
  v
Anyone can download & verify
  v
After 18 days: deleted (but commitment remains)
```

### KZG Commitment
```
- Cryptographic commitment
- Blob   
-   (48 bytes)
-   
```

## L2

### Optimistic Rollups
- **Optimism**: 2024 3 
- **Arbitrum**: 2024 3 
- **Base**: 2024 3 

### ZK Rollups
- **zkSync**: 2024 4 
- **Starknet**: 2024 5 
- **Polygon zkEVM**: 2024 

##

### 1.
```
- 18   
- L2    
- Archive   
```

### 2.
```solidity
// : Blob   
function readBlob(bytes32 blobHash) external view returns (bytes memory) {
    // Blob   
}

// : Blob  
bytes32 public blobHash;
```

### 3.
```
- L2 Data Availability 
-  DApp   
-   
```

##

### Proto-Danksharding (EIP-4844)
```
:  3-6 blobs
-  375 KB - 750 KB/block
```

### Full Danksharding ()
```
:   MB
- 1000  
- L2  $0.001 
```

##

### Blob
```javascript
// ethers.js v6 ()
const blob = createBlob(data); // 128KB 

const tx = await signer.sendTransaction({
    to: rollupContract,
    maxFeePerBlobGas: ...,
    blobs: [blob],
    type: 3
});
```

### Blob
```javascript
// Beacon Chain API
const blob = await fetch(
    `https://beacon-node/eth/v1/beacon/blob_sidecars/${blockId}`
);
```

##

### L2
```
Optimism :
- 2024 2: $0.50/txn
- 2024 4 (Blob ): $0.05/txn
- : 90%
```

### Ethereum
```
L1  : ~15 TPS
L2 + CALLDATA: ~300 TPS
L2 + Blob: ~3,000 TPS
Full Danksharding: ~100,000 TPS
```

##
- [EIP-4844 Specification](https://eips.ethereum.org/EIPS/eip-4844)
- [Danksharding Explained](https://ethereum.org/en/roadmap/danksharding/)
- [Blobscan](https://blobscan.com/) - Blob 
- [L2BEAT](https://l2beat.com/) - L2 
