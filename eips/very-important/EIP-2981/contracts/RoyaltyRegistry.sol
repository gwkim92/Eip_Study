// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RoyaltyRegistry
 * @notice 외부 로열티 레지스트리 패턴
 * @dev NFT 컨트랙트 외부에서 로열티 관리
 */
contract RoyaltyRegistry is Ownable {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyBps;
    }

    // nftContract => tokenId => RoyaltyInfo
    mapping(address => mapping(uint256 => RoyaltyInfo)) private _tokenRoyalties;

    // nftContract => default RoyaltyInfo
    mapping(address => RoyaltyInfo) private _defaultRoyalties;

    event RoyaltySet(address indexed nftContract, uint256 indexed tokenId, address receiver, uint96 royaltyBps);
    event DefaultRoyaltySet(address indexed nftContract, address receiver, uint96 royaltyBps);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice 로열티 정보 조회
     */
    function royaltyInfo(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        RoyaltyInfo memory info = _tokenRoyalties[nftContract][tokenId];

        // 토큰별 로열티가 없으면 기본값 사용
        if (info.receiver == address(0)) {
            info = _defaultRoyalties[nftContract];
        }

        receiver = info.receiver;
        royaltyAmount = (salePrice * info.royaltyBps) / 10000;
    }

    /**
     * @notice 기본 로열티 설정
     */
    function setDefaultRoyalty(
        address nftContract,
        address receiver,
        uint96 royaltyBps
    ) external onlyOwner {
        require(royaltyBps <= 1000, "Too high");
        _defaultRoyalties[nftContract] = RoyaltyInfo(receiver, royaltyBps);
        emit DefaultRoyaltySet(nftContract, receiver, royaltyBps);
    }

    /**
     * @notice 토큰별 로열티 설정
     */
    function setTokenRoyalty(
        address nftContract,
        uint256 tokenId,
        address receiver,
        uint96 royaltyBps
    ) external onlyOwner {
        require(royaltyBps <= 1000, "Too high");
        _tokenRoyalties[nftContract][tokenId] = RoyaltyInfo(receiver, royaltyBps);
        emit RoyaltySet(nftContract, tokenId, receiver, royaltyBps);
    }
}
