# EIP-5192: Minimal Soulbound NFTs (최소 Soulbound NFT)

> **"영혼에 묶인 토큰 - 양도 불가능한 신원과 명성의 디지털 표현"**

## 목차
- [개요](#개요)
- [Soulbound Token이란?](#soulbound-token이란)
- [EIP-5192가 해결하는 문제](#eip-5192가-해결하는-문제)
- [핵심 개념](#핵심-개념)
- [인터페이스 명세](#인터페이스-명세)
- [구현 패턴](#구현-패턴)
- [실전 예제](#실전-예제)
- [보안 고려사항](#보안-고려사항)
- [실제 사용 사례](#실제-사용-사례)
- [학습 로드맵](#학습-로드맵)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

---

## 개요

### EIP-5192란?

EIP-5192는 **Soulbound Token (SBT, 영혼 결속 토큰)**에 대한 최소 인터페이스를 정의합니다. Soulbound Token은 특정 주소에 영구적으로 묶여 있으며, **양도할 수 없는** NFT입니다.

**배경:**
- 2022년 5월, Vitalik Buterin이 ["Decentralized Society: Finding Web3's Soul"](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4105763) 논문 발표
- 학위, 자격증, 명성 등 개인의 정체성을 나타내는 토큰 제안
- 2022년 6월, EIP-5192 표준 제안

### 왜 중요한가?

```
기존 NFT (ERC-721):
┌─────────────────────────────────────────┐
│  Alice의 지갑                            │
├─────────────────────────────────────────┤
│  ┌─────────────┐                        │
│  │ 학위 NFT    │ → Bob에게 전송 가능     │
│  └─────────────┘   ❌ 학위를 팔 수 있음!│
└─────────────────────────────────────────┘

Soulbound Token (EIP-5192):
┌─────────────────────────────────────────┐
│  Alice의 지갑                            │
├─────────────────────────────────────────┤
│  ┌─────────────┐                        │
│  │ 학위 SBT    │ → 전송 불가!            │
│  └─────────────┘   ✅ 영구적으로 묶여있음│
└─────────────────────────────────────────┘
```

**주요 장점:**
1. **신원 증명**: 본인의 자격, 경력, 학력을 증명
2. **명성 시스템**: 온체인 평판 구축
3. **Sybil 공격 방어**: 여러 지갑을 만들어도 명성은 옮길 수 없음
4. **사회적 신뢰**: Web3에서의 신뢰 네트워크 구축

---

## Soulbound Token이란?

### 기원: World of Warcraft

"Soulbound"라는 용어는 게임 World of Warcraft에서 유래했습니다.

```
WoW의 Soulbound Item:
┌─────────────────────────────────────────┐
│  강력한 무기를 획득!                     │
├─────────────────────────────────────────┤
│  "이 아이템은 Soulbound입니다"          │
│  → 다른 플레이어에게 줄 수 없음          │
│  → 오직 획득한 캐릭터만 사용 가능        │
└─────────────────────────────────────────┘

개념의 확장:
- 게임 → 블록체인
- 아이템 → 토큰
- 캐릭터 → 지갑 주소
```

### 현실 세계의 Soulbound

실제로 우리 주변에는 이미 "Soulbound" 개념이 많습니다:

```
양도 불가능한 것들:
┌─────────────────────────────────────────┐
│ ✅ 대학 학위                             │
│ ✅ 운전 면허증                           │
│ ✅ 의사 자격증                           │
│ ✅ 여권                                  │
│ ✅ 출석 증명서                           │
│ ✅ 고용 계약서                           │
│ ✅ 범죄 기록 (불행히도...)               │
└─────────────────────────────────────────┘

이것들을 블록체인으로!
```

---

## EIP-5192가 해결하는 문제

### 문제 1: 학력 위조

**Before Soulbound:**
```
┌─────────────────────────────────────────┐
│  ❌ 문제점                              │
├─────────────────────────────────────────┤
│  1. Alice가 MIT 학위 NFT 획득           │
│  2. Alice가 Bob에게 NFT 판매            │
│  3. Bob이 MIT 졸업생인 척 사기           │
│                                         │
│  → NFT 양도 가능 = 신원 위조 가능!      │
└─────────────────────────────────────────┘
```

**After Soulbound:**
```
┌─────────────────────────────────────────┐
│  ✅ 해결책                              │
├─────────────────────────────────────────┤
│  1. Alice가 MIT 학위 SBT 획득           │
│  2. transferFrom() → revert!            │
│  3. SBT는 Alice 지갑에 영구 보관         │
│                                         │
│  → 양도 불가 = 신원 위조 불가!          │
└─────────────────────────────────────────┘
```

### 문제 2: Sybil 공격

**Before Soulbound:**
```
악의적인 사용자:
┌─────────────────────────────────────────┐
│  지갑 1: 평판 100점 획득                 │
│  지갑 2: 평판 0점 (새 지갑)              │
│                                         │
│  지갑 1 → 지갑 2로 평판 NFT 전송        │
│  지갑 1에서 다시 평판 쌓기               │
│                                         │
│  결과: 무한 평판 복제!                   │
└─────────────────────────────────────────┘
```

**After Soulbound:**
```
Sybil 공격 차단:
┌─────────────────────────────────────────┐
│  지갑 1: 평판 100점 SBT                 │
│  지갑 2: 평판 0점                        │
│                                         │
│  전송 시도 → revert!                    │
│                                         │
│  결과: 새 지갑 = 처음부터 다시 시작      │
└─────────────────────────────────────────┘
```

### 문제 3: 익명성과 신뢰의 균형

```
Web3의 딜레마:
┌─────────────────────────────────────────┐
│  완전 익명 (기존):                       │
│    Pro: 프라이버시                       │
│    Con: 신뢰 구축 불가                   │
│                                         │
│  완전 공개 (중앙화):                     │
│    Pro: 신뢰 가능                        │
│    Con: 프라이버시 침해                  │
│                                         │
│  Soulbound (균형):                      │
│    Pro: 선택적 신원 공개                 │
│    Pro: 검증 가능한 자격                 │
│    Pro: 익명성 유지 가능                 │
└─────────────────────────────────────────┘
```

---

## 핵심 개념

### 1. Locked 상태

EIP-5192의 핵심은 `locked()` 함수입니다.

```
Token State:
┌─────────────────────────────────────────┐
│  locked() = true                        │
│  → 토큰이 잠겨있음                       │
│  → 전송 불가                             │
│  → Soulbound!                           │
│                                         │
│  locked() = false                       │
│  → 토큰이 열려있음                       │
│  → 전송 가능                             │
│  → 일반 NFT처럼 동작                     │
└─────────────────────────────────────────┘
```

**3가지 구현 방식:**

```solidity
// 방식 1: 영구 잠금 (Pure Soulbound)
function locked(uint256 tokenId) external pure returns (bool) {
    return true;  // 항상 잠김
}

// 방식 2: 조건부 잠금 (Conditional)
function locked(uint256 tokenId) external view returns (bool) {
    return _locked[tokenId];  // 상태 변수 사용
}

// 방식 3: 시간 기반 잠금 (Time-based)
function locked(uint256 tokenId) external view returns (bool) {
    return block.timestamp < unlockTime[tokenId];
}
```

### 2. 생애주기

```
Soulbound Token의 생애주기:

     Mint           Lock          (Optionally) Unlock
      │              │                    │
      ▼              ▼                    ▼
┌──────────┐   ┌──────────┐        ┌──────────┐
│  탄생    │ → │ 잠금 상태│   →   │ 해제 가능│
│ (발행)   │   │(Transfer │        │(조건부) │
│          │   │ blocked) │        │          │
└──────────┘   └──────────┘        └──────────┘
      │                                  │
      └──────────────┬───────────────────┘
                     │
                     ▼
                ┌──────────┐
                │  소각    │
                │ (Burn)   │
                └──────────┘

주의: 대부분의 SBT는 영구 잠금!
```

### 3. 이벤트

```solidity
// 토큰이 잠길 때
event Locked(uint256 tokenId);

// 토큰이 잠금 해제될 때
event Unlocked(uint256 tokenId);
```

**이벤트 활용:**
```
┌─────────────────────────────────────────┐
│  사용 사례                               │
├─────────────────────────────────────────┤
│  1. UI에서 잠금 상태 표시                │
│  2. 잠금 해제 알림                       │
│  3. 감사(Audit) 목적                    │
│  4. 통계 수집                            │
└─────────────────────────────────────────┘
```

### 4. ERC-721과의 관계

```
EIP-5192는 ERC-721의 확장:

┌─────────────────────────────────────────┐
│  ERC-721 (기본 NFT)                     │
├─────────────────────────────────────────┤
│  - ownerOf()                            │
│  - balanceOf()                          │
│  - transferFrom() ✅ 가능               │
│  - approve() ✅ 가능                    │
└─────────────────────────────────────────┘
              ↓ 확장
┌─────────────────────────────────────────┐
│  EIP-5192 (Soulbound NFT)               │
├─────────────────────────────────────────┤
│  - ownerOf() ✅                         │
│  - balanceOf() ✅                       │
│  - transferFrom() ❌ revert            │
│  - approve() ❌ revert                 │
│  + locked() ✅ 새 함수!                 │
└─────────────────────────────────────────┘
```

---

## 인터페이스 명세

### 필수 인터페이스

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

interface IERC5192 {
    /// @notice 토큰이 잠겼을 때 발생
    event Locked(uint256 tokenId);

    /// @notice 토큰이 잠금 해제되었을 때 발생
    event Unlocked(uint256 tokenId);

    /// @notice 토큰의 잠금 상태 조회
    /// @param tokenId 확인할 토큰 ID
    /// @return 잠겨있으면 true, 아니면 false
    function locked(uint256 tokenId) external view returns (bool);
}
```

### 함수 상세

#### `locked(uint256 tokenId)`

```solidity
function locked(uint256 tokenId) external view returns (bool);
```

**목적:** 토큰이 잠겨있는지(양도 불가능한지) 확인

**매개변수:**
- `tokenId`: 확인할 토큰 ID

**반환값:**
- `true`: 토큰이 잠겨있음 (전송 불가)
- `false`: 토큰이 열려있음 (전송 가능)

**호출 예:**
```solidity
bool isLocked = sbt.locked(tokenId);

if (isLocked) {
    // 토큰은 Soulbound
    // transferFrom() 호출 시 revert됨
} else {
    // 토큰은 일반 NFT처럼 전송 가능
}
```

### 이벤트 상세

#### `Locked(uint256 tokenId)`

```solidity
event Locked(uint256 tokenId);
```

**발생 시점:**
- 토큰이 처음 발행되어 잠길 때
- 조건부 SBT에서 잠금 상태로 변경될 때

**사용 예:**
```solidity
function mint(address to) external returns (uint256) {
    uint256 tokenId = _nextTokenId++;
    _mint(to, tokenId);

    emit Locked(tokenId);  // 잠금 알림
    return tokenId;
}
```

#### `Unlocked(uint256 tokenId)`

```solidity
event Unlocked(uint256 tokenId);
```

**발생 시점:**
- 조건부 SBT에서 잠금이 해제될 때
- 시간 기반 잠금이 만료될 때

**사용 예:**
```solidity
function unlock(uint256 tokenId) external onlyAdmin {
    _locked[tokenId] = false;
    emit Unlocked(tokenId);
}
```

### ERC-165 통합

```solidity
function supportsInterface(bytes4 interfaceId)
    public
    view
    override
    returns (bool)
{
    return interfaceId == type(IERC5192).interfaceId ||
           interfaceId == type(IERC721).interfaceId ||
           interfaceId == type(IERC165).interfaceId;
}
```

**Interface ID:**
```solidity
// EIP-5192 Interface ID
bytes4 constant ERC5192_INTERFACE_ID = 0xb45a3c0e;

// 계산 방법:
// bytes4(keccak256("locked(uint256)"))
```

---

## 구현 패턴

### 패턴 1: 완전 Soulbound (Pure)

가장 간단하고 일반적인 패턴입니다.

```solidity
contract PureSoulbound is ERC721, IERC5192 {
    constructor() ERC721("Pure SBT", "PSBT") {}

    /// @dev 항상 잠김
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return true;
    }

    /// @dev mint만 허용
    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        emit Locked(tokenId);
        return tokenId;
    }

    /// @dev 전송 차단
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // mint는 허용 (from == address(0))
        // burn은 허용 (to == address(0))
        // 전송은 차단 (from != 0 && to != 0)
        require(
            from == address(0) || to == address(0),
            "Soulbound: Transfer not allowed"
        );

        return super._update(to, tokenId, auth);
    }

    /// @dev approve도 차단
    function approve(address, uint256) public pure override {
        revert("Soulbound: Approval not allowed");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Soulbound: Approval not allowed");
    }
}
```

**사용 사례:**
- 대학 학위
- 자격증
- 출석 증명
- 영구 멤버십

### 패턴 2: 조건부 Soulbound (Conditional)

관리자가 잠금을 제어할 수 있습니다.

```solidity
contract ConditionalSoulbound is ERC721, IERC5192 {
    mapping(uint256 => bool) private _locked;
    address public admin;

    constructor() ERC721("Conditional SBT", "CSBT") {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    /// @dev 잠금 상태 조회
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return _locked[tokenId];
    }

    /// @dev 잠긴 상태로 발행
    function mintLocked(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        _locked[tokenId] = true;
        emit Locked(tokenId);
        return tokenId;
    }

    /// @dev 잠금 상태 변경
    function setLocked(uint256 tokenId, bool locked_) external onlyAdmin {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");

        if (_locked[tokenId] != locked_) {
            _locked[tokenId] = locked_;

            if (locked_) {
                emit Locked(tokenId);
            } else {
                emit Unlocked(tokenId);
            }
        }
    }

    /// @dev 잠긴 토큰은 전송 불가
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // 전송(not mint, not burn)이고 잠긴 경우 차단
        if (from != address(0) && to != address(0)) {
            require(!_locked[tokenId], "Token is locked");
        }

        return super._update(to, tokenId, auth);
    }
}
```

**사용 사례:**
- 임시 자격증 (갱신 필요)
- 테스트용 SBT
- 조건 충족 시 양도 가능한 토큰

### 패턴 3: 시간 기반 Soulbound (Time-based)

일정 시간 후 잠금 해제됩니다.

```solidity
contract TimeLockSoulbound is ERC721, IERC5192 {
    mapping(uint256 => uint256) public unlockTime;

    constructor() ERC721("TimeLock SBT", "TLSBT") {}

    /// @dev 잠금 시간이 지나지 않았으면 잠김
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return block.timestamp < unlockTime[tokenId];
    }

    /// @dev 잠금 시간 설정하여 발행
    function mint(address to, uint256 lockDuration) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);

        unlockTime[tokenId] = block.timestamp + lockDuration;
        emit Locked(tokenId);

        return tokenId;
    }

    /// @dev 잠긴 동안은 전송 불가
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // 전송 시도 시 잠금 확인
        if (from != address(0) && to != address(0)) {
            require(
                block.timestamp >= unlockTime[tokenId],
                "Token is still locked"
            );

            // 첫 해제 시 이벤트
            emit Unlocked(tokenId);
        }

        return super._update(to, tokenId, auth);
    }
}
```

**사용 사례:**
- 베스팅 토큰
- 잠금 해제 기간이 있는 보상
- 임시 제한

### 패턴 4: 조건 충족 시 잠금 해제 (Achievement-based)

특정 조건 달성 시 잠금 해제됩니다.

```solidity
contract AchievementSoulbound is ERC721, IERC5192 {
    mapping(uint256 => uint256) public achievements;
    uint256 public constant UNLOCK_THRESHOLD = 100;

    constructor() ERC721("Achievement SBT", "ASBT") {}

    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return achievements[tokenId] < UNLOCK_THRESHOLD;
    }

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        achievements[tokenId] = 0;
        emit Locked(tokenId);
        return tokenId;
    }

    /// @dev 업적 점수 증가
    function addAchievement(uint256 tokenId, uint256 points) external {
        address owner = _ownerOf(tokenId);
        require(owner == msg.sender, "Not owner");

        uint256 oldScore = achievements[tokenId];
        achievements[tokenId] += points;

        // 임계값 도달 시 잠금 해제
        if (oldScore < UNLOCK_THRESHOLD && achievements[tokenId] >= UNLOCK_THRESHOLD) {
            emit Unlocked(tokenId);
        }
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            require(
                achievements[tokenId] >= UNLOCK_THRESHOLD,
                "Insufficient achievements"
            );
        }

        return super._update(to, tokenId, auth);
    }
}
```

**사용 사례:**
- 게임 업적
- 레벨업 시스템
- 포인트 기반 보상

---

## 실전 예제

### 예제 1: 대학 학위 증명서

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract UniversityDegree is ERC721, IERC5192 {
    struct Degree {
        string university;
        string major;
        string degreeType;  // "Bachelor", "Master", "PhD"
        uint256 graduationYear;
        string studentId;
    }

    mapping(uint256 => Degree) public degrees;
    address public registrar;  // 등록 담당자

    event DegreeIssued(
        address indexed graduate,
        uint256 indexed tokenId,
        string university,
        string major
    );

    constructor() ERC721("University Degree", "DEGREE") {
        registrar = msg.sender;
    }

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Not registrar");
        _;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId ||
               super.supportsInterface(interfaceId);
    }

    /// @dev 항상 잠김
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return true;
    }

    /// @dev 학위 발급
    function issueDegree(
        address graduate,
        string memory university,
        string memory major,
        string memory degreeType,
        uint256 graduationYear,
        string memory studentId
    ) external onlyRegistrar returns (uint256) {
        require(graduate != address(0), "Invalid address");

        uint256 tokenId = uint256(keccak256(abi.encodePacked(
            graduate,
            university,
            studentId,
            block.timestamp
        )));

        _mint(graduate, tokenId);

        degrees[tokenId] = Degree({
            university: university,
            major: major,
            degreeType: degreeType,
            graduationYear: graduationYear,
            studentId: studentId
        });

        emit Locked(tokenId);
        emit DegreeIssued(graduate, tokenId, university, major);

        return tokenId;
    }

    /// @dev 학위 검증
    function verifyDegree(uint256 tokenId)
        external
        view
        returns (bool valid, Degree memory degree)
    {
        if (_ownerOf(tokenId) == address(0)) {
            return (false, degree);
        }

        return (true, degrees[tokenId]);
    }

    /// @dev 전송 차단
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(
            from == address(0) || to == address(0),
            "Degree is non-transferable"
        );
        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override {
        revert("Degree is non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Degree is non-transferable");
    }
}
```

