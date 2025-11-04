// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EIP5192Example
 * @dev EIP-5192 Minimal Soulbound NFT 구현 예제
 *
 * EIP-5192는 양도 불가능한 토큰(Soulbound Token)에 대한 최소 인터페이스를 정의합니다.
 * Soulbound 토큰은 특정 주소에 영구적으로 묶여있으며 전송할 수 없습니다.
 *
 * EIP-5192 defines a minimal interface for non-transferable NFTs (Soulbound Tokens).
 * These tokens are permanently bound to an address and cannot be transferred.
 */

/**
 * @dev ERC-165 인터페이스
 */
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @dev ERC-721 기본 인터페이스 (간소화 버전)
 */
interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

/**
 * @dev EIP-5192 표준 인터페이스
 * EIP-5192 Standard Interface
 */
interface IERC5192 {
    /**
     * @dev 토큰이 잠겨있을 때(Locked) 발생
     * Emitted when token is locked
     */
    event Locked(uint256 tokenId);

    /**
     * @dev 토큰이 잠금 해제될 때(Unlocked) 발생
     * Emitted when token is unlocked
     */
    event Unlocked(uint256 tokenId);

    /**
     * @dev 토큰이 잠겨있는지 확인
     * Returns whether the token is locked
     *
     * @param tokenId 확인할 토큰 ID / Token ID to check
     * @return 잠겨있으면 true / True if locked
     */
    function locked(uint256 tokenId) external view returns (bool);
}

/**
 * @title BasicSoulboundToken
 * @dev 기본적인 Soulbound 토큰 (완전히 잠긴 상태)
 * Basic Soulbound token (completely locked)
 */
contract BasicSoulboundToken is IERC721, IERC5192 {
    // 토큰 소유자
    mapping(uint256 => address) private _owners;

    // 소유자별 토큰 수
    mapping(address => uint256) private _balances;

    // 다음 토큰 ID
    uint256 private _nextTokenId;

    // 토큰 메타데이터
    string public name;
    string public symbol;

    // 이벤트
    event Minted(address indexed to, uint256 indexed tokenId);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    /**
     * @dev ERC-165 인터페이스 지원 확인
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC5192).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 모든 토큰은 항상 잠겨있음 (Soulbound)
     */
    function locked(uint256 tokenId) external view override returns (bool) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return true;
    }

    /**
     * @dev 토큰 발행 (발행 후 전송 불가)
     */
    function mint(address to) external returns (uint256) {
        require(to != address(0), "Mint to zero address");

        uint256 tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _balances[to] += 1;

        emit Transfer(address(0), to, tokenId);
        emit Locked(tokenId);
        emit Minted(to, tokenId);

        return tokenId;
    }

    /**
     * @dev 소각 (유일하게 허용되는 "전송")
     */
    function burn(uint256 tokenId) external {
        address owner = _owners[tokenId];
        require(owner == msg.sender, "Not token owner");

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    // ============ ERC-721 View Functions ============

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "Zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Token does not exist");
        return owner;
    }

    // ============ ERC-721 Transfer Functions (모두 revert) ============

    function transferFrom(address, address, uint256) external pure override {
        revert("Soulbound: token is non-transferable");
    }

    function approve(address, uint256) external pure override {
        revert("Soulbound: token is non-transferable");
    }

    function getApproved(uint256) external pure override returns (address) {
        return address(0);
    }

    function setApprovalForAll(address, bool) external pure override {
        revert("Soulbound: token is non-transferable");
    }

    function isApprovedForAll(address, address) external pure override returns (bool) {
        return false;
    }
}

/**
 * @title ConditionalSoulboundToken
 * @dev 조건부로 잠금을 해제할 수 있는 Soulbound 토큰
 * Conditionally unlockable Soulbound token
 */
