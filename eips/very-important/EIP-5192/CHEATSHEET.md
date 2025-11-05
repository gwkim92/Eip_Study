# EIP-5192 Cheat Sheet

> **빠른 참조 가이드** - EIP-5192 Minimal Soulbound NFTs

## 📋 기본 정보

```solidity
// 표준 이름: EIP-5192 Minimal Soulbound NFTs
// 목적: 양도 불가능한 NFT (Soulbound Token) 표준
// 상태: Final
// 제안일: 2022년 6월
```

## 🎯 핵심 개념 (5초 요약)

```
┌─────────────────────────────────────────┐
│  Soulbound Token (SBT)                  │
├─────────────────────────────────────────┤
│  특정 주소에 영구히 묶인 NFT             │
│  전송 불가 = 신원/자격/명성 증명         │
│  locked() = true → 양도 불가             │
└─────────────────────────────────────────┘
```

## 📝 필수 인터페이스

```solidity
interface IERC5192 {
    /// @notice 토큰이 잠겼을 때 발생
    event Locked(uint256 tokenId);

    /// @notice 토큰이 잠금 해제되었을 때 발생
    event Unlocked(uint256 tokenId);

    /// @notice 토큰의 잠금 상태 조회
    /// @param tokenId 확인할 토큰 ID
    /// @return 잠겨있으면 true
    function locked(uint256 tokenId) external view returns (bool);
}
```

## 🔑 Interface ID

```solidity
// EIP-5192 Interface ID
bytes4 constant ERC5192_INTERFACE_ID = 0xb45a3c0e;

// 계산 방법
bytes4 interfaceId = bytes4(keccak256("locked(uint256)"));
```

## 🏗️ 구현 패턴

### 패턴 1: Pure Soulbound (가장 일반적)

```solidity
contract PureSoulbound is ERC721, IERC5192 {
    /// @dev 항상 잠김
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Not exist");
        return true;  // 항상 true
    }

    /// @dev 전송 차단
    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address)
    {
        address from = _ownerOf(tokenId);

        // mint (from == 0x0) 허용
        // burn (to == 0x0) 허용
        // transfer (from != 0 && to != 0) 차단
        require(
            from == address(0) || to == address(0),
            "Non-transferable"
        );

        return super._update(to, tokenId, auth);
    }
}
```

### 패턴 2: Conditional Soulbound

```solidity
contract ConditionalSoulbound is ERC721, IERC5192 {
    mapping(uint256 => bool) private _locked;

    function locked(uint256 tokenId) external view returns (bool) {
        return _locked[tokenId];
    }

    function setLocked(uint256 tokenId, bool locked_) external {
        _locked[tokenId] = locked_;

        if (locked_) {
            emit Locked(tokenId);
        } else {
            emit Unlocked(tokenId);
        }
    }

    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address)
    {
        address from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            require(!_locked[tokenId], "Locked");
        }

        return super._update(to, tokenId, auth);
    }
}
```

### 패턴 3: Time-based Soulbound

```solidity
contract TimeLockSoulbound is ERC721, IERC5192 {
    mapping(uint256 => uint256) public unlockTime;

    function locked(uint256 tokenId) external view returns (bool) {
        return block.timestamp < unlockTime[tokenId];
    }

    function mint(address to, uint256 lockDuration) external {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        unlockTime[tokenId] = block.timestamp + lockDuration;
        emit Locked(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address)
    {
        address from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            require(
                block.timestamp >= unlockTime[tokenId],
                "Still locked"
            );
            emit Unlocked(tokenId);
        }

        return super._update(to, tokenId, auth);
    }
}
```

## 💻 코드 템플릿

