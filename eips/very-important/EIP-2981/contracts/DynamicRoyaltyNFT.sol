// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DynamicRoyaltyNFT
 * @notice 조건에 따라 로열티가 변하는 NFT
 * @dev 시간, 가격, 거래 횟수 등 다양한 조건으로 로열티 동적 조정
 *
 * 패턴 예시:
 * 1. 시간 기반: 시간이 지날수록 로열티 감소
 * 2. 가격 기반: 판매가에 따라 로열티 비율 차등
 * 3. 거래 횟수 기반: 거래가 많을수록 로열티 감소
 */

// ============================================================================
// Pattern 1: 시간 기반 로열티 감소
// ============================================================================

contract TimeDecayRoyaltyNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    uint256 public immutable launchTime;

    // 로열티 설정
    uint256 public constant INITIAL_ROYALTY = 1000;  // 10%
    uint256 public constant FINAL_ROYALTY = 250;     // 2.5%
    uint256 public constant DECAY_PERIOD = 365 days; // 1년

    event RoyaltyDecayed(uint256 currentRoyalty, uint256 elapsed);

    constructor() ERC721("Time Decay NFT", "TDNFT") Ownable(msg.sender) {
        launchTime = block.timestamp;
    }

    /**
     * @notice 시간에 따라 선형으로 감소하는 로열티
     * @dev 1년에 걸쳐 10% → 2.5%로 감소
     */
    function royaltyInfo(uint256, uint256 salePrice)
        external view returns (address, uint256)
    {
        uint256 elapsed = block.timestamp - launchTime;
        uint96 currentRoyalty;

        if (elapsed >= DECAY_PERIOD) {
            currentRoyalty = uint96(FINAL_ROYALTY);
        } else {
            // 선형 감소: y = INITIAL - (INITIAL - FINAL) * elapsed / PERIOD
            uint256 decrease = (INITIAL_ROYALTY - FINAL_ROYALTY) * elapsed / DECAY_PERIOD;
            currentRoyalty = uint96(INITIAL_ROYALTY - decrease);
        }

        uint256 royaltyAmount = (salePrice * currentRoyalty) / 10000;
        return (owner(), royaltyAmount);
    }

    /**
     * @notice 현재 로열티 비율 조회 (basis points)
     */
    function getCurrentRoyaltyBps() external view returns (uint96) {
        uint256 elapsed = block.timestamp - launchTime;

        if (elapsed >= DECAY_PERIOD) {
            return uint96(FINAL_ROYALTY);
        }

        uint256 decrease = (INITIAL_ROYALTY - FINAL_ROYALTY) * elapsed / DECAY_PERIOD;
        return uint96(INITIAL_ROYALTY - decrease);
    }

    function mint(address to) external onlyOwner {
        _safeMint(to, _tokenIdCounter++);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}

// ============================================================================
// Pattern 2: 가격 기반 계층별 로열티
// ============================================================================

contract TieredPriceRoyaltyNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    event RoyaltyTierApplied(uint256 salePrice, uint96 royaltyBps);

    constructor() ERC721("Tiered Royalty NFT", "TRNFT") Ownable(msg.sender) {}

    /**
     * @notice 판매가에 따라 로열티 차등 적용
     * @dev 고액 거래일수록 높은 로열티
     *
     * 계층:
     * - < 1 ETH: 2.5%
     * - 1-10 ETH: 5%
     * - 10-100 ETH: 7.5%
     * - > 100 ETH: 10%
     */
    function royaltyInfo(uint256, uint256 salePrice)
        external view returns (address, uint256)
    {
        uint96 royaltyBps;

        if (salePrice < 1 ether) {
            royaltyBps = 250;    // 2.5%
        } else if (salePrice < 10 ether) {
            royaltyBps = 500;    // 5%
        } else if (salePrice < 100 ether) {
            royaltyBps = 750;    // 7.5%
        } else {
            royaltyBps = 1000;   // 10%
        }

        uint256 royaltyAmount = (salePrice * royaltyBps) / 10000;
        return (owner(), royaltyAmount);
    }

    function mint(address to) external onlyOwner {
        _safeMint(to, _tokenIdCounter++);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}

// ============================================================================
// Pattern 3: 거래 횟수 기반 로열티
// ============================================================================

contract TransferCountRoyaltyNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    // 토큰별 거래 횟수 추적
    mapping(uint256 => uint256) public transferCount;

    event TransferCounted(uint256 indexed tokenId, uint256 count);

    constructor() ERC721("Transfer Count NFT", "TCNFT") Ownable(msg.sender) {}

    /**
     * @notice 거래 횟수에 따라 로열티 감소
     * @dev 거래가 많을수록 로열티 낮춤 (유동성 증가 유도)
     *
     * 비율:
     * - 첫 거래: 10%
     * - 2-5회: 7.5%
     * - 6-10회: 5%
     * - 10회 이상: 2.5%
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external view returns (address, uint256)
    {
        uint256 count = transferCount[tokenId];
        uint96 royaltyBps;

        if (count == 0) {
            royaltyBps = 1000;   // 첫 거래: 10%
        } else if (count < 5) {
            royaltyBps = 750;    // 2-5회: 7.5%
        } else if (count < 10) {
            royaltyBps = 500;    // 6-10회: 5%
        } else {
            royaltyBps = 250;    // 10회 이상: 2.5%
        }

        uint256 royaltyAmount = (salePrice * royaltyBps) / 10000;
        return (owner(), royaltyAmount);
    }

    /**
     * @notice 토큰 전송 시 카운터 증가
     */
    function _update(address to, uint256 tokenId, address auth)
        internal virtual override
        returns (address)
    {
        address from = super._update(to, tokenId, auth);

        // 민팅과 소각이 아닌 일반 전송인 경우만 카운트
        if (from != address(0) && to != address(0)) {
            transferCount[tokenId]++;
            emit TransferCounted(tokenId, transferCount[tokenId]);
        }

        return from;
    }

    function mint(address to) external onlyOwner {
        _safeMint(to, _tokenIdCounter++);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}

