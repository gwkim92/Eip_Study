# EIP-2981 - NFT Royalty Standard

##
NFT 2      

##

###
```solidity
interface IERC2981 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external view returns (address receiver, uint256 royaltyAmount);
}
```

##

```solidity
contract MyNFT is ERC721, ERC2981 {
    constructor() ERC721("MyNFT", "MNFT") {
        // 5%  
        _setDefaultRoyalty(msg.sender, 500); // 500 = 5%
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
```

##

```solidity
//   
function buyNFT(address nftContract, uint256 tokenId) external payable {
    (address royaltyReceiver, uint256 royaltyAmount) = 
        IERC2981(nftContract).royaltyInfo(tokenId, msg.value);
    
    //  
    payable(royaltyReceiver).transfer(royaltyAmount);
    
    //   
    uint256 sellerProceeds = msg.value - royaltyAmount;
    payable(seller).transfer(sellerProceeds);
}
```

##
- : 2.5% - 10%
- OpenSea : 10%
- : 5%

##
- [ERC721WithRoyalty.sol](./contracts/ERC721WithRoyalty.sol)
- [MarketplaceExample.sol](./contracts/MarketplaceExample.sol)

##
- [EIP-2981 Specification](https://eips.ethereum.org/EIPS/eip-2981)
