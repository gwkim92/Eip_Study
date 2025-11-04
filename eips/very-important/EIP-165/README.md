# EIP-165 - Interface Detection

##
        

##

###
```solidity
//  ERC721     ?
//    
```

###
```solidity
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// Interface ID : XOR of all function selectors
bytes4 constant ERC721_INTERFACE_ID = 0x80ac58cd;
```

##

```solidity
contract ERC721 is IERC165 {
    function supportsInterface(bytes4 interfaceId) 
        public view virtual override returns (bool) {
        return interfaceId == type(IERC721).interfaceId ||
               interfaceId == type(IERC165).interfaceId;
    }
}
```

##

```solidity
//   
function safeInteract(address contractAddress) public {
    IERC165 target = IERC165(contractAddress);
    
    if (target.supportsInterface(type(IERC721).interfaceId)) {
        // ERC721   
        IERC721(contractAddress).ownerOf(tokenId);
    }
}
```

##
- [EIP165Example.sol](./contracts/EIP165Example.sol)
- [ERC721WithEIP165.sol](./contracts/ERC721WithEIP165.sol)

##
- [EIP-165 Specification](https://eips.ethereum.org/EIPS/eip-165)
