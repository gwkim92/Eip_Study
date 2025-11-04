// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EIP2981Example
 * @dev EIP-2981 NFT Royalty Standard 구현 예제
 *
 * EIP-2981은 NFT 판매 시 로열티 정보를 표준화된 방식으로 제공합니다.
 * 마켓플레이스는 이 표준을 통해 자동으로 로열티를 계산하고 지불할 수 있습니다.
 *
 * EIP-2981 allows NFTs to communicate royalty payment information in a standardized way.
 * Marketplaces can automatically calculate and pay royalties using this standard.
 */

/**
 * @dev ERC165 인터페이스 (Interface Detection)
 */
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @dev ERC-2981 표준 인터페이스
 * ERC-2981 Standard Interface
 */
interface IERC2981 is IERC165 {
    /**
     * @dev 로열티 정보를 반환
     * Returns royalty information
     *
     * @param tokenId 토큰 ID / Token ID
     * @param salePrice 판매 가격 (wei 단위) / Sale price in wei
     * @return receiver 로열티 수령자 주소 / Royalty receiver address
     * @return royaltyAmount 로열티 금액 (wei 단위) / Royalty amount in wei
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

/**
 * @title BasicERC2981
 * @dev 모든 토큰에 대해 동일한 로열티를 적용하는 기본 구현
 * Basic implementation with same royalty for all tokens
 */
contract BasicERC2981 is IERC2981 {
    // 기본 로열티 수령자 / Default royalty receiver
    address private _defaultRoyaltyReceiver;

    // 기본 로열티 비율 (basis points, 10000 = 100%)
    // Default royalty percentage (10000 = 100%)
    uint96 private _defaultRoyaltyFraction;

    // 로열티 정보 변경 이벤트
    event DefaultRoyaltySet(address indexed receiver, uint96 feeNumerator);

    /**
     * @dev 생성자: 기본 로열티 설정
     * Constructor: Set default royalty
     *
     * @param receiver 로열티 수령자 / Royalty receiver
     * @param feeNumerator 로열티 비율 (basis points) / Royalty in basis points
     */
    constructor(address receiver, uint96 feeNumerator) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev ERC-165 인터페이스 지원 확인
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 로열티 정보 반환
     */
    function royaltyInfo(uint256 /* tokenId */, uint256 salePrice)
        public
        view
        virtual
        override
        returns (address, uint256)
    {
        uint256 royaltyAmount = (salePrice * _defaultRoyaltyFraction) / 10000;
        return (_defaultRoyaltyReceiver, royaltyAmount);
    }

    /**
     * @dev 기본 로열티 설정 (내부 함수)
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= 10000, "ERC2981: royalty fee too high");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyReceiver = receiver;
        _defaultRoyaltyFraction = feeNumerator;

        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    /**
     * @dev 현재 로열티 설정 조회 (헬퍼 함수)
     */
    function getDefaultRoyalty() public view returns (address, uint96) {
        return (_defaultRoyaltyReceiver, _defaultRoyaltyFraction);
    }
}

/**
 * @title AdvancedERC2981
 * @dev 토큰별로 다른 로열티를 설정할 수 있는 고급 구현
 * Advanced implementation with per-token royalty settings
 */
contract AdvancedERC2981 is IERC2981 {
    // 토큰별 로열티 정보 구조체
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    // 기본 로열티 정보
    RoyaltyInfo private _defaultRoyaltyInfo;

    // 토큰 ID별 로열티 정보
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    // 이벤트
    event DefaultRoyaltySet(address indexed receiver, uint96 feeNumerator);
    event TokenRoyaltySet(uint256 indexed tokenId, address indexed receiver, uint96 feeNumerator);
    event TokenRoyaltyReset(uint256 indexed tokenId);

    constructor(address defaultReceiver, uint96 defaultFeeNumerator) {
        _setDefaultRoyalty(defaultReceiver, defaultFeeNumerator);
    }

    /**
     * @dev ERC-165 인터페이스 지원 확인
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 로열티 정보 반환
     * 토큰별 설정이 있으면 그것을 사용하고, 없으면 기본값 사용
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        virtual
        override
        returns (address, uint256)
    {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (salePrice * royalty.royaltyFraction) / 10000;

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev 기본 로열티 설정
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= 10000, "ERC2981: royalty fee too high");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    /**
     * @dev 특정 토큰의 로열티 설정
     */
    function _setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator)
        internal
        virtual
    {
        require(feeNumerator <= 10000, "ERC2981: royalty fee too high");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
        emit TokenRoyaltySet(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev 특정 토큰의 로열티 설정 제거 (기본값 사용)
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
        emit TokenRoyaltyReset(tokenId);
    }

    /**
     * @dev 토큰별 로열티 정보 조회 (헬퍼 함수)
     */
    function getTokenRoyalty(uint256 tokenId) public view returns (address, uint96) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[tokenId];
        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }
        return (royalty.receiver, royalty.royaltyFraction);
    }
}

