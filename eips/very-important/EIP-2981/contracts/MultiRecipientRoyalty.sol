// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MultiRecipientRoyaltyNFT
 * @notice 로열티를 여러 수령자에게 자동 분배하는 NFT
 * @dev PaymentSplitter를 사용한 로열티 분배
 */
contract MultiRecipientRoyaltyNFT is ERC721, ERC2981, Ownable {
    uint256 private _tokenIdCounter;
    PaymentSplitter public immutable royaltySplitter;

    event RoyaltyReceived(address indexed from, uint256 amount);
    event RoyaltyWithdrawn(address indexed payee, uint256 amount);

    /**
     * @param name NFT 이름
     * @param symbol NFT 심볼
     * @param payees 로열티 수령자 배열
     * @param shares 각 수령자의 지분 (비율)
     * @param royaltyBps 전체 로열티 비율 (basis points)
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory payees,
        uint256[] memory shares,
        uint96 royaltyBps
    ) ERC721(name, symbol) Ownable(msg.sender) {
        require(payees.length > 0, "No payees");
        require(payees.length == shares.length, "Length mismatch");
        require(royaltyBps <= 1000, "Royalty too high");

        // PaymentSplitter 생성 (로열티 자동 분배)
        royaltySplitter = new PaymentSplitter(payees, shares);

        // 로열티 수령자를 PaymentSplitter로 설정
        _setDefaultRoyalty(address(royaltySplitter), royaltyBps);
    }

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice 수령자가 자신의 몫 인출
     * @param account 인출할 주소
     */
    function releaseRoyalty(address payable account) external {
        uint256 payment = royaltySplitter.releasable(account);
        require(payment > 0, "No payment due");

        royaltySplitter.release(account);
        emit RoyaltyWithdrawn(account, payment);
    }

    /**
     * @notice 특정 수령자의 인출 가능 금액 조회
     */
    function pendingRoyalty(address account) external view returns (uint256) {
        return royaltySplitter.releasable(account);
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 * 사용 예제:
 *
 * // 3명이 로열티 분배 (50%, 30%, 20%)
 * address[] memory payees = new address[](3);
 * payees[0] = artist;      // 50%
 * payees[1] = developer;   // 30%
 * payees[2] = marketer;    // 20%
 *
 * uint256[] memory shares = new uint256[](3);
 * shares[0] = 50;
 * shares[1] = 30;
 * shares[2] = 20;
 *
 * MultiRecipientRoyaltyNFT nft = new MultiRecipientRoyaltyNFT(
 *     "Collaborative Art",
 *     "CART",
 *     payees,
 *     shares,
 *     500  // 총 5% 로열티
 * );
 *
 * // 각자 인출
 * nft.releaseRoyalty(payable(artist));
 * nft.releaseRoyalty(payable(developer));
 */
