# EIP-712

##

### Hardhat

```bash
# 1.
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox

# 2. Hardhat
npx hardhat init

# 3.
# contracts/  EIP712Example.sol

# 4.
npx hardhat test tests/EIP712Example.test.js
```

### Foundry

```bash
# 1. Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2.
forge init

# 3.
forge test
```

##

### Domain Separator
- Domain Separator  
- name, version 

###
-   
- permit  
-   
-  deadline 
- Nonce  

###
- approve  

##

```
EIP712Example
  Domain Separator
     domain separator  
    name version   
  Permit  
         
    permit    
       
     deadline  
     nonce  
   approve 
    approve   

8 passing (2s)
```