**사용법:**
```javascript
// 학위 발급
const tx = await degree.issueDegree(
    graduateAddress,
    "MIT",
    "Computer Science",
    "Bachelor",
    2024,
    "12345"
);

// 학위 검증
const [valid, degreeInfo] = await degree.verifyDegree(tokenId);
if (valid) {
    console.log(`Graduated from ${degreeInfo.university}`);
    console.log(`Major: ${degreeInfo.major}`);
}

// 전송 시도 → 실패
await degree.transferFrom(alice, bob, tokenId);  // ❌ revert!
```

### 예제 2: POAP (Proof of Attendance Protocol)

```solidity
contract AttendanceProof is ERC721, IERC5192 {
    struct Event {
        string eventName;
        string location;
        uint256 date;
        string organizer;
    }

    mapping(uint256 => Event) public events;
    mapping(bytes32 => bool) public eventHashes;  // 중복 방지

    event POAPMinted(
        address indexed attendee,
        uint256 indexed tokenId,
        string eventName
    );

    constructor() ERC721("Proof of Attendance", "POAP") {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId ||
               super.supportsInterface(interfaceId);
    }

    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return true;
    }

    /// @dev 출석 증명 발급
    function mintPOAP(
        address attendee,
        string memory eventName,
        string memory location,
        string memory organizer
    ) external returns (uint256) {
        // 중복 참여 방지
        bytes32 eventHash = keccak256(abi.encodePacked(
            attendee,
            eventName,
            block.timestamp
        ));
        require(!eventHashes[eventHash], "Already minted");

        uint256 tokenId = uint256(eventHash);
        _mint(attendee, tokenId);

        events[tokenId] = Event({
            eventName: eventName,
            location: location,
            date: block.timestamp,
            organizer: organizer
        });

        eventHashes[eventHash] = true;

        emit Locked(tokenId);
        emit POAPMinted(attendee, tokenId, eventName);

        return tokenId;
    }

    /// @dev 사용자의 모든 POAP 조회
    function getPOAPsOf(address owner)
        external
        view
        returns (uint256[] memory tokenIds, Event[] memory eventData)
    {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        eventData = new Event[](balance);

        uint256 counter = 0;
        for (uint256 i = 0; i < type(uint256).max && counter < balance; i++) {
            try this.ownerOf(i) returns (address tokenOwner) {
                if (tokenOwner == owner) {
                    tokenIds[counter] = i;
                    eventData[counter] = events[i];
                    counter++;
                }
            } catch {
                continue;
            }
        }
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(
            from == address(0) || to == address(0),
            "POAP is non-transferable"
        );
        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override {
        revert("POAP is non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("POAP is non-transferable");
    }
}
```

