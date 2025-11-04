# EIP-1271    (Quick Start Guide)

## 5  EIP-1271  (Get Started in 5 Minutes)

### 1.   (Basic Concept)

```
EOA ( )                
   |                              |
   | ecrecover               | EIP-1271 
   v                              v
                        
```

****: EIP-1271       !

---

## 2.   (Minimal Implementation)

###

```solidity
interface IERC1271 {
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue);
}
```

###

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1271.sol";

contract SimpleWallet is IERC1271 {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        //   
        address signer = recoverSigner(hash, signature);

        //  
        if (signer == owner) {
            return 0x1626ba7e; // Magic value
        }

        return 0xffffffff; // Invalid
    }

    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) v += 27;

        return ecrecover(hash, v, r, s);
    }
}
```

---

## 3.   (How to Use)

### Frontend (ethers.js)

```javascript
import { ethers } from 'ethers';

// 1.  
const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();

// 2.  
const message = "Hello, EIP-1271!";
const messageHash = ethers.utils.id(message);
const signature = await signer.signMessage(ethers.utils.arrayify(messageHash));

// 3.   ()
const walletContract = new ethers.Contract(walletAddress, ABI, provider);
const magicValue = await walletContract.isValidSignature(messageHash, signature);

// 4.  
if (magicValue === "0x1626ba7e") {
    console.log(" ");
} else {
    console.log(" ");
}
```

---

## 4.    (Key Use Cases)

### A.   (Multi-sig Wallet)

```solidity
contract MultiSigWallet is IERC1271 {
    address[] public owners;
    uint256 public threshold; //   

    function isValidSignature(
        bytes32 hash,
        bytes memory signatures
    ) external view override returns (bytes4) {
        uint256 validCount = 0;

        //   
        for (uint256 i = 0; i < threshold; i++) {
            address signer = recoverSignerAt(hash, signatures, i);
            if (isOwner[signer]) {
                validCount++;
            }
        }

        return validCount >= threshold ? 0x1626ba7e : 0xffffffff;
    }
}
```

### B.   (Session Keys)

```solidity
contract SessionKeyWallet is IERC1271 {
    struct SessionKey {
        uint256 expiresAt;
        uint256 spendLimit;
    }

    mapping(address => SessionKey) public sessionKeys;

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        address signer = recoverSigner(hash, signature);

        //     
        if (signer == owner ||
            (sessionKeys[signer].expiresAt > block.timestamp)) {
            return 0x1626ba7e;
        }

        return 0xffffffff;
    }
}
```

### C.   (Social Recovery)

```solidity
contract SocialRecoveryWallet is IERC1271 {
    address[] public guardians;
    uint256 public recoveryThreshold;

    function initiateRecovery(address newOwner) external {
        require(isGuardian[msg.sender], "Not guardian");
        //  
    }
}
```

---

## 5. EIP-712   (With EIP-712)

```solidity
contract EIP712Wallet is IERC1271 {
    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("MyWallet")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        // EIP-712     
        address signer = recoverSigner(hash, signature);

        return signer == owner ? 0x1626ba7e : 0xffffffff;
    }
}
```

---

## 6. DApp  (DApp Integration)

###

```javascript
async function verifySignature(signer, hash, signature) {
    const provider = new ethers.providers.Web3Provider(window.ethereum);

    //   
    const code = await provider.getCode(signer);

    if (code !== '0x') {
        //  : EIP-1271 
        const contract = new ethers.Contract(signer, ERC1271_ABI, provider);
        const magicValue = await contract.isValidSignature(hash, signature);
        return magicValue === "0x1626ba7e";
    } else {
        // EOA: ecrecover 
        const recoveredAddress = ethers.utils.verifyMessage(
            ethers.utils.arrayify(hash),
            signature
        );
        return recoveredAddress.toLowerCase() === signer.toLowerCase();
    }
}
```

---

## 7.   (Common Mistakes)

###

```solidity
// 1. Nonce  ( )
function execute(address to, uint256 value, bytes memory signature) external {
    bytes32 hash = keccak256(abi.encodePacked(to, value));
    require(this.isValidSignature(hash, signature) == 0x1626ba7e);
    //      !
}

// 2.  ID  (  )
function getHash(address to, uint256 value) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(to, value));
    //      !
}

// 3.   
function executeForever(bytes memory signature) external {
    //   !
}
```

###

```solidity
// 1. Nonce 
mapping(address => uint256) public nonces;

function execute(address to, uint256 value, bytes memory signature) external {
    bytes32 hash = keccak256(abi.encodePacked(
        to,
        value,
        nonces[msg.sender]++  // Nonce   
    ));
    require(this.isValidSignature(hash, signature) == 0x1626ba7e);
}

// 2.  ID 
function getHash(address to, uint256 value) public view returns (bytes32) {
    return keccak256(abi.encodePacked(
        to,
        value,
        block.chainid  //  ID 
    ));
}

// 3.   
function executeWithDeadline(
    address to,
    uint256 value,
    uint256 deadline,
    bytes memory signature
) external {
    require(block.timestamp <= deadline, "Expired");
    // ...
}
```

---

## 8.  (Testing)

### Hardhat

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EIP-1271 Wallet", function () {
    it("   ", async function () {
        const [owner] = await ethers.getSigners();

        const Wallet = await ethers.getContractFactory("SimpleWallet");
        const wallet = await Wallet.deploy();

        const message = "test";
        const messageHash = ethers.utils.id(message);
        const signature = await owner.signMessage(
            ethers.utils.arrayify(messageHash)
        );

        const magicValue = await wallet.isValidSignature(messageHash, signature);

        expect(magicValue).to.equal("0x1626ba7e");
    });
});
```

---

## 9.  (Checklist)

  :

- [ ] `isValidSignature` `view` ?
- [ ] Magic value `0x1626ba7e` ?
- [ ] Nonce  ?
- [ ]  ID ?
- [ ]   ?
- [ ]   ?
- [ ] EIP-712  ?
- [ ]  ?
- [ ]  ?
- [ ]  ?

---

## 10.   (Next Steps)

1. ** **: `contracts/EIP1271Example.sol` 
2. ****: `contracts/MultiSigWallet.sol` 
3. ** **: `contracts/SessionKeyWallet.sol` 
4. ** **: `INTEGRATION_EXAMPLES.md` 
5. ****: `SECURITY.md` 
6. ****: `TEST_GUIDE.md` 

---

## 11.   (Useful Resources)

###
- [EIP-1271 ](https://eips.ethereum.org/EIPS/eip-1271)
- [EIP-712 ](https://eips.ethereum.org/EIPS/eip-712)

###
- [Gnosis Safe](https://github.com/safe-global/safe-contracts)
- [Argent Wallet](https://github.com/argentlabs/argent-contracts)
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)

###
- [Hardhat](https://hardhat.org/)
- [Ethers.js](https://docs.ethers.org/)
- [Remix IDE](https://remix.ethereum.org/)

---

## 12. FAQ

**Q: EOA    ?**
```javascript
const code = await provider.getCode(address);
const isContract = code !== '0x';
```

**Q: Magic value  `0x1626ba7e`?**
```javascript
// bytes4(keccak256("isValidSignature(bytes32,bytes)"))
// = 0x1626ba7e
```

**Q: isValidSignature  view ?**
-        .
-      .

**Q:    ?**
- :  storage  ( )
- :    ( )

**Q:    ?**
-   (concatenate)
- : `sig1 + sig2.slice(2) + sig3.slice(2)`

---

****: 2025-10-31
****: 1.0.0

****: `contracts/EIP1271Example.sol` !
