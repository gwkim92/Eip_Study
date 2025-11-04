# EIP-5192 - Soulbound Tokens (Minimal)

##
  (Soulbound Token)   

##

###
- Vitalik Buterin "Decentralized Society" 
-  , ,   

###
```solidity
interface IERC5192 {
    event Locked(uint256 tokenId);
    event Unlocked(uint256 tokenId);
    
    function locked(uint256 tokenId) external view returns (bool);
}
```

##

```solidity
contract SoulboundToken is ERC721, IERC5192 {
    function locked(uint256 tokenId) external pure returns (bool) {
        return true; //  
    }
    
    function _update(address to, uint256 tokenId, address auth)
        internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        //  ,  
        require(from == address(0), "Soulbound: Transfer not allowed");
        
        return super._update(to, tokenId, auth);
    }
}
```

##

### 1.
```solidity
contract DegreeCertificate is SoulboundToken {
    function mint(address student, string memory degreeInfo) external {
        uint256 tokenId = nextTokenId++;
        _mint(student, tokenId);
        emit Locked(tokenId);
    }
}
```

### 2. POAP (Proof of Attendance)
```solidity
contract AttendanceBadge is SoulboundToken {
    mapping(uint256 => string) public eventName;
    
    function mintBadge(address attendee, string memory event) external {
        uint256 tokenId = nextTokenId++;
        _mint(attendee, tokenId);
        eventName[tokenId] = event;
        emit Locked(tokenId);
    }
}
```

### 3.
```solidity
contract ReputationToken is SoulboundToken {
    mapping(address => uint256) public reputationScore;
    
    function increaseReputation(address user, uint256 amount) external {
        reputationScore[user] += amount;
    }
}
```

##

### SBT
```solidity
contract TimeLockSBT is ERC721, IERC5192 {
    mapping(uint256 => uint256) public unlockTime;
    
    function locked(uint256 tokenId) external view returns (bool) {
        return block.timestamp < unlockTime[tokenId];
    }
}
```

###
```solidity
contract ConditionalSBT is ERC721, IERC5192 {
    mapping(uint256 => bool) public isLocked;
    
    function unlock(uint256 tokenId) external onlyOwner {
        isLocked[tokenId] = false;
        emit Unlocked(tokenId);
    }
}
```

##
- [SoulboundToken.sol](./contracts/SoulboundToken.sol)
- [TimeLockSBT.sol](./contracts/TimeLockSBT.sol)
- [BadgeSystem.sol](./contracts/BadgeSystem.sol)

##
- [EIP-5192 Specification](https://eips.ethereum.org/EIPS/eip-5192)
- [Decentralized Society Paper](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4105763)
