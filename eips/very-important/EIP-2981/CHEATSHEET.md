# EIP-2981 Cheatsheet

> **빠른 참고**: NFT 로열티 표준 핵심 정리

## 핵심 인터페이스

```solidity
interface IERC2981 {
    /// @notice 로열티 정보 조회
    /// @param tokenId NFT 토큰 ID
    /// @param salePrice 판매 가격 (wei)
    /// @return receiver 로열티 수령자
    /// @return royaltyAmount 로열티 금액 (wei)
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}

// Interface ID
type(IERC2981).interfaceId = 0x2a55205a
```

---

## Basis Points 빠른 참조

```solidity
// 10000 = 100%
250   = 2.5%   // OpenSea 초기 기본값
500   = 5%     // 일반적인 설정
750   = 7.5%   // 높은 편
1000  = 10%    // 최대 권장
1500  = 15%    // 매우 높음 (비권장)

// 계산 공식
royaltyAmount = salePrice * basisPoints / 10000;
```

---

## 일반적인 로열티 비율

```
┌──────────────────┬─────────────┬──────────┐
│ NFT 타입         │ 권장 로열티 │ Basis Pts│
├──────────────────┼─────────────┼──────────┤
│ Art NFTs         │ 5-10%       │ 500-1000 │
│ Music NFTs       │ 10-15%      │ 1000-1500│
│ Gaming Items     │ 2.5-5%      │ 250-500  │
│ PFP Projects     │ 5-7.5%      │ 500-750  │
│ Metaverse Land   │ 2.5-5%      │ 250-500  │
└──────────────────┴─────────────┴──────────┘
```

---

## 기본 구현 (OpenZeppelin)

```solidity
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, ERC2981, Ownable {
    constructor()
        ERC721("MyNFT", "MNFT")
        Ownable(msg.sender)
    {
        // 5% 로열티 설정
        _setDefaultRoyalty(msg.sender, 500);
    }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    // EIP-165 지원 필수
    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## 로열티 설정 패턴

### 1. 기본 로열티 (모든 토큰 동일)

```solidity
constructor() {
    // 모든 NFT에 5% 로열티
    _setDefaultRoyalty(artistAddress, 500);
}
```

### 2. 토큰별 개별 로열티

```solidity
function mintSpecial(address to, uint256 tokenId) external {
    _safeMint(to, tokenId);
    // 이 토큰만 10% 로열티
    _setTokenRoyalty(tokenId, specialArtist, 1000);
}
```

### 3. 로열티 변경

```solidity
function updateRoyalty(address newReceiver, uint96 newFee)
    external onlyOwner
{
    require(newFee <= 1000, "Max 10%"); // 상한선 설정
    _setDefaultRoyalty(newReceiver, newFee);
}
```

### 4. 로열티 삭제

```solidity
function removeRoyalty() external onlyOwner {
    _deleteDefaultRoyalty();
}

function removeTokenRoyalty(uint256 tokenId) external onlyOwner {
    _resetTokenRoyalty(tokenId);
}
```

---

## 마켓플레이스 통합 코드

### 판매 시 로열티 지급

```solidity
function buyNFT(address nftContract, uint256 tokenId)
    external payable
{
    uint256 price = listings[nftContract][tokenId].price;
    address seller = listings[nftContract][tokenId].seller;

    // 1. EIP-2981 지원 확인
    if (IERC165(nftContract).supportsInterface(0x2a55205a)) {
        // 2. 로열티 조회
        (address receiver, uint256 royalty) =
            IERC2981(nftContract).royaltyInfo(tokenId, price);

        // 3. 로열티 전송
        if (royalty > 0 && receiver != address(0)) {
            payable(receiver).transfer(royalty);
        }

        // 4. 판매자에게 잔액 전송
        payable(seller).transfer(price - royalty);
    } else {
        // 로열티 없음
        payable(seller).transfer(price);
    }

    // 5. NFT 전송
    IERC721(nftContract).transferFrom(seller, msg.sender, tokenId);
}
```

---

## 로열티 계산 예제

```solidity
// 판매가: 10 ETH, 로열티: 5%
salePrice = 10 ether;
royaltyBps = 500;

royaltyAmount = (10 ether * 500) / 10000
              = 0.5 ether

