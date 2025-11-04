# EIP-2981: NFT Royalty Standard

> **한 줄 요약**: NFT 창작자가 2차 판매 시 자동으로 로열티를 받을 수 있게 해주는 표준

📌 **[치트시트 보기](./CHEATSHEET.md)** - 빠른 참고용 코드 모음

## 핵심만 빠르게

```solidity
// ❌ Before EIP-2981: 로열티 받을 방법 없음
contract OldNFT is ERC721 {
    // 2차 판매 시 창작자는 아무것도 받지 못함 😢
}

// ✅ After EIP-2981: 자동 로열티 수령
contract ModernNFT is ERC721, ERC2981 {
    constructor() ERC721("MyNFT", "MNFT") {
        _setDefaultRoyalty(creator, 500); // 5% 로열티
    }
}

// 마켓플레이스에서 자동으로 로열티 지급
(address receiver, uint256 amount) = nft.royaltyInfo(tokenId, salePrice);
// receiver에게 amount 전송
```

### 3줄 요약
1. **문제**: NFT 창작자가 2차 판매에서 수익을 얻을 방법이 없음
2. **해결**: `royaltyInfo()` 함수로 로열티 정보를 표준화
3. **효과**: 창작자 지속 수익 + 마켓플레이스 호환성 + NFT 생태계 활성화

### 실무에서 왜 중요한가?
- ✅ **NFT 아티스트**: 작품이 재판매될 때마다 수익 발생
- ✅ **음악 NFT**: 음악이 거래될 때마다 뮤지션에게 로열티
- ✅ **게임 아이템**: 아이템 거래 시 개발사 수익 보장
- ✅ **마켓플레이스**: 표준화된 방식으로 로열티 처리

---