### 기본 SBT 구조

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MySoulbound is ERC721, IERC5192 {
    uint256 private _nextTokenId;

    constructor() ERC721("My SBT", "SBT") {}

    function supportsInterface(bytes4 interfaceId)
        public view override returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId ||
               super.supportsInterface(interfaceId);
    }

    function locked(uint256 tokenId)
        external view returns (bool)
    {
        require(_ownerOf(tokenId) != address(0), "Not exist");
        return true;
    }

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        emit Locked(tokenId);
        return tokenId;
    }

    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address)
    {
        address from = _ownerOf(tokenId);
        require(
            from == address(0) || to == address(0),
            "Soulbound: Non-transferable"
        );
        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override {
        revert("Soulbound: Approval not allowed");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Soulbound: Approval not allowed");
    }
}
```

### Burn 허용 (개인정보 보호)

```solidity
function burn(uint256 tokenId) external {
    require(_ownerOf(tokenId) == msg.sender, "Not owner");
    _burn(tokenId);
    // ✅ Soulbound여도 burn은 허용
}
```

### Revoke 기능 (발급 기관)

```solidity
contract RevocableSBT is ERC721, IERC5192 {
    mapping(uint256 => bool) public revoked;
    address public issuer;

    function locked(uint256 tokenId) external view returns (bool) {
        return !revoked[tokenId];
    }

    function revoke(uint256 tokenId) external {
        require(msg.sender == issuer, "Not issuer");
        revoked[tokenId] = true;
        emit Unlocked(tokenId);
    }
}
```

## 📊 실전 패턴

### 패턴 1: 학위 증명서

```solidity
contract DegreeSBT is ERC721, IERC5192 {
    struct Degree {
        string university;
        string major;
        uint256 year;
    }

    mapping(uint256 => Degree) public degrees;

    function locked(uint256) external pure returns (bool) {
        return true;  // 학위는 영구 Soulbound
    }

    function issueDegree(
        address graduate,
        string memory university,
        string memory major,
        uint256 year
    ) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(graduate, tokenId);

        degrees[tokenId] = Degree(university, major, year);
        emit Locked(tokenId);

        return tokenId;
    }
}
```

### 패턴 2: POAP (출석 증명)

```solidity
contract POAPToken is ERC721, IERC5192 {
    struct Event {
        string name;
        uint256 date;
        string location;
    }

    mapping(uint256 => Event) public events;

    function locked(uint256) external pure returns (bool) {
        return true;
    }

    function mintPOAP(
        address attendee,
        string memory eventName,
        string memory location
    ) external returns (uint256) {
        uint256 tokenId = uint256(keccak256(
            abi.encodePacked(attendee, eventName, block.timestamp)
        ));

        _mint(attendee, tokenId);
        events[tokenId] = Event(eventName, block.timestamp, location);
        emit Locked(tokenId);

        return tokenId;
    }
}
```

### 패턴 3: 평판 시스템

```solidity
contract ReputationSBT is ERC721, IERC5192 {
    mapping(uint256 => uint256) public scores;
    mapping(address => uint256) public userTokenId;

    function locked(uint256) external pure returns (bool) {
        return true;
    }

    function createReputation() external returns (uint256) {
        require(userTokenId[msg.sender] == 0, "Already exists");

        uint256 tokenId = uint256(uint160(msg.sender));
        _mint(msg.sender, tokenId);

        scores[tokenId] = 0;
        userTokenId[msg.sender] = tokenId;

        emit Locked(tokenId);
        return tokenId;
    }

    function addScore(address user, uint256 points) external {
        uint256 tokenId = userTokenId[user];
        require(tokenId != 0, "No reputation");

        scores[tokenId] += points;
    }
}
```

### 패턴 4: 멤버십

```solidity
contract MembershipSBT is ERC721, IERC5192 {
    mapping(uint256 => uint256) public expiresAt;

    /// @dev 만료 전까지만 잠김
    function locked(uint256 tokenId) external view returns (bool) {
        return block.timestamp < expiresAt[tokenId];
    }

    function issueMembership(
        address member,
        uint256 duration
    ) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(member, tokenId);

        expiresAt[tokenId] = block.timestamp + duration;
        emit Locked(tokenId);

        return tokenId;
    }

    function isMember(address account) external view returns (bool) {
        uint256 tokenId = userTokenId[account];
        return tokenId != 0 && block.timestamp < expiresAt[tokenId];
    }
}
```

## ⚠️ 보안 체크리스트

```solidity
□ locked() 구현
  ✅ 존재하지 않는 토큰 처리
  ✅ 올바른 잠금 로직

□ _update() 오버라이드
  ✅ mint (from == 0x0) 허용
  ✅ burn (to == 0x0) 허용
  ✅ transfer 차단 (locked일 때)

□ approve 차단
  ✅ approve() revert
  ✅ setApprovalForAll() revert

□ burn 허용 (선택사항)
  ✅ 소유자만 burn 가능
  ✅ "잊혀질 권리" 보장

□ ERC-165 지원
  ✅ supportsInterface 구현
  ✅ ERC5192 interfaceId 반환
```

## 🔍 일반적인 실수

### 실수 1: _update에서 잠금 확인 안 함

```solidity
// ❌ 나쁜 예
function _update(address to, uint256 tokenId, address auth)
    internal override returns (address)
{
    // 잠금 확인 없음!
    return super._update(to, tokenId, auth);
}

// ✅ 좋은 예
function _update(address to, uint256 tokenId, address auth)
    internal override returns (address)
{
    address from = _ownerOf(tokenId);

    if (from != address(0) && to != address(0)) {
        require(!_locked[tokenId], "Locked");
    }

    return super._update(to, tokenId, auth);
}
```

### 실수 2: burn 차단

```solidity
// ❌ 나쁜 예: burn도 차단
function _update(address to, uint256 tokenId, address auth)
    internal override returns (address)
{
    address from = _ownerOf(tokenId);
    require(from == address(0), "Cannot transfer or burn");
    return super._update(to, tokenId, auth);
}