contract ConditionalSoulboundToken is IERC721, IERC5192 {
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => bool) private _locked;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 private _nextTokenId;

    string public name;
    string public symbol;

    // 잠금 해제 권한 관리자
    address public admin;

    event Minted(address indexed to, uint256 indexed tokenId, bool locked);
    event LockStatusChanged(uint256 indexed tokenId, bool locked);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    /**
     * @dev ERC-165 인터페이스 지원 확인
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC5192).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 토큰이 잠겨있는지 확인
     */
    function locked(uint256 tokenId) external view override returns (bool) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _locked[tokenId];
    }

    /**
     * @dev 잠긴 상태로 토큰 발행
     */
    function mintLocked(address to) external returns (uint256) {
        return _mint(to, true);
    }

    /**
     * @dev 잠기지 않은 상태로 토큰 발행
     */
    function mintUnlocked(address to) external returns (uint256) {
        return _mint(to, false);
    }

    /**
     * @dev 토큰 잠금 상태 변경 (관리자만 가능)
     */
    function setLocked(uint256 tokenId, bool locked_) external onlyAdmin {
        require(_owners[tokenId] != address(0), "Token does not exist");

        if (_locked[tokenId] != locked_) {
            _locked[tokenId] = locked_;

            if (locked_) {
                emit Locked(tokenId);
            } else {
                emit Unlocked(tokenId);
            }

            emit LockStatusChanged(tokenId, locked_);
        }
    }

    /**
     * @dev 내부 발행 함수
     */
    function _mint(address to, bool locked_) internal returns (uint256) {
        require(to != address(0), "Mint to zero address");

        uint256 tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _balances[to] += 1;
        _locked[tokenId] = locked_;

        emit Transfer(address(0), to, tokenId);

        if (locked_) {
            emit Locked(tokenId);
        }

        emit Minted(to, tokenId, locked_);
        return tokenId;
    }

    // ============ ERC-721 View Functions ============

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "Zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Token does not exist");
        return owner;
    }

    // ============ ERC-721 Transfer Functions ============

    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(!_locked[tokenId], "Token is locked");
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved");
        _transfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = _owners[tokenId];
        require(msg.sender == owner || _operatorApprovals[owner][msg.sender], "Not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator)
        external
        view
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    // ============ Internal Functions ============

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(_owners[tokenId] == from, "Not owner");
        require(to != address(0), "Transfer to zero");

        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = _owners[tokenId];
        return (spender == owner ||
            _tokenApprovals[tokenId] == spender ||
            _operatorApprovals[owner][spender]);
    }
}

/**
 * @title AchievementBadge
 * @dev 업적 배지 시스템 (Soulbound)
 * Achievement badge system using Soulbound tokens
 */
contract AchievementBadge is BasicSoulboundToken {
    // 배지 메타데이터
    struct Badge {
        string name;
        string description;
        uint256 timestamp;
    }

    mapping(uint256 => Badge) public badges;

    // 배지 타입별 발급 횟수
    mapping(string => uint256) public badgeTypeCounts;

    event BadgeAwarded(address indexed recipient, uint256 indexed tokenId, string badgeType);

    constructor() BasicSoulboundToken("Achievement Badge", "BADGE") {}

    /**
     * @dev 배지 수여
     */
    function awardBadge(
        address recipient,
        string memory badgeName,
        string memory description
    ) external returns (uint256) {
        uint256 tokenId = this.mint(recipient);

        badges[tokenId] = Badge({
            name: badgeName,
            description: description,
            timestamp: block.timestamp
        });

        badgeTypeCounts[badgeName] += 1;

        emit BadgeAwarded(recipient, tokenId, badgeName);
        return tokenId;
    }

    /**
     * @dev 특정 주소가 보유한 모든 배지 조회
     */
    function getBadgesOfOwner(address owner)
        external
        view
        returns (uint256[] memory tokenIds, Badge[] memory badgeData)
    {
        uint256 balance = this.balanceOf(owner);
        tokenIds = new uint256[](balance);
        badgeData = new Badge[](balance);

        uint256 currentIndex = 0;
        for (uint256 i = 0; i < _nextTokenId && currentIndex < balance; i++) {
            try this.ownerOf(i) returns (address tokenOwner) {
                if (tokenOwner == owner) {
                    tokenIds[currentIndex] = i;
                    badgeData[currentIndex] = badges[i];
                    currentIndex++;
                }
            } catch {}
        }
    }

    /**
     * @dev 특정 타입의 배지를 보유하고 있는지 확인
     */
    function hasBadgeType(address owner, string memory badgeType)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < _nextTokenId; i++) {
            try this.ownerOf(i) returns (address tokenOwner) {
                if (
                    tokenOwner == owner &&
                    keccak256(bytes(badges[i].name)) == keccak256(bytes(badgeType))
                ) {
                    return true;
                }
            } catch {}
        }
        return false;
    }
}

