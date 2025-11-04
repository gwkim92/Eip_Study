# EIP-165: Standard Interface Detection

> **한 줄 요약**: 스마트 컨트랙트가 "나 이 기능 지원해!" 라고 알려주는 표준 방법

📌 **[치트시트 보기](./CHEATSHEET.md)** - 빠른 참고용 코드 모음

## 핵심만 빠르게

```solidity
// ❌ 위험: 확인 없이 호출
IERC721(unknownContract).ownerOf(1); // revert 될 수 있음

// ✅ 안전: 먼저 확인
if (IERC165(unknownContract).supportsInterface(type(IERC721).interfaceId)) {
    IERC721(unknownContract).ownerOf(1); // 안전!
}
```

### 3줄 요약
1. **문제**: 컨트랙트가 어떤 기능을 지원하는지 모르면 호출 시 에러 발생
2. **해결**: `supportsInterface()` 함수로 미리 확인
3. **효과**: 안전한 컨트랙트 통신 + 다양한 토큰 타입 자동 처리

### 실무에서 언제 쓰나?
- ✅ NFT 마켓플레이스 (ERC721 확인)
- ✅ 멀티 토큰 지갑 (ERC721/ERC1155 구분)
- ✅ DeFi 프로토콜 (토큰 타입별 처리)
- ✅ DAO 거버넌스 (제안 타입 확인)

---