// ✅ 좋은 예: burn은 허용
function _update(address to, uint256 tokenId, address auth)
    internal override returns (address)
{
    address from = _ownerOf(tokenId);

    // burn (to == 0x0)은 허용
    if (to != address(0)) {
        require(from == address(0), "Non-transferable");
    }

    return super._update(to, tokenId, auth);
}
```

### 실수 3: locked() 호출 시 존재 확인 안 함

```solidity
// ❌ 나쁜 예
function locked(uint256 tokenId) external view returns (bool) {
    return _locked[tokenId];  // 존재하지 않는 토큰도 false 반환
}

// ✅ 좋은 예
function locked(uint256 tokenId) external view returns (bool) {
    require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
    return _locked[tokenId];
}
```

## 🌐 ethers.js 통합

### 기본 사용

```javascript
const SBT_ABI = [
    "function mint(address to) returns (uint256)",
    "function locked(uint256 tokenId) view returns (bool)",
    "function balanceOf(address owner) view returns (uint256)",
    "function ownerOf(uint256 tokenId) view returns (address)",
    "event Locked(uint256 tokenId)"
];

const sbt = new ethers.Contract(SBT_ADDRESS, SBT_ABI, signer);

// SBT 발행
const tx = await sbt.mint(userAddress);
const receipt = await tx.wait();

// 잠금 상태 확인
const isLocked = await sbt.locked(tokenId);
console.log(`Locked: ${isLocked}`);  // true

// 전송 시도 (실패)
try {
    await sbt.transferFrom(alice, bob, tokenId);
} catch (error) {
    console.log("Cannot transfer SBT");  // ✅ 예상된 동작
}
```

### 이벤트 리스닝

```javascript
// Locked 이벤트 감지
sbt.on("Locked", (tokenId) => {
    console.log(`Token ${tokenId} is now soulbound`);
});

// Unlocked 이벤트 감지 (조건부 SBT)
sbt.on("Unlocked", (tokenId) => {
    console.log(`Token ${tokenId} is now transferable`);
});
```

## 🎓 사용 사례

```
✅ 대학 학위
✅ 자격증 (의사, 변호사, 엔지니어)
✅ 출석 증명 (POAP)
✅ 평판/신용 점수
✅ 멤버십
✅ KYC 인증
✅ 업적 배지
✅ 근무 경력
✅ GitHub 기여 증명
✅ DAO 참여 이력
```

## 📈 패턴 비교

```
┌──────────────────────────────────────────────────┐
│ Pattern          │ locked() │ Use Case           │
├──────────────────────────────────────────────────┤
│ Pure             │ always   │ 학위, 자격증        │
│ Conditional      │ variable │ 테스트, 임시        │
│ Time-based       │ until X  │ 베스팅, 기간제      │
│ Achievement      │ until Y  │ 게임, 레벨업        │
└──────────────────────────────────────────────────┘
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 설명
- [EIP5192Example.sol](./contracts/EIP5192Example.sol) - 구현 예제
- [EIP-5192 Spec](https://eips.ethereum.org/EIPS/eip-5192) - 공식 문서

## 💡 핵심 요약

```
┌─────────────────────────────────────────┐
│  EIP-5192 = 양도 불가능한 NFT            │
├─────────────────────────────────────────┤
│  1. locked() 함수 하나만 추가            │
│  2. ERC-721 확장 (호환성 유지)           │
│  3. 신원/자격/명성 온체인 증명           │
│  4. Sybil 공격 방어                     │
│  5. 전송 차단, burn 허용                │
└─────────────────────────────────────────┘

핵심: "영혼에 묶인" 토큰
목적: 신뢰할 수 있는 Web3 신원 시스템
```

## 🎯 구현 순서

```
1. ERC-721 상속
   ├─ constructor에서 name, symbol 설정

2. IERC5192 구현
   ├─ locked() 함수
   ├─ Locked/Unlocked 이벤트
   └─ supportsInterface

3. _update 오버라이드
   ├─ from == 0x0 → mint 허용
   ├─ to == 0x0 → burn 허용
   └─ 그 외 → 잠금 확인 후 차단

4. approve 차단
   ├─ approve() → revert
   └─ setApprovalForAll() → revert

5. 테스트
   ├─ mint 성공
   ├─ transfer 실패
   ├─ burn 성공 (선택)
   └─ locked() 반환값 확인
```

---

**마지막 업데이트: 2024**
**작성자: EIP Study Group**
