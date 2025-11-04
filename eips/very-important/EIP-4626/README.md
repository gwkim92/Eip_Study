# EIP-4626 - Tokenized Vault Standard

##
  (Yield Vault)   

##

###
- Yearn, Compound, Aave   
- DeFi  

###
```solidity
interface IERC4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}
```

##

```solidity
contract SimpleVault is ERC4626 {
    constructor(IERC20 asset) ERC4626(asset) ERC20("Vault Token", "vToken") {}
    
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
```

##

```javascript
// 1000 USDC 
const assets = ethers.parseUnits("1000", 6);
const shares = await vault.deposit(assets, userAddress);

//  
const withdrawn = await vault.redeem(shares, userAddress, userAddress);
```

##
- Inflation Attack :   
- Rounding:   

##
- [SimpleVault.sol](./contracts/SimpleVault.sol)
- [YieldVault.sol](./contracts/YieldVault.sol)

##
- [EIP-4626 Specification](https://eips.ethereum.org/EIPS/eip-4626)