## 목차
1. [EIP-165가 왜 필요한가?](#왜-필요한가)
2. [핵심 개념](#핵심-개념)
3. [Interface ID 계산 방법](#interface-id-계산-방법)
4. [실전 구현 패턴](#실전-구현-패턴)
5. [실무 활용 예제](#실무-활용-예제)
6. [주의사항과 베스트 프랙티스](#주의사항)

---

## 왜 필요한가?

### 문제 상황
스마트 컨트랙트를 호출하기 전에 **"이 컨트랙트가 내가 원하는 기능을 지원하는가?"**를 알아야 합니다.

```solidity
// 나쁜 예: 확인 없이 호출하면 revert 발생
function dangerousCall(address target) public {
    IERC721(target).ownerOf(1); // target이 ERC721이 아니면? 💥
}
```

### EIP-165의 해결책
표준화된 방식으로 컨트랙트에게 "너 이 기능 있어?" 라고 물어볼 수 있습니다.

```solidity
// 좋은 예: 안전하게 확인 후 호출
function safeCall(address target) public {
    if (IERC165(target).supportsInterface(type(IERC721).interfaceId)) {
        IERC721(target).ownerOf(1); // ✅ 안전
    } else {
        revert("Not an ERC721 contract");
    }
}
```

---

## 동작 원리 (한눈에 보기)

```
┌─────────────────────────────────────────────────────────────┐
│                    컨트랙트 A (호출자)                        │
│                                                               │
│  "이 컨트랙트가 ERC721을 지원하는지 확인하고 싶어!"           │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ supportsInterface(0x80ac58cd) 호출
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    컨트랙트 B (대상)                          │
│                                                               │
│  function supportsInterface(bytes4 interfaceId)              │
│      returns (bool)                                          │
│  {                                                            │
│      if (interfaceId == 0x80ac58cd) return true; ✅          │
│      if (interfaceId == 0x01ffc9a7) return true; ✅          │
│      return false;                                           │
│  }                                                            │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ true 반환
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    컨트랙트 A (호출자)                        │
│                                                               │
│  IERC721(B).transferFrom(...) // 안전하게 호출 가능!         │
└─────────────────────────────────────────────────────────────┘
```

### Interface ID 계산 과정

```
인터페이스 정의:
┌──────────────────────────────────────────┐
│ interface IERC721 {                      │
│   function balanceOf(address)            │
│   function ownerOf(uint256)              │
│   function transferFrom(address,...)     │
│   ...                                    │
│ }                                        │
└──────────────────────────────────────────┘
              │
              ▼
각 함수의 Selector 계산:
┌──────────────────────────────────────────┐
│ balanceOf.selector    = 0x70a08231       │
│ ownerOf.selector      = 0x6352211e       │
│ transferFrom.selector = 0x23b872dd       │
│ ...                                      │
└──────────────────────────────────────────┘
              │
              ▼
모두 XOR 연산:
┌──────────────────────────────────────────┐
│ 0x70a08231 ^ 0x6352211e ^ 0x23b872dd ... │
│                                          │
│ = 0x80ac58cd  ← Interface ID             │
└──────────────────────────────────────────┘
```

---

## 핵심 개념

### 1. IERC165 인터페이스
모든 EIP-165 호환 컨트랙트는 이 인터페이스를 구현해야 합니다:

```solidity
interface IERC165 {
    /// @notice 이 컨트랙트가 특정 인터페이스를 구현하는지 확인
    /// @param interfaceId 확인하려는 인터페이스의 ID (bytes4)
    /// @return bool 구현하면 true, 아니면 false
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
```

### 2. Interface ID란?
**인터페이스의 모든 함수 선택자(selector)를 XOR 연산한 결과값**

```solidity
// 예: IAnimal 인터페이스
interface IAnimal {
    function eat() external;      // selector: 0x???
    function sleep() external;    // selector: 0x???
}

// Interface ID = eat.selector XOR sleep.selector
bytes4 interfaceId = type(IAnimal).interfaceId;
```

---

## Interface ID 계산 방법

### 자동 계산 (권장)
```solidity
// Solidity 컴파일러가 자동으로 계산
bytes4 id = type(IERC721).interfaceId;
```

### 수동 계산 (이해를 위해)

#### Step 1: 각 함수의 selector 계산
```solidity
// 함수 시그니처 해시의 첫 4바이트
bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));
```

#### Step 2: 모든 selector를 XOR
```solidity
interface IExample {
    function foo() external;
    function bar(uint256) external;
}

// 계산 과정:
bytes4 selector1 = bytes4(keccak256("foo()"));           // 0xc2985578
bytes4 selector2 = bytes4(keccak256("bar(uint256)"));    // 0x0423a132
bytes4 interfaceId = selector1 ^ selector2;              // 0xc4ba4f4a
```

### 실전 계산 예제
[InterfaceIdCalculator](./contracts/EIP165Example.sol#L333-L387) 컨트랙트를 참고하세요:

```solidity
// 1. 함수 시그니처로 selector 계산
bytes4 sel = calculateSelector("transfer(address,uint256)");

// 2. 여러 selector를 XOR하여 interface ID 계산
bytes4[] memory selectors = new bytes4[](2);
selectors[0] = sel1;
selectors[1] = sel2;
bytes4 interfaceId = calculateInterfaceId(selectors);
```

---

## 실전 구현 패턴

### 패턴 1: 기본 구현 (단순한 컨트랙트)

```solidity
contract SimpleERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId;
    }
}
```

**언제 사용?** 상속이 단순하고 인터페이스가 고정적일 때

참고: [BasicERC165](./contracts/EIP165Example.sol#L26-L48)

### 패턴 2: 다중 인터페이스 지원

```solidity
contract MultiInterface is IERC165, IERC721, IERC721Metadata {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IERC721).interfaceId ||
               interfaceId == type(IERC721Metadata).interfaceId;
    }
}
```

**언제 사용?** 여러 표준을 구현하는 컨트랙트 (NFT, 토큰 등)

참고: [ERC165WithCustomInterface](./contracts/EIP165Example.sol#L63-L103)

### 패턴 3: Mapping 기반 (동적 관리)

```solidity
contract FlexibleERC165 is IERC165 {
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor() {
        _registerInterface(type(IERC165).interfaceId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override returns (bool)
    {
        return _supportedInterfaces[interfaceId];
    }

    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff, "Invalid interface");
        _supportedInterfaces[interfaceId] = true;
    }
}
```

**언제 사용?**
- 복잡한 상속 구조
- 런타임에 인터페이스 추가/제거가 필요할 때
- 업그레이드 가능한 컨트랙트

참고: [MappingBasedERC165](./contracts/EIP165Example.sol#L110-L171)

---

## 실무 활용 예제

### 예제 1: NFT 마켓플레이스

```solidity
contract NFTMarketplace {
    // NFT가 맞는지 확인 후 거래
    function listNFT(address nftContract, uint256 tokenId) external {
        // 1. ERC165 지원 확인
        require(
            IERC165(nftContract).supportsInterface(type(IERC165).interfaceId),
            "Not ERC165 compatible"
        );

        // 2. ERC721 지원 확인
        require(
            IERC165(nftContract).supportsInterface(type(IERC721).interfaceId),
            "Not an ERC721 NFT"
        );

        // 3. 안전하게 NFT 처리
        address owner = IERC721(nftContract).ownerOf(tokenId);
        // ... 리스팅 로직
    }
}
```

### 예제 2: 범용 토큰 핸들러

```solidity
contract UniversalTokenHandler {
    function handleToken(address token) external {
        IERC165 target = IERC165(token);

        if (target.supportsInterface(type(IERC721).interfaceId)) {
            // NFT 처리 로직
            handleNFT(token);
        } else if (target.supportsInterface(type(IERC1155).interfaceId)) {
            // Multi-token 처리 로직
            handleMultiToken(token);
        } else if (target.supportsInterface(type(IERC20).interfaceId)) {
            // 주의: ERC20은 EIP-165를 표준으로 구현하지 않음
            handleERC20(token);
        } else {
            revert("Unsupported token type");
        }
    }
}
```

### 예제 3: 안전한 Batch 체크

```solidity
contract BatchInterfaceChecker {
    using ERC165Checker for address;

    // 여러 컨트랙트가 특정 인터페이스를 지원하는지 한번에 확인
    function batchCheck(address[] memory contracts, bytes4 interfaceId)
        external view returns (bool[] memory)
    {
        bool[] memory results = new bool[](contracts.length);

        for (uint i = 0; i < contracts.length; i++) {
            results[i] = contracts[i].supportsInterface(interfaceId);
        }

        return results;
    }

    // 하나의 컨트랙트가 여러 인터페이스를 모두 지원하는지 확인
    function supportsAll(address target, bytes4[] memory interfaceIds)
        external view returns (bool)
    {
        return target.supportsAllInterfaces(interfaceIds);
    }
}
```

참고: [ERC165Checker 라이브러리](./contracts/EIP165Example.sol#L230-L291)

---

## 주의사항

### ⚠️ 금지된 Interface ID
```solidity
// 0xffffffff는 무효한 ID로 정의됨 (항상 false 반환)
function supportsInterface(bytes4 interfaceId) public view returns (bool) {
    if (interfaceId == 0xffffffff) {
        return false; // 반드시!
    }
    // ... 나머지 로직
}
```

참고: [InvalidInterfaceChecker](./contracts/EIP165Example.sol#L203-L224)

### 🔒 가스 제한 고려
외부 컨트랙트 호출 시 가스 제한을 설정하세요:

```solidity
// 악의적인 컨트랙트가 무한 루프로 가스를 소진시킬 수 있음
(bool success, bytes memory result) = target.staticcall{gas: 30000}(
    abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId)
);
```

### ❌ ERC20은 EIP-165를 지원하지 않음
```solidity
// ERC20은 EIP-165 이전에 만들어져서 지원하지 않음
// 따라서 ERC20 확인은 다른 방법 사용
function isERC20(address token) public view returns (bool) {
    // try-catch 사용
    try IERC20(token).totalSupply() returns (uint256) {
        return true;
    } catch {
        return false;
    }
}
```

### 🎯 상속 시 주의사항
```solidity
contract Parent is IERC165 {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

contract Child is Parent, ICustomInterface {
    // Parent의 supportsInterface를 override하여 확장
    function supportsInterface(bytes4 interfaceId)
        public view override returns (bool) {
        return interfaceId == type(ICustomInterface).interfaceId ||
               super.supportsInterface(interfaceId); // ✅ super 호출!
    }
}
```

---

## 테스트 방법

### Foundry로 테스트하기

```bash
# Interface ID 확인
forge test --match-test testInterfaceId -vv

# 여러 인터페이스 지원 확인
forge test --match-test testMultipleInterfaces -vv
```

### Hardhat으로 테스트하기

```javascript
const interfaceId = ethers.utils.hexDataSlice(
  ethers.utils.keccak256(ethers.utils.toUtf8Bytes("transfer(address,uint256)")),
  0, 4
);

expect(await contract.supportsInterface(interfaceId)).to.be.true;
```

---

## 실전 체크리스트

EIP-165를 구현할 때 확인하세요:

- [ ] `supportsInterface` 함수 구현
- [ ] `type(IERC165).interfaceId` 반환 (0x01ffc9a7)
- [ ] 모든 구현 인터페이스의 ID 반환
- [ ] `0xffffffff`는 false 반환
- [ ] 상속 구조에서 `super.supportsInterface()` 호출
- [ ] 가스 제한 설정 (외부 호출 시)
- [ ] 테스트 코드 작성

---

## 추가 자료

- [EIP-165 공식 명세](https://eips.ethereum.org/EIPS/eip-165)
- [OpenZeppelin ERC165 구현](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/introspection/ERC165.sol)
- [Solidity by Example - ERC165](https://solidity-by-example.org/app/erc165/)

## 코드 예제

### 기본 예제
- [EIP165Example.sol](./contracts/EIP165Example.sol) - 전체 구현 예제 모음
  - [BasicERC165](./contracts/EIP165Example.sol#L26-L48) - 가장 기본적인 구현
  - [ERC165WithCustomInterface](./contracts/EIP165Example.sol#L63-L103) - 커스텀 인터페이스 추가
  - [MappingBasedERC165](./contracts/EIP165Example.sol#L110-L171) - 동적 관리 패턴
  - [InterfaceIdCalculator](./contracts/EIP165Example.sol#L333-L387) - ID 계산 도구
  - [ERC165Checker](./contracts/EIP165Example.sol#L230-L291) - 유틸리티 라이브러리

### 실전 예제
- [RealWorldExample.sol](./contracts/RealWorldExample.sol) - 실무 활용 예제
  - [SimpleNFT](./contracts/RealWorldExample.sol#L51-L126) - EIP-165 지원 NFT 구현
  - [NFTMarketplace](./contracts/RealWorldExample.sol#L138-L265) - 안전한 NFT 마켓플레이스
  - [UniversalTokenVault](./contracts/RealWorldExample.sol#L282-L405) - 다중 토큰 타입 지원 금고
  - [UsageExample](./contracts/RealWorldExample.sol#L413-L449) - 사용 시나리오

---

## 학습 로드맵

```
초급 (30분) → 중급 (1시간) → 고급 (2시간) → 실전 (프로젝트 적용)
```

### 🟢 초급: 개념 이해 (30분)
1. [왜 필요한가?](#왜-필요한가) 읽기 (5분)
2. [동작 원리 다이어그램](#동작-원리-한눈에-보기) 보기 (5분)
3. [BasicERC165](./contracts/EIP165Example.sol#L26-L48) 코드 읽기 (10분)
4. Interface ID가 `0x01ffc9a7`인 이유 이해 (10분)

### 🟡 중급: 실습 (1시간)
1. [InterfaceIdCalculator](./contracts/EIP165Example.sol#L333-L387) 배포 (15분)
2. 직접 Interface ID 계산해보기 (15분)
3. [SimpleNFT](./contracts/RealWorldExample.sol#L51-L126) 코드 분석 (15분)
4. `supportsInterface` 직접 구현해보기 (15분)

### 🔴 고급: 복잡한 패턴 (2시간)
1. [Mapping 기반 패턴](./contracts/EIP165Example.sol#L110-L171) 이해 (30분)
2. [NFTMarketplace](./contracts/RealWorldExample.sol#L138-L265) 코드 분석 (30분)
3. [ERC165Checker 라이브러리](./contracts/EIP165Example.sol#L230-L291) 활용 (30분)
4. 보안 고려사항 학습 (30분)

### 🚀 실전: 프로젝트 적용
- [ ] 자신의 컨트랙트에 EIP-165 추가
- [ ] 테스트 코드 작성
- [ ] 가스 최적화
- [ ] 보안 체크리스트 확인

---

## 빠른 시작 가이드

### 1단계: 기본 개념 이해
먼저 [왜 필요한가?](#왜-필요한가) 섹션을 읽고 문제 상황을 이해하세요.

### 2단계: Interface ID 계산 실습
[InterfaceIdCalculator](./contracts/EIP165Example.sol#L333-L387)를 배포하고 직접 계산해보세요:

```solidity
// 1. 함수 시그니처로 selector 계산
bytes4 sel = calculator.calculateSelector("transfer(address,uint256)");

// 2. 여러 selector XOR 계산
bytes4[] memory selectors = new bytes4[](2);
selectors[0] = 0x12345678;
selectors[1] = 0x87654321;
bytes4 interfaceId = calculator.calculateInterfaceId(selectors);
```

### 3단계: 실전 예제 실행
[RealWorldExample.sol](./contracts/RealWorldExample.sol)을 배포하고 NFT 거래 시나리오를 따라해보세요:

```solidity
// NFT 발행
uint256 tokenId = nft.mint(msg.sender, "ipfs://metadata");

// 마켓에 리스팅 (EIP-165 검증 자동 수행)
nft.approve(address(marketplace), tokenId);
marketplace.listNFT(address(nft), tokenId, 1 ether);

// 안전성 확인
bool isValid = marketplace.isValidNFT(address(nft)); // true
```

### 4단계: 직접 구현해보기
자신만의 컨트랙트에 EIP-165를 추가해보세요:

```solidity
contract MyContract is IERC165, IMyInterface {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IMyInterface).interfaceId;
    }
}
```

---

## 자주 묻는 질문 (FAQ)

### Q1: Interface ID는 어떻게 계산되나요?
인터페이스의 모든 함수 selector를 XOR 연산합니다.

```solidity
// 예: 두 함수가 있는 인터페이스
interface IExample {
    function foo() external;        // selector: 0xc2985578
    function bar(uint256) external; // selector: 0x0423a132
}

// Interface ID = 0xc2985578 XOR 0x0423a132 = 0xc4ba4f4a
```

참고: [Interface ID 계산 방법](#interface-id-계산-방법)

### Q2: 왜 0xffffffff는 무효한가요?
EIP-165 명세에서 무효한 인터페이스 ID로 정의했습니다. 모든 구현은 이 값에 대해 `false`를 반환해야 합니다.

```solidity
function supportsInterface(bytes4 interfaceId) public view returns (bool) {
    if (interfaceId == 0xffffffff) return false; // 필수!
    // ... 나머지 로직
}
```

### Q3: ERC20은 왜 EIP-165를 지원하지 않나요?
ERC20 표준이 EIP-165보다 먼저 만들어졌기 때문입니다. ERC721, ERC1155 같은 최신 표준들은 EIP-165를 지원합니다.

### Q4: 상속이 복잡할 때는 어떻게 하나요?
Mapping 기반 패턴을 사용하세요:

```solidity
contract ComplexContract is MappingBasedERC165 {
    constructor() {
        _registerInterface(type(IERC165).interfaceId);
        _registerInterface(type(IMyInterface1).interfaceId);
        _registerInterface(type(IMyInterface2).interfaceId);
    }
}
```

참고: [MappingBasedERC165](./contracts/EIP165Example.sol#L110-L171)

### Q5: try-catch를 사용하는 이유는?
외부 컨트랙트가 악의적이거나 잘못 구현되었을 수 있어서, 안전하게 호출하기 위함입니다.

```solidity
function _supportsERC165(address account) private view returns (bool) {
    try IERC165(account).supportsInterface(type(IERC165).interfaceId)
        returns (bool supported) {
        return supported;
    } catch {
        return false; // 호출 실패 시 안전하게 처리
    }
}
```

### Q6: 가스 비용은 얼마나 드나요?
`supportsInterface()` 호출은 매우 저렴합니다 (view 함수):
- 기본 구현: ~500 gas
- Mapping 기반: ~2,300 gas

### Q7: 업그레이드 가능한 컨트랙트에서는?
Proxy 패턴과 함께 사용할 때, Implementation 컨트랙트에서 EIP-165를 구현하면 됩니다.

```solidity
contract MyImplementation is IERC165, Initializable {
    function supportsInterface(bytes4 interfaceId)
        public view override returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IMyFeature).interfaceId;
    }
}
```

---

## 디버깅 팁

### Interface ID가 다를 때
```solidity
// Solidity 버전에 따라 계산이 다를 수 있음
// 컴파일러 자동 계산을 신뢰하세요
bytes4 expected = type(IERC721).interfaceId;
bytes4 actual = calculateInterfaceId(selectors);

require(expected == actual, string(abi.encodePacked(
    "Mismatch: ", toHexString(expected), " vs ", toHexString(actual)
)));
```

### 호출이 실패할 때
```solidity
// 상세한 로깅으로 디버깅
function debugSupportsInterface(address target, bytes4 interfaceId)
    external view returns (bool supported, bool callSuccess, bytes memory returnData)
{
    (callSuccess, returnData) = target.staticcall(
        abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId)
    );

    if (callSuccess && returnData.length == 32) {
        supported = abi.decode(returnData, (bool));
    }
}
```

---

## 보안 체크리스트

EIP-165를 안전하게 사용하기 위한 체크리스트:

- [ ] **가스 제한**: 외부 호출 시 가스 제한 설정 (`{gas: 30000}`)
- [ ] **try-catch**: 외부 호출은 항상 try-catch로 감싸기
- [ ] **0xffffffff 체크**: 무효한 ID는 false 반환
- [ ] **반환값 검증**: staticcall 성공 + 32바이트 + bool 값 확인
- [ ] **재진입 방지**: 외부 호출 전 상태 업데이트
- [ ] **타입 캐스팅 검증**: 인터페이스 확인 후에만 캐스팅
- [ ] **테스트 커버리지**: 모든 인터페이스 조합 테스트

---

## 관련 EIP

- **EIP-721**: Non-Fungible Token (EIP-165 필수)
- **EIP-1155**: Multi-Token Standard (EIP-165 필수)
- **EIP-2981**: NFT Royalty Standard (EIP-165 권장)
- **EIP-4906**: Metadata Update Extension (EIP-165 필수)