## 목차
1. [EIP-2981이 왜 필요한가?](#왜-필요한가)
2. [동작 원리 (한눈에 보기)](#동작-원리-한눈에-보기)
3. [핵심 개념](#핵심-개념)
4. [Basis Points 이해하기](#basis-points-이해하기)
5. [실전 구현 패턴](#실전-구현-패턴)
6. [마켓플레이스 통합](#마켓플레이스-통합)
7. [로열티 계산 패턴](#로열티-계산-패턴)
8. [다중 수령자 패턴](#다중-수령자-패턴)
9. [실무 활용 예제](#실무-활용-예제)
10. [보안 고려사항](#보안-고려사항)

---

## 왜 필요한가?

### 문제 상황: NFT 창작자의 딜레마

```
시나리오:
1. 아티스트가 NFT를 1 ETH에 판매
2. 구매자가 며칠 후 10 ETH에 재판매
3. 아티스트는 최초 1 ETH만 받고 끝

문제:
- 작품 가치 상승의 혜택을 창작자가 받지 못함
- 2차 시장 거래에서 창작자 소외
- 지속 가능한 창작 생태계 부재
```

**실제 사례:**

```
Beeple의 "Everydays":
- 최초 판매: $69.3M (2021년 3월)
- 만약 재판매된다면? Beeple은 로열티를 받을 수 있어야 함

CryptoPunks:
- 초기 무료 배포
- 현재 거래가: 수백만 달러
- EIP-2981 없이는 원작자 수익 없음
```

### EIP-2981의 해결책

```
┌─────────────────────────────────────────────────────────────┐
│                  EIP-2981 핵심 아이디어                       │
│                                                               │
│  NFT 컨트랙트가 "이 NFT 팔리면 창작자에게 X% 주세요"         │
│  라고 마켓플레이스에게 알려주는 표준 방법 제공                │
│                                                               │
│  royaltyInfo(tokenId, salePrice)                             │
│    → (수령자 주소, 로열티 금액)                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 동작 원리 (한눈에 보기)

### 전체 흐름도

```
1. NFT 발행 시 로열티 설정
┌──────────────────────────────────────────┐
│  NFT Contract                            │
│  ────────────────────────────────────    │
│  constructor() {                         │
│    _setDefaultRoyalty(                   │
│      artist,  // 수령자                  │
│      500      // 5% (10000 = 100%)       │
│    );                                    │
│  }                                       │
└────────────────┬─────────────────────────┘
                 │
                 ▼
2. 마켓플레이스에서 거래 발생
┌──────────────────────────────────────────┐
│  Buyer: "이 NFT를 10 ETH에 사고 싶어요"  │
│  Marketplace: "로열티 확인해볼게요"      │
│                                          │
│  (address receiver, uint256 royalty)     │
│    = nft.royaltyInfo(tokenId, 10 ETH);   │
│                                          │
│  // 반환: (artist, 0.5 ETH)              │
└────────────────┬─────────────────────────┘
                 │
                 ▼
3. 자금 분배
┌──────────────────────────────────────────┐
│  총 거래액: 10 ETH                       │
│  ├─ 로열티: 0.5 ETH → 창작자            │
│  ├─ 수수료: 0.25 ETH → 마켓플레이스     │
│  └─ 판매금: 9.25 ETH → 판매자           │
│                                          │
│  모두가 만족! 🎉                         │
└──────────────────────────────────────────┘
```

### 로열티 계산 과정

```
입력값:
┌─────────────────────────┐
│ tokenId: 42             │
│ salePrice: 10 ETH       │
└────────┬────────────────┘
         │
         ▼
royaltyInfo() 호출
┌─────────────────────────────────────┐
│ 1. 해당 토큰의 로열티 설정 확인     │
│    - 개별 설정 있음? → 사용         │
│    - 없음? → 기본값 사용            │
│                                     │
│ 2. 로열티 비율: 500 (5%)            │
│                                     │
│ 3. 계산:                            │
│    royalty = 10 ETH × 500 / 10000   │
│           = 0.5 ETH                 │
└────────┬────────────────────────────┘
         │
         ▼
반환값:
┌─────────────────────────┐
│ receiver: 0x123...abc   │
│ royaltyAmount: 0.5 ETH  │
└─────────────────────────┘
```

---

## 핵심 개념

### 1. IERC2981 인터페이스

모든 EIP-2981 호환 NFT는 이 인터페이스를 구현해야 합니다:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC2981 {
    /**
     * @notice 로열티 정보 조회
     * @param tokenId NFT 토큰 ID
     * @param salePrice 판매 가격 (wei 단위)
     * @return receiver 로열티 수령자 주소
     * @return royaltyAmount 로열티 금액 (wei 단위)
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}
```

**핵심 포인트:**
- `view` 함수: 상태 변경 없음, 가스비 무료
- `salePrice` 입력: 판매가에 비례한 로열티 계산
- 반환값: 누구에게(`receiver`) 얼마를(`royaltyAmount`) 줄지 명확

### 2. Basis Points (베이시스 포인트)

**10000 = 100%** 규칙을 사용합니다.

```solidity
// Basis Points 계산법
uint256 constant DENOMINATOR = 10000;

// 예시
500   = 5%    (500 / 10000)
250   = 2.5%  (250 / 10000)
1000  = 10%   (1000 / 10000)
10000 = 100%  (10000 / 10000)

// 로열티 계산
royaltyAmount = salePrice * basisPoints / 10000;
```

**왜 10000인가?**

```
장점:
✅ 소수점 없이 정밀한 퍼센트 표현 (2.5% = 250)
✅ 정수 연산만으로 처리 가능 (가스 절약)
✅ 업계 표준 (금융권에서 사용하는 방식)
✅ Solidity의 실수 연산 제한 우회

예시:
2.5% 로열티를 표현하려면?
- ❌ 0.025 (Solidity는 소수점 지원 안함)
- ✅ 250 basis points (정수로 표현)
```

### 3. 수령자 (Receiver)

로열티를 받을 주소를 지정합니다.

```solidity
address public royaltyReceiver;

// 패턴 1: 창작자 직접 수령
royaltyReceiver = 0x123...abc; // 아티스트 주소

// 패턴 2: 스마트 컨트랙트 수령 (자동 분배)
royaltyReceiver = paymentSplitterContract;

// 패턴 3: DAO 수령
royaltyReceiver = daoTreasuryContract;

// 패턴 4: 다중서명 지갑
royaltyReceiver = multisigWalletContract;
```

### 4. EIP-165 통합

EIP-2981은 EIP-165를 사용하여 인터페이스 지원을 알립니다:

```solidity
contract MyNFT is ERC721, ERC2981 {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}
```

**Interface ID:**
```solidity
type(IERC2981).interfaceId = 0x2a55205a
```

---

## Basis Points 이해하기

### 일반적인 로열티 비율

```solidity
// 표준 로열티 비율들
uint256 constant ROYALTY_2_5_PERCENT = 250;   // OpenSea 초기 기본값
uint256 constant ROYALTY_5_PERCENT = 500;     // 일반적인 설정
uint256 constant ROYALTY_7_5_PERCENT = 750;   // 높은 편
uint256 constant ROYALTY_10_PERCENT = 1000;   // 최대 권장값
uint256 constant ROYALTY_15_PERCENT = 1500;   // 매우 높음 (비권장)

// 산업별 일반적인 비율
// Art NFTs: 5-10%
// Music NFTs: 10-15%
// Gaming Items: 2.5-5%
// Profile Pictures (PFP): 5-7.5%
// Metaverse Land: 2.5-5%
```

### 계산 예제

```solidity
contract RoyaltyCalculator {
    uint96 private constant _feeDenominator = 10000;

    /**
     * @notice 로열티 금액 계산
     */
    function calculateRoyalty(
        uint256 salePrice,
        uint96 feeNumerator
    ) public pure returns (uint256) {
        return (salePrice * feeNumerator) / _feeDenominator;
    }

    /**
     * @notice 다양한 가격대의 로열티 계산 예시
     */
    function exampleCalculations() public pure {
        uint96 royalty5Percent = 500;

        // 1 ETH 판매
        // 0.05 ETH 로열티 (1 * 500 / 10000)

        // 10 ETH 판매
        // 0.5 ETH 로열티 (10 * 500 / 10000)

        // 100 ETH 판매
        // 5 ETH 로열티 (100 * 500 / 10000)
    }
}
```

### 실제 계산 시뮬레이션

```
판매가: 8.5 ETH = 8,500,000,000,000,000,000 wei
로열티: 5% = 500 basis points

계산:
royaltyAmount = 8,500,000,000,000,000,000 × 500 / 10000
              = 425,000,000,000,000,000 wei
              = 0.425 ETH

결과:
- 로열티 수령자: 0.425 ETH
- 마켓플레이스 수수료 (2.5%): 0.2125 ETH
- 판매자 순수익: 7.8625 ETH
```

---

## 실전 구현 패턴

### 패턴 1: 기본 구현 (OpenZeppelin 사용)

[SimpleRoyaltyNFT.sol](./contracts/SimpleRoyaltyNFT.sol) 참고

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleRoyaltyNFT is ERC721, ERC2981, Ownable {
    uint256 private _tokenIdCounter;

    constructor(
        address royaltyReceiver,
        uint96 royaltyFeeNumerator  // 500 = 5%
    ) ERC721("Simple Royalty NFT", "SRNFT") Ownable(msg.sender) {
        // 모든 NFT에 동일한 로열티 적용
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    function mint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
    }

    /**
     * @notice 기본 로열티 설정 변경
     */
    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @notice 특정 토큰의 로열티 설정
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @notice EIP-165 지원 인터페이스
     */
    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### 패턴 2: 동적 로열티 (조건부)

[DynamicRoyaltyNFT.sol](./contracts/DynamicRoyaltyNFT.sol) 참고

```solidity
contract DynamicRoyaltyNFT is ERC721, ERC2981, Ownable {
    uint256 private _tokenIdCounter;

    // 시간에 따른 로열티 감소
    uint256 public immutable launchTime;
    uint256 public constant INITIAL_ROYALTY = 1000;  // 10%
    uint256 public constant FINAL_ROYALTY = 250;     // 2.5%
    uint256 public constant DECAY_PERIOD = 365 days;

    constructor() ERC721("Dynamic Royalty NFT", "DRNFT") Ownable(msg.sender) {
        launchTime = block.timestamp;
        _setDefaultRoyalty(owner(), INITIAL_ROYALTY);
    }

    /**
     * @notice 시간이 지날수록 로열티 감소
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public view virtual override
        returns (address, uint256)
    {
        uint256 elapsed = block.timestamp - launchTime;
        uint96 currentRoyalty;

        if (elapsed >= DECAY_PERIOD) {
            currentRoyalty = FINAL_ROYALTY;
        } else {
            // 선형 감소
            uint256 decrease = (INITIAL_ROYALTY - FINAL_ROYALTY) * elapsed / DECAY_PERIOD;
            currentRoyalty = uint96(INITIAL_ROYALTY - decrease);
        }

        uint256 royaltyAmount = (salePrice * currentRoyalty) / 10000;
        return (owner(), royaltyAmount);
    }

    function mint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## 마켓플레이스 통합

### OpenSea, Blur, LooksRare 호환성

```solidity
contract MarketplaceCompatibleNFT is ERC721, ERC2981, Ownable {
    constructor() ERC721("Compatible NFT", "CNFT") Ownable(msg.sender) {
        // 모든 주요 마켓플레이스가 EIP-2981 지원
        _setDefaultRoyalty(msg.sender, 500); // 5%
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

**마켓플레이스별 지원 현황:**

```
┌─────────────┬──────────────┬─────────────────┐
│ Marketplace │ EIP-2981     │ Royalty Enforcement│
├─────────────┼──────────────┼─────────────────┤
│ OpenSea     │ ✅ 지원      │ 선택적           │
│ Blur        │ ✅ 지원      │ 선택적 (0% 가능) │
│ LooksRare   │ ✅ 완전 지원 │ 강제             │
│ Rarible     │ ✅ 완전 지원 │ 강제             │
│ Foundation  │ ✅ 지원      │ 강제             │
└─────────────┴──────────────┴─────────────────┘
```

### 커스텀 마켓플레이스 구현

[MarketplaceIntegration.sol](./contracts/MarketplaceIntegration.sol) 참고

```solidity
contract NFTMarketplace {
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;
    uint256 public platformFee = 250; // 2.5%
    address public platformAddress;

    constructor() {
        platformAddress = msg.sender;
    }

    /**
     * @notice NFT 구매 (로열티 자동 처리)
     */
    function buyNFT(
        address nftContract,
        uint256 tokenId
    ) external payable {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.active, "Not listed");
        require(msg.value >= listing.price, "Insufficient payment");

        uint256 royaltyAmount = 0;
        address royaltyReceiver;

        // 1. 로열티 확인 및 지급
        if (IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)) {
            (royaltyReceiver, royaltyAmount) =
                IERC2981(nftContract).royaltyInfo(tokenId, listing.price);

            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                (bool royaltySuccess, ) = royaltyReceiver.call{value: royaltyAmount}("");
                require(royaltySuccess, "Royalty transfer failed");
            }
        }

        // 2. 플랫폼 수수료
        uint256 platformAmount = (listing.price * platformFee) / 10000;
        (bool platformSuccess, ) = platformAddress.call{value: platformAmount}("");
        require(platformSuccess, "Platform fee transfer failed");

        // 3. 판매자에게 잔액 전송
        uint256 sellerAmount = listing.price - royaltyAmount - platformAmount;
        (bool sellerSuccess, ) = listing.seller.call{value: sellerAmount}("");
        require(sellerSuccess, "Seller transfer failed");

        // 4. NFT 전송
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);

        // 5. 리스팅 제거
        listings[nftContract][tokenId].active = false;
    }
}
```

---

## 로열티 계산 패턴

### 패턴 1: 고정 로열티

```solidity
contract FixedRoyaltyNFT is ERC721, ERC2981, Ownable {
    constructor() ERC721("Fixed", "FIX") Ownable(msg.sender) {
        _setDefaultRoyalty(owner(), 500); // 항상 5%
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### 패턴 2: 계층별 로열티

```solidity
contract TieredRoyaltyNFT is ERC721, ERC2981, Ownable {
    constructor() ERC721("Tiered", "TIER") Ownable(msg.sender) {}

    /**
     * @notice 판매가에 따라 로열티 차등 적용
     */
    function royaltyInfo(uint256, uint256 salePrice)
        public view virtual override
        returns (address, uint256)
    {
        uint96 royaltyBps;

        if (salePrice < 1 ether) {
            royaltyBps = 250;    // 2.5% (소액 거래)
        } else if (salePrice < 10 ether) {
            royaltyBps = 500;    // 5% (일반 거래)
        } else if (salePrice < 100 ether) {
            royaltyBps = 750;    // 7.5% (고액 거래)
        } else {
            royaltyBps = 1000;   // 10% (초고액 거래)
        }

        uint256 royaltyAmount = (salePrice * royaltyBps) / 10000;
        return (owner(), royaltyAmount);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## 다중 수령자 패턴

### PaymentSplitter 사용

[MultiRecipientRoyalty.sol](./contracts/MultiRecipientRoyalty.sol) 참고

```solidity
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract MultiRecipientRoyaltyNFT is ERC721, ERC2981, Ownable {
    PaymentSplitter public royaltySplitter;

    constructor(
        address[] memory payees,
        uint256[] memory shares
    ) ERC721("Multi Recipient NFT", "MRNFT") Ownable(msg.sender) {
        // 로열티 분배 컨트랙트 생성
        royaltySplitter = new PaymentSplitter(payees, shares);

        // PaymentSplitter 주소를 로열티 수령자로 설정
        _setDefaultRoyalty(address(royaltySplitter), 500); // 5%
    }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    /**
     * @notice 수령자가 자신의 몫 인출
     */
    function withdrawRoyalties(address payable account) external {
        royaltySplitter.release(account);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## 실무 활용 예제

### 예제 1: 아트 NFT 컬렉션

```solidity
contract ArtNFTCollection is ERC721, ERC2981, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MINT_PRICE = 0.08 ether;
    uint256 private _tokenIdCounter;

    string private _baseTokenURI;
    address public artist;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address _artist
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenURI = baseURI;
        artist = _artist;

        // 아티스트에게 7.5% 로열티
        _setDefaultRoyalty(_artist, 750);
    }

    function mint() external payable returns (uint256) {
        require(_tokenIdCounter < MAX_SUPPLY, "Sold out");
        require(msg.value >= MINT_PRICE, "Insufficient payment");

        uint256 tokenId = _tokenIdCounter++;
        _safeMint(msg.sender, tokenId);

        return tokenId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### 예제 2: 음악 NFT

```solidity
contract MusicNFT is ERC721, ERC2981, Ownable {
    struct Track {
        string title;
        string artist;
        string ipfsHash;
        uint256 duration;
        uint256 releaseDate;
    }

    mapping(uint256 => Track) public tracks;
    uint256 private _tokenIdCounter;
    uint96 public constant MUSICIAN_ROYALTY = 1000; // 10%

    event TrackMinted(
        uint256 indexed tokenId,
        string title,
        string artist,
        address musician
    );

    constructor() ERC721("Music NFT", "MUSIC") Ownable(msg.sender) {}

    function mintTrack(
        address musician,
        string memory title,
        string memory artist,
        string memory ipfsHash,
        uint256 duration
    ) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;

        tracks[tokenId] = Track({
            title: title,
            artist: artist,
            ipfsHash: ipfsHash,
            duration: duration,
            releaseDate: block.timestamp
        });

        _safeMint(musician, tokenId);
        _setTokenRoyalty(tokenId, musician, MUSICIAN_ROYALTY);

        emit TrackMinted(tokenId, title, artist, musician);
        return tokenId;
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### 예제 3: 게임 아이템 NFT

```solidity
contract GameItemNFT is ERC721, ERC2981, Ownable {
    enum ItemType { Weapon, Armor, Consumable, Cosmetic }
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary }

    struct GameItem {
        ItemType itemType;
        Rarity rarity;
        uint256 power;
        bool tradeable;
    }

    mapping(uint256 => GameItem) public items;
    uint256 private _tokenIdCounter;
    address public gameStudio;

    constructor(address _gameStudio) ERC721("Game Item", "ITEM") Ownable(msg.sender) {
        gameStudio = _gameStudio;
        _setDefaultRoyalty(_gameStudio, 250); // 2.5%
    }

    function mintItem(
        address player,
        ItemType itemType,
        Rarity rarity,
        uint256 power
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;

        items[tokenId] = GameItem({
            itemType: itemType,
            rarity: rarity,
            power: power,
            tradeable: true
        });

        _safeMint(player, tokenId);

        // 희귀도에 따른 로열티
        uint96 royalty = getRoyaltyByRarity(rarity);
        _setTokenRoyalty(tokenId, gameStudio, royalty);

        return tokenId;
    }

    function getRoyaltyByRarity(Rarity rarity)
        public pure returns (uint96)
    {
        if (rarity == Rarity.Common) return 100;      // 1%
        if (rarity == Rarity.Uncommon) return 150;    // 1.5%
        if (rarity == Rarity.Rare) return 250;        // 2.5%
        if (rarity == Rarity.Epic) return 400;        // 4%
        return 500;  // Legendary: 5%
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## 보안 고려사항

### 1. 로열티 조작 방지

```solidity
contract SecureRoyaltyNFT is ERC721, ERC2981, Ownable {
    uint96 public constant MAX_ROYALTY_BPS = 1000; // 최대 10%

    constructor() ERC721("Secure", "SEC") Ownable(msg.sender) {}

    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        require(feeNumerator <= MAX_ROYALTY_BPS, "Royalty too high");
        require(receiver != address(0), "Invalid receiver");
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### 2. 오버플로우 방지

```solidity
// Solidity 0.8+ 자동 오버플로우 체크
function royaltyInfo(uint256, uint256 salePrice)
    public view returns (address, uint256)
{
    uint96 royaltyBps = 500;

    // ✅ 안전: 곱셈 먼저, 나눗셈 나중
    uint256 royaltyAmount = (salePrice * royaltyBps) / 10000;

    return (owner(), royaltyAmount);
}
```

### 3. Zero Address 체크

```solidity
function setRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
    require(receiver != address(0), "Receiver cannot be zero address");
    require(feeNumerator <= 10000, "Invalid fee");
    _setDefaultRoyalty(receiver, feeNumerator);
}
```

---

## 자주 묻는 질문 (FAQ)

### Q1: 로열티는 누가 지급하나요?

**A:** 마켓플레이스가 판매 대금에서 자동으로 차감하여 지급합니다.

```
거래 흐름:
1. 구매자가 10 ETH 지불
2. 마켓플레이스가 royaltyInfo() 호출
3. 창작자에게 0.5 ETH 전송 (5% 로열티)
4. 마켓플레이스 수수료 0.25 ETH (2.5%)
5. 판매자에게 9.25 ETH 전송
```

### Q2: 적정 로열티 비율은?

**A:** 일반적으로 **2.5-10%**가 적정합니다.

```
업계 표준:
Art NFTs: 5-10%
Music NFTs: 10-15%
PFP Projects: 5-7.5%
Gaming Items: 2.5-5%
```

### Q3: 로열티를 나중에 변경할 수 있나요?

**A:** 컨트랙트 설계에 따라 다릅니다.

```solidity
// 변경 가능 (Mutable)
function setDefaultRoyalty(address receiver, uint96 fee)
    external onlyOwner
{
    _setDefaultRoyalty(receiver, fee);
}

// 권장: 변경 가능하되 상한선 설정
```

---

## 학습 로드맵

```
초급 (30분) → 중급 (1시간) → 고급 (2시간) → 실전
```

### 🟢 초급: 개념 이해 (30분)
1. [왜 필요한가?](#왜-필요한가) 읽기
2. [동작 원리](#동작-원리-한눈에-보기) 이해
3. [Basis Points](#basis-points-이해하기) 학습

### 🟡 중급: 실습 (1시간)
1. [SimpleRoyaltyNFT](./contracts/SimpleRoyaltyNFT.sol) 배포
2. [마켓플레이스 통합](#마켓플레이스-통합) 이해
3. OpenZeppelin ERC2981 분석

### 🔴 고급: 복잡한 패턴 (2시간)
1. [다중 수령자 패턴](#다중-수령자-패턴) 구현
2. [동적 로열티](./contracts/DynamicRoyaltyNFT.sol) 구현
3. [보안 고려사항](#보안-고려사항) 학습

### 🚀 실전: 프로젝트 적용
- [ ] NFT 프로젝트에 EIP-2981 추가
- [ ] 적정 로열티 비율 결정
- [ ] 마켓플레이스 호환성 테스트
- [ ] 보안 감사 수행

---

## 코드 예제

### 스마트 컨트랙트
- [SimpleRoyaltyNFT.sol](./contracts/SimpleRoyaltyNFT.sol) - 기본 구현
- [DynamicRoyaltyNFT.sol](./contracts/DynamicRoyaltyNFT.sol) - 동적 로열티
- [MultiRecipientRoyalty.sol](./contracts/MultiRecipientRoyalty.sol) - 다중 수령자
- [MarketplaceIntegration.sol](./contracts/MarketplaceIntegration.sol) - 마켓플레이스 예제
- [RoyaltyRegistry.sol](./contracts/RoyaltyRegistry.sol) - 외부 레지스트리
- [RealWorldExamples.sol](./contracts/RealWorldExamples.sol) - 실전 예제

---

## 관련 자료

- [EIP-2981 공식 명세](https://eips.ethereum.org/EIPS/eip-2981)
- [OpenZeppelin ERC2981](https://docs.openzeppelin.com/contracts/4.x/api/token/common#ERC2981)
- [EIP-165: Interface Detection](../EIP-165/README.md)

---

**Happy Creating!**

NFT 창작자들의 권리를 보호하고, 건강한 NFT 생태계를 만들어갑시다.
