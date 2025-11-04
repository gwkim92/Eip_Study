// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RealWorldExample
 * @dev EIP-165를 실전에서 어떻게 사용하는지 보여주는 완전한 예제
 *
 * 이 파일은 다음을 포함합니다:
 * 1. 간단한 NFT 구현 (EIP-165 지원)
 * 2. NFT 마켓플레이스 (EIP-165로 안전성 확보)
 * 3. 다양한 토큰 타입을 처리하는 범용 핸들러
 */

// ============================================
// 1. 필수 인터페이스 정의
// ============================================

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
}

interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// ============================================
// 2. 간단한 NFT 구현 (EIP-165 포함)
// ============================================

/**
 * @title SimpleNFT
 * @dev EIP-165를 지원하는 간단한 NFT 구현
 *
 * 핵심 포인트:
 * - supportsInterface()로 자신이 어떤 인터페이스를 구현하는지 알림
 * - 다른 컨트랙트가 안전하게 이 NFT를 사용할 수 있게 함
 */
contract SimpleNFT is IERC721Metadata {
    string private _name;
    string private _symbol;
    uint256 private _nextTokenId;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(uint256 => string) private _tokenURIs;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    // ==================== EIP-165 구현 ====================

    /**
     * @dev 이 부분이 핵심!
     * 이 컨트랙트가 어떤 인터페이스를 지원하는지 알려줌
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IERC721).interfaceId ||
               interfaceId == type(IERC721Metadata).interfaceId;
    }

    // ==================== ERC721 기본 함수들 ====================

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "Invalid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Token does not exist");
        return owner;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _tokenURIs[tokenId];
    }

    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "Not the owner");
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _tokenApprovals[tokenId];
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(ownerOf(tokenId) == from, "From is not owner");
        require(
            msg.sender == from ||
            msg.sender == getApproved(tokenId),
            "Not authorized"
        );

        _transfer(from, to, tokenId);
    }

    // ==================== 추가 기능 ====================

    /**
     * @dev NFT 발행
     */
    function mint(address to, string memory uri) public returns (uint256) {
        uint256 tokenId = _nextTokenId++;

        _owners[tokenId] = to;
        _balances[to]++;
        _tokenURIs[tokenId] = uri;

        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(to != address(0), "Invalid recipient");

        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;
        delete _tokenApprovals[tokenId];

        emit Transfer(from, to, tokenId);
    }
}

// ============================================
// 3. NFT 마켓플레이스 (EIP-165 활용)
// ============================================

/**
 * @title NFTMarketplace
 * @dev EIP-165를 활용해 안전하게 NFT를 거래하는 마켓플레이스
 *
 * 핵심 포인트:
 * - 리스팅 전에 컨트랙트가 진짜 NFT인지 확인
 * - 잘못된 컨트랙트로 인한 오류 방지
 */
contract NFTMarketplace {
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );

    event NFTSold(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price
    );

    /**
     * @dev NFT 리스팅 (EIP-165로 검증)
     *
     * 단계별 검증:
     * 1. 컨트랙트가 EIP-165를 지원하는가?
     * 2. ERC721 인터페이스를 구현하는가?
     * 3. 호출자가 실제 소유자인가?
     */
    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external returns (uint256) {
        // ===== 1단계: EIP-165 지원 확인 =====
        require(
            _supportsERC165(nftContract),
            "Contract does not support ERC165"
        );

        // ===== 2단계: ERC721 인터페이스 확인 =====
        require(
            _supportsERC721(nftContract),
            "Contract is not ERC721"
        );

        // ===== 3단계: 소유권 확인 =====
        IERC721 nft = IERC721(nftContract);
        require(
            nft.ownerOf(tokenId) == msg.sender,
            "You are not the owner"
        );

        // ===== 4단계: 승인 확인 =====
        require(
            nft.getApproved(tokenId) == address(this),
            "Marketplace not approved"
        );

        // 리스팅 생성
        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        emit NFTListed(listingId, msg.sender, nftContract, tokenId, price);
        return listingId;
    }

    /**
     * @dev NFT 구매
     */
    function buyNFT(uint256 listingId) external payable {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");

        listing.active = false;

        // NFT 전송
        IERC721(listing.nftContract).transferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // 판매자에게 대금 지급
        payable(listing.seller).transfer(listing.price);

        // 잔액 반환
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }

        emit NFTSold(listingId, msg.sender, listing.price);
    }

    // ==================== EIP-165 검증 헬퍼 함수 ====================

    /**
     * @dev 컨트랙트가 ERC165를 지원하는지 확인
     */
    function _supportsERC165(address account) private view returns (bool) {
        try IERC165(account).supportsInterface(type(IERC165).interfaceId)
            returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    /**
     * @dev 컨트랙트가 ERC721을 지원하는지 확인
     */
    function _supportsERC721(address account) private view returns (bool) {
        try IERC165(account).supportsInterface(type(IERC721).interfaceId)
            returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    /**
     * @dev 안전성 체크 (공개 함수)
     * 사용자가 리스팅 전에 미리 확인할 수 있음
     */
    function isValidNFT(address nftContract) external view returns (bool) {
        return _supportsERC165(nftContract) && _supportsERC721(nftContract);
    }
}

// ============================================
// 4. 범용 토큰 핸들러 (여러 타입 지원)
// ============================================

interface IERC1155 is IERC165 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}

