# EIP-165 치트시트 (Cheat Sheet)

> 빠른 참고용 요약본

## 핵심 코드 스니펫

### 기본 구현
```solidity
contract MyContract is IERC165 {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId;
    }
}
```

### 다중 인터페이스 지원
```solidity
contract MyNFT is IERC165, IERC721 {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IERC721).interfaceId;
    }
}
```

### 상속 구조에서 super 사용
```solidity
contract Child is Parent, INewInterface {
    function supportsInterface(bytes4 interfaceId)
        public view override returns (bool)
    {
        return interfaceId == type(INewInterface).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}
```

### 안전한 인터페이스 확인
```solidity
function safeCheck(address target) internal view returns (bool) {
    try IERC165(target).supportsInterface(type(IERC721).interfaceId)
        returns (bool supported) {
        return supported;
    } catch {
        return false;
    }
}
```

---

## 주요 Interface IDs

| 인터페이스 | Interface ID | 계산 방법 |
|-----------|--------------|----------|
| IERC165 | `0x01ffc9a7` | `bytes4(keccak256('supportsInterface(bytes4)'))` |
| IERC721 | `0x80ac58cd` | 모든 ERC721 함수 selector XOR |
| IERC721Metadata | `0x5b5e139f` | name, symbol, tokenURI XOR |
| IERC1155 | `0xd9b67a26` | 모든 ERC1155 함수 selector XOR |
| IERC2981 (Royalty) | `0x2a55205a` | royaltyInfo selector |

### Interface ID 가져오기
```solidity
// 자동 (권장)
bytes4 id = type(IERC721).interfaceId;

// 수동 계산
bytes4 id = bytes4(keccak256("functionName(paramTypes)"));
```

---

## 체크리스트

### 구현 시
- [ ] `supportsInterface(bytes4)` 함수 구현
- [ ] `type(IERC165).interfaceId` (0x01ffc9a7) 반환
- [ ] 구현하는 모든 인터페이스 ID 반환
- [ ] `0xffffffff`는 `false` 반환
- [ ] 상속 시 `super.supportsInterface()` 호출

### 사용 시
- [ ] 외부 호출 전 인터페이스 확인
- [ ] try-catch로 안전하게 감싸기
- [ ] 가스 제한 설정 (30000 가스 권장)
- [ ] 반환값 검증 (32바이트 bool)

---

## 자주 하는 실수

### ❌ 실수 1: 0xffffffff 처리 안함
```solidity
// 나쁨
function supportsInterface(bytes4 interfaceId) public view returns (bool) {
    return interfaceId == type(IERC165).interfaceId;
}
```

```solidity
// 좋음
function supportsInterface(bytes4 interfaceId) public view returns (bool) {
    if (interfaceId == 0xffffffff) return false;
    return interfaceId == type(IERC165).interfaceId;
}
```

### ❌ 실수 2: super 호출 빠뜨림
```solidity
// 나쁨 - Parent의 인터페이스를 무시함
contract Child is Parent, INew {
    function supportsInterface(bytes4 interfaceId)
        public view override returns (bool) {
        return interfaceId == type(INew).interfaceId;
    }
}
```

```solidity
// 좋음
contract Child is Parent, INew {
    function supportsInterface(bytes4 interfaceId)
        public view override returns (bool) {
        return interfaceId == type(INew).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}
```

### ❌ 실수 3: try-catch 없이 외부 호출
```solidity
// 나쁨 - revert 위험
function unsafeCheck(address target) public view returns (bool) {
    return IERC165(target).supportsInterface(type(IERC721).interfaceId);
}
```

```solidity
// 좋음
function safeCheck(address target) public view returns (bool) {
    try IERC165(target).supportsInterface(type(IERC721).interfaceId)
        returns (bool supported) {
        return supported;
    } catch {
        return false;
    }
}
```

### ❌ 실수 4: ERC20을 EIP-165로 확인
```solidity
// 나쁨 - ERC20은 EIP-165를 지원하지 않음
function isERC20(address token) public view returns (bool) {
    return IERC165(token).supportsInterface(type(IERC20).interfaceId);
}
```

```solidity
// 좋음
function isERC20(address token) public view returns (bool) {
    try IERC20(token).totalSupply() returns (uint256) {
        return true;
    } catch {
        return false;
    }
}
```

