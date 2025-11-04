# EIP-2930 - Access Lists

##
       

##

### Access List?
```javascript
// Type 1  (EIP-2930)
const tx = {
    to: contractAddress,
    data: calldata,
    accessList: [
        {
            address: "0x...",  //  
            storageKeys: [     //   
                "0x0000...",
                "0x0001..."
            ]
        }
    ]
};
```

##

###
-  : 2600 gas (cold access)
- Access List : 2400 gas
-   : 100 gas (warm access)

###
```javascript
// ethers.js
const accessList = await provider.send("eth_createAccessList", [{
    to: contractAddress,
    data: calldata
}]);

const tx = await signer.sendTransaction({
    ...txData,
    accessList: accessList.accessList,
    type: 1  // EIP-2930 
});
```

##
- EIP-1559 (Type 2)   
- Access List 
-   

##
- [EIP-2930 Specification](https://eips.ethereum.org/EIPS/eip-2930)