### 예제 3: 온체인 평판 시스템

```solidity
contract ReputationSystem is ERC721, IERC5192 {
    struct Reputation {
        uint256 score;
        uint256 level;
        uint256 positiveReviews;
        uint256 negativeReviews;
        uint256 lastUpdated;
    }

    mapping(uint256 => Reputation) public reputations;
    mapping(address => uint256) public userTokenId;

    uint256[] public levelThresholds = [0, 100, 500, 1000, 5000, 10000];

    event ReputationCreated(address indexed user, uint256 tokenId);
    event ScoreUpdated(uint256 indexed tokenId, uint256 newScore, uint256 newLevel);
    event ReviewAdded(uint256 indexed tokenId, bool positive);

    constructor() ERC721("Reputation Score", "REP") {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId ||
               super.supportsInterface(interfaceId);
    }

    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return true;
    }

    /// @dev 평판 토큰 생성 (주소당 1개만)
    function createReputation() external returns (uint256) {
        require(userTokenId[msg.sender] == 0, "Already has reputation");

        uint256 tokenId = uint256(uint160(msg.sender));
        _mint(msg.sender, tokenId);

        reputations[tokenId] = Reputation({
            score: 0,
            level: 0,
            positiveReviews: 0,
            negativeReviews: 0,
            lastUpdated: block.timestamp
        });

        userTokenId[msg.sender] = tokenId;

        emit Locked(tokenId);
        emit ReputationCreated(msg.sender, tokenId);

        return tokenId;
    }

    /// @dev 리뷰 추가 (점수 변동)
    function addReview(address user, bool positive) external {
        uint256 tokenId = userTokenId[user];
        require(tokenId != 0, "User has no reputation");

        Reputation storage rep = reputations[tokenId];
        uint256 oldLevel = _calculateLevel(rep.score);

        if (positive) {
            rep.positiveReviews++;
            rep.score += 10;
        } else {
            rep.negativeReviews++;
            if (rep.score >= 5) {
                rep.score -= 5;
            }
        }

        uint256 newLevel = _calculateLevel(rep.score);
        rep.level = newLevel;
        rep.lastUpdated = block.timestamp;

        emit ReviewAdded(tokenId, positive);
        emit ScoreUpdated(tokenId, rep.score, newLevel);
    }

    /// @dev 평판 점수로 레벨 계산
    function _calculateLevel(uint256 score) internal view returns (uint256) {
        for (uint256 i = levelThresholds.length - 1; i > 0; i--) {
            if (score >= levelThresholds[i]) {
                return i;
            }
        }
        return 0;
    }

    /// @dev 사용자 평판 조회
    function getReputation(address user)
        external
        view
        returns (Reputation memory)
    {
        uint256 tokenId = userTokenId[user];
        require(tokenId != 0, "User has no reputation");
        return reputations[tokenId];
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(
            from == address(0) || to == address(0),
            "Reputation is non-transferable"
        );
        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override {
        revert("Reputation is non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Reputation is non-transferable");
    }
}
```