// 분배:
// - 창작자: 0.5 ETH (로열티)
// - 마켓: 0.25 ETH (수수료 2.5%)
// - 판매자: 9.25 ETH (순수익)
```

---

## 다중 수령자 패턴

```solidity
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract MultiRoyaltyNFT is ERC721, ERC2981, Ownable {
    PaymentSplitter public splitter;

    constructor() ERC721("Multi", "MLT") Ownable(msg.sender) {
        // 3명이 로열티 분배
        address[] memory payees = new address[](3);
        payees[0] = artist;
        payees[1] = developer;
        payees[2] = marketer;

        uint256[] memory shares = new uint256[](3);
        shares[0] = 50;  // 50%
        shares[1] = 30;  // 30%
        shares[2] = 20;  // 20%

        splitter = new PaymentSplitter(payees, shares);
        _setDefaultRoyalty(address(splitter), 500); // 총 5%
    }

    // 각자 인출
    function withdraw(address payee) external {
        splitter.release(payable(payee));
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

## 동적 로열티 패턴

### 시간 기반 감소

```solidity
function royaltyInfo(uint256, uint256 salePrice)
    public view override returns (address, uint256)
{
    uint256 elapsed = block.timestamp - launchTime;
    uint96 currentBps;

    if (elapsed < 30 days) {
        currentBps = 1000;  // 10% (첫 달)
    } else if (elapsed < 180 days) {
        currentBps = 750;   // 7.5% (6개월까지)
    } else {
        currentBps = 500;   // 5% (이후)
    }

    return (owner(), (salePrice * currentBps) / 10000);
}
```

### 가격 기반 차등

```solidity
function royaltyInfo(uint256, uint256 salePrice)
    public view override returns (address, uint256)
{
    uint96 bps;

    if (salePrice < 1 ether) {
        bps = 250;    // 2.5%
    } else if (salePrice < 10 ether) {
        bps = 500;    // 5%
    } else {
        bps = 1000;   // 10%
    }

    return (owner(), (salePrice * bps) / 10000);
}
```

---

## 보안 체크리스트

```solidity
// ✅ 1. 로열티 상한선 설정
uint96 public constant MAX_ROYALTY = 1000; // 10%

function setRoyalty(address receiver, uint96 fee) external onlyOwner {
    require(fee <= MAX_ROYALTY, "Too high");
    require(receiver != address(0), "Zero address");
    _setDefaultRoyalty(receiver, fee);
}

// ✅ 2. 오버플로우 방지 (Solidity 0.8+)
// 자동으로 처리됨

// ✅ 3. 재진입 공격 방지
function buyNFT(address nft, uint256 id) external payable nonReentrant {
    // ...
}

// ✅ 4. Zero address 체크
require(receiver != address(0), "Invalid receiver");

// ✅ 5. EIP-165 구현
function supportsInterface(bytes4 interfaceId)
    public view virtual override(ERC721, ERC2981)
    returns (bool)
{
    return super.supportsInterface(interfaceId);
}
```

---

## 일반적인 실수와 해결

### ❌ 실수 1: supportsInterface 미구현

```solidity
// 잘못된 예
contract BadNFT is ERC721, ERC2981 {
    // supportsInterface 오버라이드 안함
}

// 올바른 예
contract GoodNFT is ERC721, ERC2981 {
    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### ❌ 실수 2: 로열티 비율 너무 높음

```solidity
// 위험: 30% 로열티
_setDefaultRoyalty(owner(), 3000); // 거래 감소!

// 권장: 10% 이하
_setDefaultRoyalty(owner(), 500);  // 5%
```

### ❌ 실수 3: 계산 순서 오류

```solidity
// 잘못된 계산 (정밀도 손실)
uint256 bad = (salePrice / 10000) * bps;

// 올바른 계산 (곱셈 먼저)
uint256 good = (salePrice * bps) / 10000;
```

---

## 디버깅 팁

### 로열티 정보 조회

```solidity
// 1 ETH 판매 시 로열티 확인
(address receiver, uint256 amount) =
    nft.royaltyInfo(tokenId, 1 ether);

console.log("Receiver:", receiver);
console.log("Royalty:", amount);
```

### EIP-2981 지원 확인

```solidity
bool supported = IERC165(nftAddress).supportsInterface(0x2a55205a);
console.log("EIP-2981 supported:", supported);
```

### 로열티 비율 역계산

```solidity
// 로열티 금액으로 비율 계산
uint256 royaltyBps = (royaltyAmount * 10000) / salePrice;
console.log("Royalty %:", royaltyBps / 100);
```

---

## 마켓플레이스 호환성 체크

```javascript
// JavaScript/ethers.js
const nft = await ethers.getContractAt("IERC721", nftAddress);

// EIP-2981 지원 확인
const supported = await nft.supportsInterface("0x2a55205a");

if (supported) {
    // 로열티 정보 가져오기
    const [receiver, royalty] = await nft.royaltyInfo(
        tokenId,
        ethers.parseEther("10") // 10 ETH 가정
    );

    console.log("Royalty Receiver:", receiver);
    console.log("Royalty Amount:", ethers.formatEther(royalty), "ETH");
}
```

---

## 빠른 배포 체크리스트

- [ ] `ERC721` 상속
- [ ] `ERC2981` 상속
- [ ] `Ownable` 상속 (권한 관리)
- [ ] `constructor`에서 `_setDefaultRoyalty()` 호출
- [ ] `supportsInterface()` 오버라이드
- [ ] 로열티 상한선 설정 (권장: 10%)
- [ ] Zero address 체크
- [ ] 테스트 코드 작성
- [ ] 마켓플레이스 호환성 테스트

---

## 유용한 상수

```solidity
// Interface IDs
bytes4 constant IERC165_ID = 0x01ffc9a7;
bytes4 constant IERC721_ID = 0x80ac58cd;
bytes4 constant IERC2981_ID = 0x2a55205a;

// 일반적인 로열티
uint96 constant ROYALTY_2_5_PCT = 250;
uint96 constant ROYALTY_5_PCT = 500;
uint96 constant ROYALTY_7_5_PCT = 750;
uint96 constant ROYALTY_10_PCT = 1000;

// 분모
uint96 constant BPS_DENOMINATOR = 10000;
```

---

## 추가 참고

- [완전한 가이드](./README.md)
- [SimpleRoyaltyNFT.sol](./contracts/SimpleRoyaltyNFT.sol)
- [DynamicRoyaltyNFT.sol](./contracts/DynamicRoyaltyNFT.sol)
- [MultiRecipientRoyalty.sol](./contracts/MultiRecipientRoyalty.sol)
- [EIP-2981 명세](https://eips.ethereum.org/EIPS/eip-2981)
- [OpenZeppelin Docs](https://docs.openzeppelin.com/contracts/4.x/api/token/common#ERC2981)