/**
 * @title SimpleNFTWithRoyalty
 * @dev 로열티 기능이 있는 간단한 NFT 컨트랙트
 * Simple NFT contract with royalty support
 */
contract SimpleNFTWithRoyalty is AdvancedERC2981 {
    // NFT 소유자 정보
    mapping(uint256 => address) private _owners;

    // 다음 토큰 ID
    uint256 private _nextTokenId;

    // 이벤트
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Minted(address indexed to, uint256 indexed tokenId);

    constructor() AdvancedERC2981(msg.sender, 250) {
        // 기본 로열티: 2.5% (250 basis points)
    }

    /**
     * @dev NFT 발행
     */
    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _owners[tokenId] = to;

        emit Minted(to, tokenId);
        emit Transfer(address(0), to, tokenId);

        return tokenId;
    }

    /**
     * @dev 특정 NFT에 대해 커스텀 로열티 설정
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator)
        external
    {
        require(_owners[tokenId] == msg.sender, "Not token owner");
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev NFT 소유자 조회
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Token does not exist");
        return owner;
    }
}

/**
 * @title RoyaltyPaymentSplitter
 * @dev 로열티를 여러 수령자에게 분배하는 컨트랙트
 * Contract to split royalty payments among multiple receivers
 */
contract RoyaltyPaymentSplitter {
    // 수령자 정보
    struct Payee {
        address account;
        uint256 shares;
    }

    Payee[] private _payees;
    uint256 private _totalShares;

    // 수령자별 누적 지급액
    mapping(address => uint256) private _released;
    uint256 private _totalReleased;

    // 이벤트
    event PaymentReleased(address indexed to, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);

    /**
     * @dev 생성자: 수령자와 지분 설정
     */
    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "Payees and shares length mismatch");
        require(payees.length > 0, "No payees");

        for (uint256 i = 0; i < payees.length; i++) {
            require(payees[i] != address(0), "Invalid payee");
            require(shares_[i] > 0, "Shares must be > 0");

            _payees.push(Payee(payees[i], shares_[i]));
            _totalShares += shares_[i];
        }
    }

    /**
     * @dev 이더 수령
     */
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev 특정 수령자에게 로열티 지급
     */
    function release(address payable account) public {
        uint256 payment = releasable(account);
        require(payment > 0, "No payment due");

        _released[account] += payment;
        _totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success, "Transfer failed");

        emit PaymentReleased(account, payment);
    }

    /**
     * @dev 지급 가능한 금액 계산
     */
    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 payment = (totalReceived * shares(account)) / _totalShares - _released[account];
        return payment;
    }

    /**
     * @dev 수령자의 지분 조회
     */
    function shares(address account) public view returns (uint256) {
        for (uint256 i = 0; i < _payees.length; i++) {
            if (_payees[i].account == account) {
                return _payees[i].shares;
            }
        }
        return 0;
    }

    /**
     * @dev 수령자 정보 조회
     */
    function payee(uint256 index) public view returns (address, uint256) {
        require(index < _payees.length, "Invalid index");
        return (_payees[index].account, _payees[index].shares);
    }

    /**
     * @dev 수령자 수 조회
     */
    function payeesCount() public view returns (uint256) {
        return _payees.length;
    }

    /**
     * @dev 총 지분 조회
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }
}

/**
 * @title NFTMarketplaceWithRoyalty
 * @dev ERC-2981 로열티를 지원하는 NFT 마켓플레이스
 * NFT Marketplace with ERC-2981 royalty support
 */