/**
 * @title IdentityCredential
 * @dev 신원 증명서 (Soulbound, 만료 기능 포함)
 * Identity credential with expiration
 */
contract IdentityCredential is IERC721, IERC5192 {
    struct Credential {
        string credentialType;
        string issuer;
        uint256 issuedAt;
        uint256 expiresAt;
        bool revoked;
    }

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => Credential) public credentials;

    uint256 private _nextTokenId;

    string public name = "Identity Credential";
    string public symbol = "IDC";

    address public authority;

    event CredentialIssued(
        address indexed recipient,
        uint256 indexed tokenId,
        string credentialType
    );
    event CredentialRevoked(uint256 indexed tokenId);

    constructor() {
        authority = msg.sender;
    }

    modifier onlyAuthority() {
        require(msg.sender == authority, "Not authority");
        _;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC5192).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 취소되지 않고 유효한 경우에만 잠금 (Soulbound)
     */
    function locked(uint256 tokenId) external view override returns (bool) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        Credential memory cred = credentials[tokenId];
        return !cred.revoked && block.timestamp < cred.expiresAt;
    }

    /**
     * @dev 증명서 발급
     */
    function issueCredential(
        address recipient,
        string memory credentialType,
        string memory issuer,
        uint256 validityPeriod
    ) external onlyAuthority returns (uint256) {
        require(recipient != address(0), "Invalid recipient");

        uint256 tokenId = _nextTokenId++;
        _owners[tokenId] = recipient;
        _balances[recipient] += 1;

        credentials[tokenId] = Credential({
            credentialType: credentialType,
            issuer: issuer,
            issuedAt: block.timestamp,
            expiresAt: block.timestamp + validityPeriod,
            revoked: false
        });

        emit Transfer(address(0), recipient, tokenId);
        emit Locked(tokenId);
        emit CredentialIssued(recipient, tokenId, credentialType);

        return tokenId;
    }

    /**
     * @dev 증명서 취소
     */
    function revokeCredential(uint256 tokenId) external onlyAuthority {
        require(_owners[tokenId] != address(0), "Token does not exist");
        require(!credentials[tokenId].revoked, "Already revoked");

        credentials[tokenId].revoked = true;
        emit Unlocked(tokenId);
        emit CredentialRevoked(tokenId);
    }

    /**
     * @dev 증명서가 유효한지 확인
     */
    function isValid(uint256 tokenId) external view returns (bool) {
        if (_owners[tokenId] == address(0)) return false;

        Credential memory cred = credentials[tokenId];
        return !cred.revoked && block.timestamp < cred.expiresAt;
    }

    /**
     * @dev 만료 확인
     */
    function isExpired(uint256 tokenId) external view returns (bool) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return block.timestamp >= credentials[tokenId].expiresAt;
    }

    // ============ ERC-721 View Functions ============

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "Zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Token does not exist");
        return owner;
    }

    // ============ Transfer Functions (모두 비활성화) ============

    function transferFrom(address, address, uint256) external pure override {
        revert("Soulbound: non-transferable");
    }

    function approve(address, uint256) external pure override {
        revert("Soulbound: non-transferable");
    }

    function getApproved(uint256) external pure override returns (address) {
        return address(0);
    }

    function setApprovalForAll(address, bool) external pure override {
        revert("Soulbound: non-transferable");
    }

    function isApprovedForAll(address, address) external pure override returns (bool) {
        return false;
    }
}

/**
 * @title SoulboundAccessControl
 * @dev Soulbound 토큰을 사용한 접근 제어 시스템
 * Access control system using Soulbound tokens
 */