### 예제 4: 멤버십 시스템

```solidity
contract MembershipNFT is ERC721, IERC5192 {
    enum Tier { Bronze, Silver, Gold, Platinum }

    struct Membership {
        Tier tier;
        uint256 joinedAt;
        uint256 expiresAt;
        bool active;
    }

    mapping(uint256 => Membership) public memberships;
    mapping(address => uint256) public memberTokenId;

    event MembershipIssued(address indexed member, uint256 tokenId, Tier tier);
    event MembershipUpgraded(uint256 indexed tokenId, Tier newTier);
    event MembershipRevoked(uint256 indexed tokenId);

    constructor() ERC721("Elite Membership", "MEMBER") {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId ||
               super.supportsInterface(interfaceId);
    }

    /// @dev 활성 멤버십만 잠김
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        Membership memory m = memberships[tokenId];
        return m.active && block.timestamp < m.expiresAt;
    }

    /// @dev 멤버십 발급
    function issueMembership(
        address member,
        Tier tier,
        uint256 duration
    ) external returns (uint256) {
        require(memberTokenId[member] == 0, "Already has membership");

        uint256 tokenId = uint256(uint160(member));
        _mint(member, tokenId);

        memberships[tokenId] = Membership({
            tier: tier,
            joinedAt: block.timestamp,
            expiresAt: block.timestamp + duration,
            active: true
        });

        memberTokenId[member] = tokenId;

        emit Locked(tokenId);
        emit MembershipIssued(member, tokenId, tier);

        return tokenId;
    }

    /// @dev 티어 업그레이드
    function upgradeTier(address member, Tier newTier) external {
        uint256 tokenId = memberTokenId[member];
        require(tokenId != 0, "No membership");

        Membership storage m = memberships[tokenId];
        require(m.active, "Membership not active");
        require(uint256(newTier) > uint256(m.tier), "Not an upgrade");

        m.tier = newTier;
        emit MembershipUpgraded(tokenId, newTier);
    }

    /// @dev 멤버십 취소
    function revokeMembership(address member) external {
        uint256 tokenId = memberTokenId[member];
        require(tokenId != 0, "No membership");

        memberships[tokenId].active = false;
        emit Unlocked(tokenId);
        emit MembershipRevoked(tokenId);
    }

    /// @dev 멤버십 확인
    function isMember(address account) external view returns (bool) {
        uint256 tokenId = memberTokenId[account];
        if (tokenId == 0) return false;

        Membership memory m = memberships[tokenId];
        return m.active && block.timestamp < m.expiresAt;
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // 전송 시 잠금 확인
        if (from != address(0) && to != address(0)) {
            Membership memory m = memberships[tokenId];
            require(
                !m.active || block.timestamp >= m.expiresAt,
                "Active membership is non-transferable"
            );
        }

        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override {
        revert("Membership is non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Membership is non-transferable");
    }
}
```

