// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title NFTMarketplace
 * @notice EIP-2981 로열티를 자동으로 처리하는 마켓플레이스
 */
contract NFTMarketplace is ReentrancyGuard {
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;
    uint256 public platformFee = 250; // 2.5%
    address public platformAddress;

    event NFTListed(address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address buyer, uint256 price);
    event RoyaltyPaid(address indexed receiver, uint256 amount);

    constructor() {
        platformAddress = msg.sender;
    }

    /**
     * @notice NFT 리스팅
     */
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Invalid price");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        emit NFTListed(nftContract, tokenId, price);
    }

    /**
     * @notice NFT 구매 (로열티 자동 처리)
     */
    function buyNFT(address nftContract, uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.active, "Not listed");
        require(msg.value >= listing.price, "Insufficient payment");

        uint256 royaltyAmount = 0;
        address royaltyReceiver;

        // EIP-2981 지원 확인 및 로열티 처리
        if (IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)) {
            (royaltyReceiver, royaltyAmount) =
                IERC2981(nftContract).royaltyInfo(tokenId, listing.price);

            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                (bool royaltySuccess, ) = royaltyReceiver.call{value: royaltyAmount}("");
                require(royaltySuccess, "Royalty transfer failed");
                emit RoyaltyPaid(royaltyReceiver, royaltyAmount);
            }
        }

        // 플랫폼 수수료
        uint256 platformAmount = (listing.price * platformFee) / 10000;
        (bool platformSuccess, ) = platformAddress.call{value: platformAmount}("");
        require(platformSuccess, "Platform fee failed");

        // 판매자에게 잔액 전송
        uint256 sellerAmount = listing.price - royaltyAmount - platformAmount;
        (bool sellerSuccess, ) = listing.seller.call{value: sellerAmount}("");
        require(sellerSuccess, "Seller transfer failed");

        // NFT 전송
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // 리스팅 제거
        listings[nftContract][tokenId].active = false;

        emit NFTSold(nftContract, tokenId, msg.sender, listing.price);
    }

    /**
     * @notice 판매 시 예상 분배 금액 계산
     */
    function calculatePaymentDistribution(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (
        uint256 royaltyAmount,
        uint256 platformAmount,
        uint256 sellerAmount,
        address royaltyReceiver
    ) {
        // 로열티
        if (IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)) {
            (royaltyReceiver, royaltyAmount) =
                IERC2981(nftContract).royaltyInfo(tokenId, salePrice);
        }

        // 플랫폼 수수료
        platformAmount = (salePrice * platformFee) / 10000;

        // 판매자
        sellerAmount = salePrice - royaltyAmount - platformAmount;

        return (royaltyAmount, platformAmount, sellerAmount, royaltyReceiver);
    }
}