/**
 * @title UniversalTokenVault
 * @dev 여러 종류의 토큰을 보관할 수 있는 금고
 *
 * EIP-165를 활용하여:
 * - ERC721 (NFT)
 * - ERC1155 (멀티 토큰)
 * 등을 구분하여 처리
 */
contract UniversalTokenVault {
    event TokenDeposited(
        address indexed user,
        address indexed tokenContract,
        string tokenType,
        uint256 tokenId
    );

    event TokenWithdrawn(
        address indexed user,
        address indexed tokenContract,
        string tokenType,
        uint256 tokenId
    );

    // 사용자 -> 토큰 컨트랙트 -> 토큰 ID -> 보유 여부
    mapping(address => mapping(address => mapping(uint256 => bool))) public deposits;

    /**
     * @dev 토큰 입금 (자동으로 타입 감지)
     */
    function deposit(address tokenContract, uint256 tokenId) external {
        string memory tokenType = _detectTokenType(tokenContract);

        if (_isERC721(tokenContract)) {
            // ERC721 처리
            IERC721(tokenContract).transferFrom(msg.sender, address(this), tokenId);
            deposits[msg.sender][tokenContract][tokenId] = true;
        } else if (_isERC1155(tokenContract)) {
            // ERC1155 처리
            IERC1155(tokenContract).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                1,
                ""
            );
            deposits[msg.sender][tokenContract][tokenId] = true;
        } else {
            revert("Unsupported token type");
        }

        emit TokenDeposited(msg.sender, tokenContract, tokenType, tokenId);
    }

    /**
     * @dev 토큰 출금
     */
    function withdraw(address tokenContract, uint256 tokenId) external {
        require(
            deposits[msg.sender][tokenContract][tokenId],
            "No deposit found"
        );

        string memory tokenType = _detectTokenType(tokenContract);
        deposits[msg.sender][tokenContract][tokenId] = false;

        if (_isERC721(tokenContract)) {
            IERC721(tokenContract).transferFrom(address(this), msg.sender, tokenId);
        } else if (_isERC1155(tokenContract)) {
            IERC1155(tokenContract).safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                1,
                ""
            );
        }

        emit TokenWithdrawn(msg.sender, tokenContract, tokenType, tokenId);
    }

    // ==================== 타입 감지 헬퍼 함수 ====================

    function _isERC721(address account) private view returns (bool) {
        try IERC165(account).supportsInterface(type(IERC721).interfaceId)
            returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function _isERC1155(address account) private view returns (bool) {
        try IERC165(account).supportsInterface(type(IERC1155).interfaceId)
            returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function _detectTokenType(address tokenContract)
        private
        view
        returns (string memory)
    {
        if (_isERC721(tokenContract)) {
            return "ERC721";
        } else if (_isERC1155(tokenContract)) {
            return "ERC1155";
        } else {
            return "Unknown";
        }
    }

    /**
     * @dev 토큰 타입 조회 (공개 함수)
     */
    function getTokenType(address tokenContract)
        external
        view
        returns (string memory)
    {
        return _detectTokenType(tokenContract);
    }

    /**
     * @dev ERC1155 수신용 콜백
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}

// ============================================
// 5. 사용 예제 및 테스트 시나리오
// ============================================

/**
 * @title UsageExample
 * @dev 실제로 어떻게 사용하는지 보여주는 예제
 */
contract UsageExample {
    SimpleNFT public nft;
    NFTMarketplace public marketplace;
    UniversalTokenVault public vault;

    constructor() {
        nft = new SimpleNFT("My NFT", "MNFT");
        marketplace = new NFTMarketplace();
        vault = new UniversalTokenVault();
    }

    /**
     * @dev 시나리오 1: NFT 발행 및 마켓에 리스팅
     */
    function scenario1_MintAndList() external {
        // 1. NFT 발행
        uint256 tokenId = nft.mint(msg.sender, "ipfs://example");

        // 2. 마켓플레이스에 승인
        nft.approve(address(marketplace), tokenId);

        // 3. 리스팅 (내부에서 EIP-165로 검증됨)
        marketplace.listNFT(address(nft), tokenId, 1 ether);
    }

    /**
     * @dev 시나리오 2: 안전하게 토큰 타입 확인
     */
    function scenario2_CheckTokenType(address unknownContract)
        external
        view
        returns (string memory)
    {
        // UniversalTokenVault의 타입 감지 활용
        return vault.getTokenType(unknownContract);
    }

    /**
     * @dev 시나리오 3: 잘못된 컨트랙트 거부
     */
    function scenario3_RejectInvalidContract(address suspiciousContract)
        external
        view
        returns (bool isValid)
    {
        // 마켓플레이스의 검증 활용
        return marketplace.isValidNFT(suspiciousContract);
    }
}

/**
 * @title 학습 정리
 *
 * EIP-165의 핵심 가치:
 *
 * 1. 안전성 향상
 *    - 잘못된 컨트랙트 호출 방지
 *    - 런타임 에러 감소
 *
 * 2. 유연성 제공
 *    - 여러 토큰 타입을 동적으로 처리
 *    - 타입별 로직 분기
 *
 * 3. 호환성 보장
 *    - 표준화된 인터페이스 확인 방법
 *    - 다른 프로젝트와의 통합 용이
 *
 * 실전 적용:
 * - NFT 마켓플레이스
 * - 멀티체인 브릿지
 * - DeFi 프로토콜
 * - DAO 거버넌스
 *
 * 주의사항:
 * - 가스 제한 설정 (악의적인 컨트랙트 대비)
 * - try-catch로 안전하게 호출
 * - 0xffffffff는 항상 false 반환
 */