// ============================================================================
// Pattern 4: 희귀도 기반 로열티
// ============================================================================

contract RarityBasedRoyaltyNFT is ERC721, Ownable {
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary }

    uint256 private _tokenIdCounter;
    mapping(uint256 => Rarity) public tokenRarity;

    event TokenMintedWithRarity(uint256 indexed tokenId, Rarity rarity, uint96 royalty);

    constructor() ERC721("Rarity NFT", "RNFT") Ownable(msg.sender) {}

    /**
     * @notice 희귀도별 로열티
     * @dev 희귀할수록 높은 로열티
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external view returns (address, uint256)
    {
        uint96 royaltyBps = getRoyaltyByRarity(tokenRarity[tokenId]);
        uint256 royaltyAmount = (salePrice * royaltyBps) / 10000;
        return (owner(), royaltyAmount);
    }

    /**
     * @notice 희귀도에 따른 로열티 비율 계산
     */
    function getRoyaltyByRarity(Rarity rarity) public pure returns (uint96) {
        if (rarity == Rarity.Common) return 100;        // 1%
        if (rarity == Rarity.Uncommon) return 250;      // 2.5%
        if (rarity == Rarity.Rare) return 500;          // 5%
        if (rarity == Rarity.Epic) return 750;          // 7.5%
        return 1000;  // Legendary: 10%
    }

    /**
     * @notice 희귀도와 함께 민팅
     */
    function mintWithRarity(address to, Rarity rarity) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);

        tokenRarity[tokenId] = rarity;

        emit TokenMintedWithRarity(tokenId, rarity, getRoyaltyByRarity(rarity));
        return tokenId;
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}

// ============================================================================
// Pattern 5: 성과 기반 로열티
// ============================================================================

contract PerformanceRoyaltyNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    // 토큰별 최고 판매가 추적
    mapping(uint256 => uint256) public highestSalePrice;

    event HighestPriceUpdated(uint256 indexed tokenId, uint256 price);
    event PerformanceBonusApplied(uint256 indexed tokenId, uint96 bonusRoyalty);

    constructor() ERC721("Performance NFT", "PNFT") Ownable(msg.sender) {}

    /**
     * @notice 최고가 갱신 시 더 높은 로열티
     * @dev 작품 가치 상승 시 창작자에게 더 많은 보상
     *
     * 로직:
     * - 최고가 갱신: 10%
     * - 최고가의 80% 이상: 5%
     * - 그 외: 2.5%
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external view returns (address, uint256)
    {
        uint256 highest = highestSalePrice[tokenId];
        uint96 royaltyBps;

        if (salePrice > highest) {
            // 최고가 갱신: 프리미엄 로열티
            royaltyBps = 1000;  // 10%
        } else if (salePrice >= (highest * 80) / 100) {
            // 최고가의 80% 이상: 표준 로열티
            royaltyBps = 500;   // 5%
        } else {
            // 그 외: 최소 로열티
            royaltyBps = 250;   // 2.5%
        }

        uint256 royaltyAmount = (salePrice * royaltyBps) / 10000;
        return (owner(), royaltyAmount);
    }

    /**
     * @notice 판매 기록 업데이트
     * @dev 마켓플레이스가 호출
     */
    function recordSale(uint256 tokenId, uint256 price) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        if (price > highestSalePrice[tokenId]) {
            highestSalePrice[tokenId] = price;
            emit HighestPriceUpdated(tokenId, price);
        }
    }

    function mint(address to) external onlyOwner {
        _safeMint(to, _tokenIdCounter++);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}

/**
 * ============================================================================
 * 사용 예제
 * ============================================================================
 *
 * 1. 시간 기반 로열티:
 * ```javascript
 * const nft = await TimeDecayRoyaltyNFT.deploy();
 *
 * // 배포 직후: 10% 로열티
 * // 6개월 후: 6.25% 로열티
 * // 1년 후: 2.5% 로열티
 *
 * const currentBps = await nft.getCurrentRoyaltyBps();
 * console.log("Current royalty:", currentBps / 100, "%");
 * ```
 *
 * 2. 가격 기반 로열티:
 * ```javascript
 * const nft = await TieredPriceRoyaltyNFT.deploy();
 *
 * // 0.5 ETH 판매: 2.5% 로열티
 * const [receiver1, amount1] = await nft.royaltyInfo(0, ethers.parseEther("0.5"));
 *
 * // 50 ETH 판매: 7.5% 로열티
 * const [receiver2, amount2] = await nft.royaltyInfo(0, ethers.parseEther("50"));
 * ```
 *
 * 3. 거래 횟수 기반:
 * ```javascript
 * const nft = await TransferCountRoyaltyNFT.deploy();
 * await nft.mint(collector1);
 *
 * // 첫 거래: 10%
 * await nft.transferFrom(collector1, collector2, tokenId);
 *
 * // 5번째 거래: 7.5%
 * // 10번째 거래: 5%
 *
 * const count = await nft.transferCount(tokenId);
 * console.log("Transfer count:", count);
 * ```
 *
 * 4. 희귀도 기반:
 * ```javascript
 * const nft = await RarityBasedRoyaltyNFT.deploy();
 *
 * // Common (1%), Rare (5%), Legendary (10%) 민팅
 * await nft.mintWithRarity(collector, 0); // Common
 * await nft.mintWithRarity(collector, 2); // Rare
 * await nft.mintWithRarity(collector, 4); // Legendary
 * ```
 */