---

## 보안 고려사항

### 1. 잠금 우회 공격

**취약점:**
```solidity
// ❌ 취약한 코드
function locked(uint256 tokenId) external view returns (bool) {
    return _locked[tokenId];
}

// _update에서 잠금 확인 없음!
function _update(...) internal override returns (address) {
    return super._update(to, tokenId, auth);
    // 잠금 상태인데도 전송됨!
}
```

**해결책:**
```solidity
// ✅ 안전한 코드
function _update(
    address to,
    uint256 tokenId,
    address auth
) internal override returns (address) {
    address from = _ownerOf(tokenId);

    // mint와 burn은 허용
    if (from != address(0) && to != address(0)) {
        // 잠금 확인 필수!
        require(!_locked[tokenId], "Token is locked");
    }

    return super._update(to, tokenId, auth);
}
```

### 2. Burn 공격

**문제:**
Soulbound Token도 소각은 가능해야 합니다 (개인정보 보호).

```solidity
// ✅ 올바른 구현
function burn(uint256 tokenId) external {
    require(_ownerOf(tokenId) == msg.sender, "Not owner");
    _burn(tokenId);
    // Soulbound이어도 burn은 허용
}

function _update(...) internal override returns (address) {
    address from = _ownerOf(tokenId);

    // to == address(0) → burn, 항상 허용
    if (to == address(0)) {
        return super._update(to, tokenId, auth);
    }

    // from != address(0) → 전송, 잠금 확인
    if (from != address(0)) {
        require(!locked(tokenId), "Locked");
    }

    return super._update(to, tokenId, auth);
}
```