contract SoulboundAccessControl {
    BasicSoulboundToken public membershipToken;

    mapping(address => uint256) public memberTokenId;
    mapping(uint256 => bool) public activeMemberships;

    event MembershipGranted(address indexed member, uint256 indexed tokenId);
    event MembershipRevoked(address indexed member, uint256 indexed tokenId);
    event AccessGranted(address indexed member, string resource);

    constructor(BasicSoulboundToken token) {
        membershipToken = token;
    }

    /**
     * @dev 멤버십 부여
     */
    function grantMembership(address member) external returns (uint256) {
        require(memberTokenId[member] == 0, "Already has membership");

        uint256 tokenId = membershipToken.mint(member);
        memberTokenId[member] = tokenId;
        activeMemberships[tokenId] = true;

        emit MembershipGranted(member, tokenId);
        return tokenId;
    }

    /**
     * @dev 멤버십 취소 (토큰은 유지되지만 비활성화)
     */
    function revokeMembership(address member) external {
        uint256 tokenId = memberTokenId[member];
        require(tokenId != 0, "No membership");
        require(activeMemberships[tokenId], "Already revoked");

        activeMemberships[tokenId] = false;
        emit MembershipRevoked(member, tokenId);
    }

    /**
     * @dev 멤버십 확인
     */
    function isMember(address account) public view returns (bool) {
        uint256 tokenId = memberTokenId[account];
        if (tokenId == 0) return false;

        try membershipToken.ownerOf(tokenId) returns (address owner) {
            return owner == account && activeMemberships[tokenId];
        } catch {
            return false;
        }
    }

    /**
     * @dev 멤버 전용 함수
     */
    function accessProtectedResource(string memory resource) external {
        require(isMember(msg.sender), "Not a member");
        emit AccessGranted(msg.sender, resource);
        // 실제 리소스 접근 로직...
    }

    /**
     * @dev 멤버 전용 modifier
     */
    modifier onlyMember() {
        require(isMember(msg.sender), "Not a member");
        _;
    }

    /**
     * @dev 멤버 전용 기능 예제
     */
    function memberOnlyFunction() external onlyMember returns (string memory) {
        return "Access granted to member-only function";
    }
}

/**
 * @title ReputationScore
 * @dev 평판 점수 시스템 (Soulbound, 업그레이드 가능)
 * Reputation score system with upgradeable Soulbound tokens
 */
contract ReputationScore is BasicSoulboundToken {
    // 토큰별 평판 점수
    mapping(uint256 => uint256) public scores;

    // 레벨별 필요 점수
    uint256[] public levelThresholds = [0, 100, 500, 1000, 5000];

    event ScoreUpdated(uint256 indexed tokenId, uint256 newScore, uint256 level);
    event LevelUp(uint256 indexed tokenId, uint256 newLevel);

    constructor() BasicSoulboundToken("Reputation Score", "REP") {}

    /**
     * @dev 평판 토큰 발행
     */
    function issueReputation(address to) external returns (uint256) {
        uint256 tokenId = this.mint(to);
        scores[tokenId] = 0;
        emit ScoreUpdated(tokenId, 0, 0);
        return tokenId;
    }

    /**
     * @dev 평판 점수 증가
     */
    function increaseScore(uint256 tokenId, uint256 amount) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        uint256 oldLevel = getLevel(tokenId);
        scores[tokenId] += amount;
        uint256 newLevel = getLevel(tokenId);

        emit ScoreUpdated(tokenId, scores[tokenId], newLevel);

        if (newLevel > oldLevel) {
            emit LevelUp(tokenId, newLevel);
        }
    }

    /**
     * @dev 현재 레벨 조회
     */
    function getLevel(uint256 tokenId) public view returns (uint256) {
        uint256 score = scores[tokenId];
        uint256 level = 0;

        for (uint256 i = levelThresholds.length - 1; i > 0; i--) {
            if (score >= levelThresholds[i]) {
                return i;
            }
        }

        return level;
    }

    /**
     * @dev 다음 레벨까지 필요한 점수
     */
    function scoreToNextLevel(uint256 tokenId) external view returns (uint256) {
        uint256 currentLevel = getLevel(tokenId);
        if (currentLevel >= levelThresholds.length - 1) {
            return 0; // 최대 레벨
        }

        uint256 currentScore = scores[tokenId];
        uint256 nextLevelThreshold = levelThresholds[currentLevel + 1];

        return nextLevelThreshold - currentScore;
    }

    /**
     * @dev 내부 함수: 소유자 조회
     */
    function _ownerOf(uint256 tokenId) internal view returns (address) {
        try this.ownerOf(tokenId) returns (address owner) {
            return owner;
        } catch {
            return address(0);
        }
    }
}
