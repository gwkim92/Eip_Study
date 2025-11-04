// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleRoyaltyNFT
 * @notice EIP-2981 기본 구현 예제
 * @dev OpenZeppelin의 ERC2981을 사용한 간단한 NFT 컨트랙트
 *
 * 핵심 기능:
 * - 모든 NFT에 동일한 로열티 적용
 * - 로열티 수령자와 비율 변경 가능
 * - 개별 토큰에 대해 다른 로열티 설정 가능
 */
contract SimpleRoyaltyNFT is ERC721, ERC2981, Ownable {
    // ============ State Variables ============

    uint256 private _tokenIdCounter;
    uint96 public constant MAX_ROYALTY_BPS = 1000; // 10% 상한

    string private _baseTokenURI;

    // ============ Events ============

    event RoyaltyUpdated(address indexed receiver, uint96 feeNumerator);
    event TokenRoyaltyUpdated(uint256 indexed tokenId, address indexed receiver, uint96 feeNumerator);

    // ============ Constructor ============

    /**
     * @notice 컨트랙트 배포 및 초기 로열티 설정
     * @param name NFT 컬렉션 이름
     * @param symbol NFT 심볼
     * @param royaltyReceiver 로열티 수령자 주소
     * @param royaltyFeeNumerator 로열티 비율 (basis points, 500 = 5%)
     */
    constructor(
        string memory name,
        string memory symbol,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) ERC721(name, symbol) Ownable(msg.sender) {
        require(royaltyReceiver != address(0), "Invalid receiver");
        require(royaltyFeeNumerator <= MAX_ROYALTY_BPS, "Royalty too high");

        // 기본 로열티 설정 (모든 토큰에 적용)
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);

        emit RoyaltyUpdated(royaltyReceiver, royaltyFeeNumerator);
    }

    // ============ Minting Functions ============

    /**
     * @notice 새로운 NFT 발행
     * @param to NFT 수령자
     * @return tokenId 발행된 토큰 ID
     */
    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice 여러 NFT 일괄 발행
     * @param to NFT 수령자
     * @param amount 발행 수량
     */
    function batchMint(address to, uint256 amount) external onlyOwner {
        require(amount > 0 && amount <= 100, "Invalid amount");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter++;
            _safeMint(to, tokenId);
        }
    }

    // ============ Royalty Management ============

    /**
     * @notice 기본 로열티 설정 변경
     * @param receiver 새로운 로열티 수령자
     * @param feeNumerator 새로운 로열티 비율 (basis points)
     *
     * 예시:
     * - setDefaultRoyalty(artist, 500) → 5% 로열티
     * - setDefaultRoyalty(artist, 250) → 2.5% 로열티
     */
    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        require(receiver != address(0), "Invalid receiver");
        require(feeNumerator <= MAX_ROYALTY_BPS, "Royalty too high");

        _setDefaultRoyalty(receiver, feeNumerator);

        emit RoyaltyUpdated(receiver, feeNumerator);
    }

    /**
     * @notice 특정 토큰의 로열티 설정
     * @param tokenId 토큰 ID
     * @param receiver 로열티 수령자
     * @param feeNumerator 로열티 비율 (basis points)
     *
     * 사용 사례:
     * - 특별한 토큰에 더 높은 로열티 적용
     * - 특정 토큰만 다른 수령자 지정
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(receiver != address(0), "Invalid receiver");
        require(feeNumerator <= MAX_ROYALTY_BPS, "Royalty too high");

        _setTokenRoyalty(tokenId, receiver, feeNumerator);

        emit TokenRoyaltyUpdated(tokenId, receiver, feeNumerator);
    }

    /**
     * @notice 기본 로열티 삭제
     */
    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
        emit RoyaltyUpdated(address(0), 0);
    }

    /**
     * @notice 특정 토큰의 개별 로열티 삭제 (기본값으로 복귀)
     * @param tokenId 토큰 ID
     */
    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        _resetTokenRoyalty(tokenId);
        emit TokenRoyaltyUpdated(tokenId, address(0), 0);
    }

    // ============ View Functions ============

    /**
     * @notice 현재 총 발행된 NFT 수량
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @notice Base URI 조회
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Base URI 설정
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    // ============ EIP-165 Support ============

    /**
     * @notice 인터페이스 지원 여부 확인
     * @dev EIP-2981 및 ERC721 지원을 알림
     */
    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 * ============================================================================
 * 사용 예제
 * ============================================================================
 *
 * 1. 배포:
 * ```javascript
 * const nft = await SimpleRoyaltyNFT.deploy(
 *     "My Art Collection",
 *     "MART",
 *     artistAddress,
 *     500  // 5% 로열티
 * );
 * ```
 *
 * 2. 민팅:
 * ```javascript
 * await nft.mint(collectorAddress);
 * ```
 *
 * 3. 로열티 조회:
 * ```javascript
 * const [receiver, amount] = await nft.royaltyInfo(
 *     tokenId,
 *     ethers.parseEther("10")  // 10 ETH 판매가 가정
 * );
 * console.log("Royalty:", ethers.formatEther(amount), "ETH");
 * ```
 *
 * 4. 로열티 변경:
 * ```javascript
 * // 전체 로열티를 7.5%로 변경
 * await nft.setDefaultRoyalty(artistAddress, 750);
 *
 * // 특정 토큰만 10%로 설정
 * await nft.setTokenRoyalty(tokenId, artistAddress, 1000);
 * ```
 *
 * ============================================================================
 * 마켓플레이스 통합 예제
 * ============================================================================
 *
 * ```solidity
 * contract Marketplace {
 *     function buyNFT(address nftContract, uint256 tokenId) external payable {
 *         // 로열티 확인
 *         (address receiver, uint256 royalty) =
 *             IERC2981(nftContract).royaltyInfo(tokenId, msg.value);
 *
 *         // 로열티 전송
 *         if (royalty > 0) {
 *             payable(receiver).transfer(royalty);
 *         }
 *
 *         // 판매자에게 잔액 전송
 *         uint256 sellerAmount = msg.value - royalty;
 *         payable(seller).transfer(sellerAmount);
 *
 *         // NFT 전송
 *         IERC721(nftContract).transferFrom(seller, msg.sender, tokenId);
 *     }
 * }
 * ```
 *
 * ============================================================================
 * 테스트 코드 예제 (Foundry)
 * ============================================================================
 *
 * ```solidity
 * function testRoyalty() public {
 *     // 5% 로열티 설정으로 배포
 *     SimpleRoyaltyNFT nft = new SimpleRoyaltyNFT(
 *         "Test", "TST", artist, 500
 *     );
 *
 *     // 민팅
 *     nft.mint(collector);
 *
 *     // 로열티 확인 (10 ETH 판매 가정)
 *     (address receiver, uint256 amount) =
 *         nft.royaltyInfo(0, 10 ether);
 *
 *     // 검증
 *     assertEq(receiver, artist);
 *     assertEq(amount, 0.5 ether);  // 5% of 10 ETH
 * }
 * ```
 */