### 3. 프라이버시 문제

```
문제: 모든 SBT가 공개됨
┌─────────────────────────────────────────┐
│  Alice의 지갑:                           │
├─────────────────────────────────────────┤
│  - MIT 학위 ✅                          │
│  - 병원 진료 기록 ❌ (민감 정보!)       │
│  - 범죄 기록 ❌ (프라이버시 침해!)      │
└─────────────────────────────────────────┘

해결책: 선택적 공개
```

**Zero-Knowledge Proof 통합:**
```solidity
contract PrivateSoulbound is ERC721, IERC5192 {
    // 실제 데이터는 오프체인, 온체인에는 해시만
    mapping(uint256 => bytes32) public commitments;

    function mint(address to, bytes32 commitment) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        commitments[tokenId] = commitment;
        emit Locked(tokenId);
        return tokenId;
    }

    /// @dev ZK Proof로 자격 증명 (데이터 노출 없이)
    function verifyCredential(
        uint256 tokenId,
        bytes memory proof
    ) external view returns (bool) {
        // ZK-SNARK 검증
        // 실제 데이터를 공개하지 않고 자격 증명 가능
        return _verifyZKProof(commitments[tokenId], proof);
    }
}
```

### 4. 다중 계정 공격 (Sybil)

```
문제: 여러 지갑으로 여러 SBT 발급
┌─────────────────────────────────────────┐
│  악의적 사용자:                          │
├─────────────────────────────────────────┤
│  지갑 1: 평판 SBT #1                     │
│  지갑 2: 평판 SBT #2                     │
│  지갑 3: 평판 SBT #3                     │
│  ...                                    │
│  지갑 100: 평판 SBT #100                 │
└─────────────────────────────────────────┘

해결책: 신원 확인
```

**KYC 통합:**
```solidity
contract KYCVerifiedSBT is ERC721, IERC5192 {
    mapping(bytes32 => bool) public usedKYCHashes;

    function mint(address to, bytes32 kycHash, bytes memory signature)
        external
        returns (uint256)
    {
        // 1. KYC 제공자 서명 확인
        require(_verifyKYCSignature(kycHash, signature), "Invalid KYC");

        // 2. 중복 확인
        require(!usedKYCHashes[kycHash], "KYC already used");

        // 3. 발급
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        usedKYCHashes[kycHash] = true;

        emit Locked(tokenId);
        return tokenId;
    }
}
```

### 5. 잘못된 발급

```
문제: 실수로 잘못된 주소에 발급
┌─────────────────────────────────────────┐
│  대학교: Alice의 학위를 Bob에게 발급!    │
│  → Bob은 Alice인 척 사기                │
│  → 학위는 전송 불가 = 수정 불가!         │
└─────────────────────────────────────────┘

해결책: 취소 메커니즘
```

**Revoke 기능:**
```solidity
contract RevocableSBT is ERC721, IERC5192 {
    mapping(uint256 => bool) public revoked;
    address public issuer;

    function locked(uint256 tokenId) external view returns (bool) {
        return !revoked[tokenId];
    }

    /// @dev 발급 기관이 취소 가능
    function revoke(uint256 tokenId) external {
        require(msg.sender == issuer, "Not issuer");
        require(!revoked[tokenId], "Already revoked");

        revoked[tokenId] = true;
        emit Unlocked(tokenId);
    }

    function _update(...) internal override returns (address) {
        // 취소된 토큰은 burn 가능 (수정 가능)
        if (revoked[tokenId]) {
            return super._update(to, tokenId, auth);
        }

        // 취소되지 않은 토큰은 Soulbound
        address from = _ownerOf(tokenId);
        require(
            from == address(0) || to == address(0),
            "Non-transferable"
        );

        return super._update(to, tokenId, auth);
    }
}
```

---

## 실제 사용 사례

### 1. POAP (Proof of Attendance Protocol)

**가장 성공적인 SBT 프로젝트**

```
POAP 통계 (2024):
- 발급된 토큰: 수백만 개
- 이벤트 수: 수만 개
- 사용자: 수십만 명

사용 예:
✅ 컨퍼런스 출석 증명
✅ 온라인 이벤트 참여
✅ 커뮤니티 활동 증명
✅ 마일스톤 기념
```

**POAP의 특징:**
- 완전 Soulbound (전송 불가)
- 각 이벤트마다 고유한 디자인
- 무료 발급
- 게이밍피케이션 (수집 욕구)

### 2. GitPOAP

**GitHub 기여자를 위한 SBT**

```
발급 조건:
- 특정 리포지토리에 기여
- Pull Request 머지
- 오픈소스 프로젝트 참여

장점:
✅ 개발자 포트폴리오
✅ 기여 증명
✅ 커뮤니티 명성
```

### 3. Binance Account Bound (BAB)

**바이낸스의 KYC SBT**

```
목적: KYC 완료 증명

사용처:
✅ DeFi 프로토콜 접근
✅ 에어드롭 자격
✅ Sybil 공격 방어
✅ 규제 준수

주의사항:
- 개인정보는 오프체인
- 온체인에는 검증 결과만 저장
```

### 4. Galxe (구 Project Galaxy)

**Web3 자격 증명 플랫폼**