contract NFTMarketplaceWithRoyalty {
    // 판매 리스팅 정보
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    mapping(bytes32 => Listing) public listings;

    // 이벤트
    event Listed(
        bytes32 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );
    event Sold(
        bytes32 indexed listingId,
        address indexed buyer,
        uint256 price,
        uint256 royalty
    );
    event ListingCancelled(bytes32 indexed listingId);

    /**
     * @dev NFT 리스팅
     */
    function list(address nftContract, uint256 tokenId, uint256 price)
        external
        returns (bytes32)
    {
        require(price > 0, "Price must be > 0");

        bytes32 listingId = keccak256(
            abi.encodePacked(nftContract, tokenId, msg.sender, block.timestamp)
        );

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        emit Listed(listingId, msg.sender, nftContract, tokenId, price);
        return listingId;
    }

    /**
     * @dev NFT 구매 (로열티 자동 지급)
     */
    function buy(bytes32 listingId) external payable {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(msg.value == listing.price, "Incorrect payment");

        listing.active = false;

        // 로열티 계산 및 지급
        uint256 royaltyAmount = 0;
        address royaltyReceiver = address(0);

        // ERC-2981 지원 확인
        if (_supportsERC2981(listing.nftContract)) {
            (royaltyReceiver, royaltyAmount) = IERC2981(listing.nftContract).royaltyInfo(
                listing.tokenId,
                listing.price
            );

            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                (bool royaltySuccess, ) = royaltyReceiver.call{value: royaltyAmount}("");
                require(royaltySuccess, "Royalty transfer failed");
            }
        }

        // 판매자에게 나머지 금액 지급
        uint256 sellerAmount = listing.price - royaltyAmount;
        (bool sellerSuccess, ) = listing.seller.call{value: sellerAmount}("");
        require(sellerSuccess, "Seller transfer failed");

        emit Sold(listingId, msg.sender, listing.price, royaltyAmount);
    }

    /**
     * @dev 리스팅 취소
     */
    function cancelListing(bytes32 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not seller");

        listing.active = false;
        emit ListingCancelled(listingId);
    }

    /**
     * @dev ERC-2981 지원 여부 확인 (내부 함수)
     */
    function _supportsERC2981(address nftContract) private view returns (bool) {
        try IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId) returns (
            bool supported
        ) {
            return supported;
        } catch {
            return false;
        }
    }

    /**
     * @dev 로열티 정보 미리보기
     */
    function previewRoyalty(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        if (_supportsERC2981(nftContract)) {
            return IERC2981(nftContract).royaltyInfo(tokenId, salePrice);
        }
        return (address(0), 0);
    }
}

/**
 * @title RoyaltyRegistry
 * @dev 외부 로열티 정보를 등록하고 조회하는 레지스트리
 * Registry for external royalty information
 */
contract RoyaltyRegistry {
    // NFT 컨트랙트별 기본 로열티 정보
    struct RoyaltyOverride {
        address receiver;
        uint96 royaltyFraction;
    }

    mapping(address => RoyaltyOverride) private _overrides;

    event RoyaltyOverrideSet(address indexed nftContract, address receiver, uint96 feeNumerator);

    /**
     * @dev 로열티 오버라이드 설정 (NFT 소유자만 가능)
     */
    function setRoyaltyOverride(
        address nftContract,
        address receiver,
        uint96 feeNumerator
    ) external {
        require(feeNumerator <= 10000, "Fee too high");
        require(receiver != address(0), "Invalid receiver");

        _overrides[nftContract] = RoyaltyOverride(receiver, feeNumerator);
        emit RoyaltyOverrideSet(nftContract, receiver, feeNumerator);
    }

    /**
     * @dev 로열티 정보 조회 (오버라이드 우선)
     */
    function getRoyalty(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        // 먼저 오버라이드 확인
        RoyaltyOverride memory override = _overrides[nftContract];
        if (override.receiver != address(0)) {
            royaltyAmount = (salePrice * override.royaltyFraction) / 10000;
            return (override.receiver, royaltyAmount);
        }

        // 오버라이드가 없으면 컨트랙트에서 직접 조회
        try IERC2981(nftContract).royaltyInfo(tokenId, salePrice) returns (
            address _receiver,
            uint256 _royaltyAmount
        ) {
            return (_receiver, _royaltyAmount);
        } catch {
            return (address(0), 0);
        }
    }
}