---

## 패턴별 가스 비용

| 패턴 | 읽기 (view) | 쓰기 (등록) | 사용 케이스 |
|-----|------------|------------|------------|
| 직접 비교 | ~500 gas | - | 단순한 컨트랙트 |
| Mapping | ~2,300 gas | ~20,000 gas | 복잡한 상속, 동적 관리 |
| Bitmap | ~800 gas | ~5,000 gas | 가스 최적화 필요 시 |

---

## 빠른 디버깅

### Interface ID 확인
```solidity
// Remix 또는 Hardhat에서
console.log("IERC165:", uint32(type(IERC165).interfaceId));
console.log("IERC721:", uint32(type(IERC721).interfaceId));
```

### 수동 계산 검증
```solidity
contract Debug {
    function getERC165ID() external pure returns (bytes4) {
        return type(IERC165).interfaceId; // 0x01ffc9a7
    }

    function calculateManually() external pure returns (bytes4) {
        return bytes4(keccak256("supportsInterface(bytes4)")); // 0x01ffc9a7
    }

    function compare() external pure returns (bool) {
        return type(IERC165).interfaceId ==
               bytes4(keccak256("supportsInterface(bytes4)"));
    }
}
```

### 호출 실패 진단
```solidity
function diagnose(address target, bytes4 interfaceId)
    external view returns (
        bool callSuccess,
        bool hasReturnData,
        bool returnValue,
        bytes memory rawData
    )
{
    (callSuccess, rawData) = target.staticcall(
        abi.encodeWithSelector(
            IERC165.supportsInterface.selector,
            interfaceId
        )
    );

    hasReturnData = rawData.length == 32;

    if (hasReturnData) {
        returnValue = abi.decode(rawData, (bool));
    }
}
```

---

## 실전 코드 템플릿

### NFT 컨트랙트
```solidity
contract MyNFT is ERC721, IERC165 {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IERC721).interfaceId ||
               interfaceId == type(IERC721Metadata).interfaceId;
    }
}
```

### 마켓플레이스
```solidity
contract Marketplace {
    function listNFT(address nft, uint256 tokenId) external {
        require(_isERC721(nft), "Not ERC721");
        // ... 리스팅 로직
    }

    function _isERC721(address account) private view returns (bool) {
        try IERC165(account).supportsInterface(type(IERC721).interfaceId)
            returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }
}
```

### 범용 토큰 핸들러
```solidity
contract TokenHandler {
    function handle(address token) external {
        if (_isERC721(token)) {
            handleNFT(token);
        } else if (_isERC1155(token)) {
            handleMulti(token);
        } else {
            revert("Unsupported");
        }
    }
}
```

---

## 테스트 코드 (Foundry)

```solidity
contract ERC165Test is Test {
    MyContract c;

    function setUp() public {
        c = new MyContract();
    }

    function testSupportsERC165() public {
        assertTrue(c.supportsInterface(type(IERC165).interfaceId));
    }

    function testSupportsMyInterface() public {
        assertTrue(c.supportsInterface(type(IMyInterface).interfaceId));
    }

    function testDoesNotSupportInvalid() public {
        assertFalse(c.supportsInterface(0xffffffff));
        assertFalse(c.supportsInterface(0x12345678));
    }

    function testInterfaceIdCalculation() public {
        bytes4 expected = type(IMyInterface).interfaceId;
        bytes4 actual = _calculateInterfaceId();
        assertEq(expected, actual);
    }

    function _calculateInterfaceId() internal pure returns (bytes4) {
        return bytes4(keccak256("myFunction()")) ^
               bytes4(keccak256("anotherFunction(uint256)"));
    }
}
```

---

## 참고 링크

- [README.md](./README.md) - 전체 가이드
- [EIP165Example.sol](./contracts/EIP165Example.sol) - 기본 예제
- [RealWorldExample.sol](./contracts/RealWorldExample.sol) - 실전 예제
- [EIP-165 명세](https://eips.ethereum.org/EIPS/eip-165)

---

## 한 줄 요약

**EIP-165는 컨트랙트의 "기능 명세서"를 표준화된 방식으로 제공하는 인터페이스입니다.**