```
기능:
- 다양한 활동 증명 SBT
- 퀘스트 완료 시 발급
- 여러 프로토콜 통합

예시:
✅ DeFi 프로토콜 사용 경험
✅ NFT 컬렉션 보유
✅ DAO 투표 참여
✅ 특정 체인 활동
```

### 5. 대학 학위 (미래)

**아직 초기 단계이지만 가능성 큼**

```
MIT Digital Credentials:
- 2017년부터 실험 중
- Blockcerts 프로토콜 사용
- 졸업장을 블록체인에 기록

장점:
✅ 위조 방지
✅ 즉각 검증
✅ 평생 보관
✅ 글로벌 인정

과제:
❌ 법적 인정 필요
❌ 프라이버시 우려
❌ 대학들의 채택 필요
```

---

## 학습 로드맵

### Level 1: 초보자 (1주)

**목표:** Soulbound Token의 기본 개념 이해

```
□ ERC-721 복습
  - mint, burn, transfer
  - ownerOf, balanceOf

□ EIP-5192 이해
  - locked() 함수
  - Locked/Unlocked 이벤트
  - 전송 차단 원리

□ 간단한 SBT 배포
  - PureSoulbound 컨트랙트 배포
  - mint 테스트
  - transfer 시도 (revert 확인)

□ 실습 과제:
  - 출석 증명 SBT 만들기
  - locked()가 true 반환하는지 확인
  - transferFrom() 호출 시 revert 확인
```

### Level 2: 중급자 (2주)

**목표:** 다양한 SBT 패턴 구현

```
□ Conditional Soulbound
  - 잠금/해제 메커니즘
  - 관리자 권한 구조
  - 상태 변경 이벤트

□ Time-based Soulbound
  - 시간 기반 잠금
  - block.timestamp 활용
  - 자동 해제 로직

□ Achievement-based
  - 조건 충족 시 해제
  - 포인트 시스템
  - 레벨업 메커니즘

□ 실습 과제:
  - 3가지 패턴 모두 구현
  - 각 패턴의 사용 사례 생각
  - 테스트 케이스 작성
```

### Level 3: 고급자 (3주)

**목표:** 프로덕션급 SBT 시스템 구축

```
□ 복합 SBT 시스템
  - 학위 증명서 시스템
  - POAP 시스템
  - 평판 시스템

□ 메타데이터 관리
  - IPFS 통합
  - 동적 메타데이터
  - 이미지 생성

□ 보안 강화
  - Reentrancy 방어
  - Access Control
  - Revoke 메커니즘

□ 실습 과제:
  - 대학 학위 시스템 구현
  - 발급, 검증, 취소 기능
  - 프론트엔드 연동
```

### Level 4: 전문가 (4주+)

**목표:** 혁신적인 SBT 애플리케이션

```
□ 프라이버시 보호
  - Zero-Knowledge Proofs 통합
  - 선택적 공개
  - 오프체인 데이터 관리

□ Multi-chain SBT
  - Cross-chain 증명
  - LayerZero/Axelar 통합
  - 체인 간 검증

□ 실제 통합
  - KYC 제공자 연동
  - 대학/기업 시스템 연동
  - 법적 요구사항 충족

□ 실전 프로젝트:
  - 본인만의 SBT 플랫폼 구축
  - 실제 사용 사례 구현
  - 커뮤니티 피드백 수집
```

---

## FAQ

### Q1: Soulbound Token은 정말 전송할 수 없나요?

**A:** 구현에 따라 다릅니다.

```
1. Pure Soulbound:
   - 완전히 전송 불가
   - locked() 항상 true

2. Conditional Soulbound:
   - 조건부로 전송 가능
   - 관리자가 unlock 가능

3. Time-based Soulbound:
   - 일정 시간 후 전송 가능
   - 베스팅 토큰처럼 동작
```

### Q2: Soulbound Token도 소각할 수 있나요?

**A:** 네, 소각은 가능합니다 (그리고 가능해야 합니다).

```solidity
// "잊혀질 권리" 보장
function burn(uint256 tokenId) external {
    require(_ownerOf(tokenId) == msg.sender, "Not owner");
    _burn(tokenId);
    // ✅ Soulbound여도 소각은 허용
}
```

**이유:**
- 개인정보 보호 (GDPR 준수)
- 실수로 발급된 경우
- 더 이상 필요 없는 경우

### Q3: SBT를 잃어버리면?

**A:** 일반 NFT보다 더 심각한 문제입니다.

```
문제:
┌─────────────────────────────────────────┐
│  Alice가 지갑 개인키 분실               │
│  → 모든 학위, 자격증, 평판 손실         │
│  → 복구 불가능!                         │
└─────────────────────────────────────────┘

해결책:
1. 사회적 복구 (Social Recovery)
   - 친구/가족이 복구 승인

2. 재발급 메커니즘
   - 발급 기관이 새 지갑에 재발급

3. Multi-sig 지갑 사용
   - 여러 키로 지갑 제어
```

### Q4: 익명성과 SBT는 모순 아닌가요?

**A:** 선택적 공개가 답입니다.

```
Zero-Knowledge Credentials:
┌─────────────────────────────────────────┐
│  Alice:                                 │
│  - MIT 학위 SBT 보유 (private)          │
│  - "나는 대학 졸업자다" 증명 (public)    │
│  - 어느 대학인지는 비공개               │
│                                         │
│  → ZK Proof로 자격 증명                 │
│  → 개인정보는 노출 안 됨                │
└─────────────────────────────────────────┘
```

### Q5: EIP-5192와 EIP-4973의 차이는?

**A:** 두 표준 모두 Soulbound를 다루지만 접근이 다릅니다.

