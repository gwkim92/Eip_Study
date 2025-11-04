// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// ============================================================================
// 실전 예제 1: 아트 NFT 컬렉션
// ============================================================================

contract ArtNFTCollection is ERC721, ERC2981, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MINT_PRICE = 0.08 ether;
    uint256 private _tokenIdCounter;

    string private _baseTokenURI;
    address public artist;

    event Minted(address indexed to, uint256 indexed tokenId);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address _artist
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenURI = baseURI;
        artist = _artist;
        _setDefaultRoyalty(_artist, 750); // 7.5%
    }

    function mint() external payable returns (uint256) {
        require(_tokenIdCounter < MAX_SUPPLY, "Sold out");
        require(msg.value >= MINT_PRICE, "Insufficient payment");

        uint256 tokenId = _tokenIdCounter++;
        _safeMint(msg.sender, tokenId);

        emit Minted(msg.sender, tokenId);
        return tokenId;
    }

    function withdraw() external {
        uint256 balance = address(this).balance;
        uint256 artistAmount = (balance * 90) / 100;
        uint256 platformAmount = balance - artistAmount;

        payable(artist).transfer(artistAmount);
        payable(owner()).transfer(platformAmount);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

// ============================================================================
// 실전 예제 2: 음악 NFT 플랫폼
// ============================================================================

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
        address indexed musician
    );

    constructor() ERC721("Music NFT", "MUSIC") Ownable(msg.sender) {}

    function mintTrack(
        address musician,
        string memory title,
        string memory artist,
        string memory ipfsHash,
        uint256 duration
    ) external onlyOwner returns (uint256) {
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

        emit TrackMinted(tokenId, title, musician);
        return tokenId;
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

// ============================================================================
// 실전 예제 3: 게임 아이템 NFT
// ============================================================================

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

    event ItemMinted(
        uint256 indexed tokenId,
        ItemType itemType,
        Rarity rarity,
        uint256 power
    );

    constructor(address _gameStudio)
        ERC721("Game Item", "ITEM")
        Ownable(msg.sender)
    {
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

        uint96 royalty = getRoyaltyByRarity(rarity);
        _setTokenRoyalty(tokenId, gameStudio, royalty);

        emit ItemMinted(tokenId, itemType, rarity, power);
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
        public view override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 * ============================================================================
 * 사용 시나리오
 * ============================================================================
 *
 * 1. 아트 컬렉션:
 * const art = await ArtNFTCollection.deploy(
 *     "Pixel Art Collection",
 *     "PIXEL",
 *     "ipfs://QmHash/",
 *     artistAddress
 * );
 * await art.mint({ value: ethers.parseEther("0.08") });
 *
 * 2. 음악 NFT:
 * const music = await MusicNFT.deploy();
 * await music.mintTrack(
 *     musicianAddress,
 *     "My Song",
 *     "Artist Name",
 *     "ipfs://QmMusicHash",
 *     180  // 3 minutes
 * );
 *
 * 3. 게임 아이템:
 * const game = await GameItemNFT.deploy(studioAddress);
 * await game.mintItem(
 *     playerAddress,
 *     0,  // Weapon
 *     4,  // Legendary
 *     1000  // Power
 * );
 */