```
EIP-5192 (Minimal):
✅ ERC-721 확장
✅ locked() 함수만 추가
✅ 기존 NFT 생태계와 호환
✅ 간단하고 유연함

EIP-4973 (Account Bound):
✅ 새로운 표준 (ERC-721 아님)
✅ mint에 수신자 동의 필요
✅ 더 엄격한 Soulbound
❌ 복잡함
❌ 생태계 호환성 낮음

일반적으로 EIP-5192 추천!
```

### Q6: SBT를 거래소에 상장할 수 있나요?

**A:** 할 수 없고, 해서도 안 됩니다.

```
Soulbound의 본질:
┌─────────────────────────────────────────┐
│  ❌ 금전적 가치를 가져서는 안 됨         │
│  ❌ 판매 목적이 아님                    │
│  ✅ 신원, 자격, 명성의 증명             │
│  ✅ 개인에게 고유함                     │
└─────────────────────────────────────────┘

만약 거래 가능하다면:
- 자격 위조 가능
- Sybil 공격 가능
- 본래 목적 상실
```

### Q7: SBT는 상속할 수 있나요?

**A:** 일반적으로 아니지만, 구현 가능합니다.

```solidity
contract InheritableSBT is ERC721, IERC5192 {
    mapping(address => address) public heir;  // 상속인 지정

    function setHeir(address _heir) external {
        heir[msg.sender] = _heir;
    }

    function inheritToken(uint256 tokenId, address deceased)
        external
    {
        require(heir[deceased] == msg.sender, "Not heir");
        // 사망 증명 확인 로직...

        // 특별히 상속만 허용
        _transfer(deceased, msg.sender, tokenId);
    }
}
```

하지만 대부분의 SBT는 상속 불가가 원칙입니다.

### Q8: 기업도 SBT를 가질 수 있나요?

**A:** 네, 조직도 "영혼"이 있을 수 있습니다.

```
조직의 SBT 사례:
┌─────────────────────────────────────────┐
│  ✅ 기업 인증서                         │
│  ✅ 파트너십 증명                       │
│  ✅ 규제 준수 증명                      │
│  ✅ ESG 등급                            │
│  ✅ 업계 수상 경력                      │
└─────────────────────────────────────────┘

예: DAO에 발급된 SBT
- 특정 프로토콜과의 파트너십
- 감사 통과 증명
- 거버넌스 참여 이력
```

### Q9: SBT의 가장 큰 문제점은?

**A:** 프라이버시와 영구성입니다.

```
문제점:
┌─────────────────────────────────────────┐
│  1. 모든 SBT가 공개됨                   │
│     → 민감한 정보 노출 위험             │
│                                         │
│  2. 삭제 불가능 (블록체인 특성)         │
│     → "잊혀질 권리" 침해                │
│                                         │
│  3. 편견과 차별 가능성                  │
│     → 부정적 SBT로 낙인                 │
│                                         │
│  4. 표준화 부족                         │
│     → 각 플랫폼마다 다름                │
└─────────────────────────────────────────┘

해결 방향:
✅ Zero-Knowledge Proofs
✅ Off-chain 데이터 저장
✅ 선택적 공개 메커니즘
✅ 표준 확립
```

### Q10: SBT의 미래는?

**A:** 매우 유망하지만 과제도 많습니다.

```
긍정적 전망:
✅ Web3 신원 시스템의 핵심
✅ 학력, 자격증의 디지털화
✅ 온체인 평판 시스템
✅ Sybil 공격 방어

과제:
❌ 법적 인정 필요
❌ 프라이버시 보호 기술 필요
❌ 대규모 채택 필요
❌ 표준화 필요

예상 타임라인:
2024-2025: 실험 및 표준화
2026-2027: 초기 채택 (게임, 커뮤니티)
2028-2030: 대규모 채택 (교육, 기업)
```

---

## 참고 자료

### 공식 문서
- [EIP-5192 Specification](https://eips.ethereum.org/EIPS/eip-5192)
- [Decentralized Society Paper](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4105763) - Vitalik Buterin
- [POAP Documentation](https://poap.xyz/)

### 실전 예제
- [contracts/EIP5192Example.sol](./contracts/EIP5192Example.sol) - 다양한 구현 패턴
- [CHEATSHEET.md](./CHEATSHEET.md) - 빠른 참조

### 외부 자료
- [Soulbound Tokens Explained](https://vitalik.ca/general/2022/01/26/soulbound.html) - Vitalik's Blog
- [GitPOAP](https://www.gitpoap.io/) - GitHub 기여자 SBT
- [Binance Account Bound (BAB)](https://www.binance.com/en/babt)

### 추천 도구
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) - ERC-721 기반
- [IPFS](https://ipfs.io/) - 메타데이터 저장
- [The Graph](https://thegraph.com/) - SBT 데이터 인덱싱

---

## 요약

**EIP-5192 한 줄 요약:**
> "양도 불가능한 NFT로 개인의 자격, 경력, 명성을 온체인에 영구 기록하는 표준입니다."

**핵심 포인트:**
1. ✅ **양도 불가**: 특정 주소에 영구히 묶임
2. ✅ **신원 증명**: 학위, 자격증, 출석 증명
3. ✅ **명성 시스템**: 온체인 평판 구축
4. ✅ **Sybil 방어**: 여러 지갑으로 명성 복제 불가
5. ✅ **최소 인터페이스**: locked() 함수 하나만 추가

**다음 학습:**
- [EIP-712 (Typed Data Signing)](../../essential/EIP-712/README.md)
- [EIP-1271 (Contract Signature)](../../essential/EIP-1271/README.md)
- [EIP-4973 (Account Bound Token)](https://eips.ethereum.org/EIPS/eip-4973)

---

*최종 업데이트: 2024년*
*작성자: EIP Study Group*
