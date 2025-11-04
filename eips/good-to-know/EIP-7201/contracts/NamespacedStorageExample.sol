// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NamespacedStorageExample
 * @dev EIP-7201 Namespaced Storage Layout 구현 예제
 *
 * EIP-7201은 스토리지 충돌을 방지하기 위한 네임스페이스 패턴을 정의합니다.
 * 프록시 패턴, 라이브러리, Diamond 등에서 스토리지 충돌 없이 안전하게 사용할 수 있습니다.
 *
 * EIP-7201 defines a namespaced storage pattern to prevent storage collisions.
 * Safe for use in proxies, libraries, and Diamond patterns without conflicts.
 *
 * 핵심 공식:
 * Key Formula:
 * namespace_slot = keccak256(abi.encode(uint256(keccak256(id)) - 1)) & ~bytes32(uint256(0xff))
 *
 * 장점:
 * Benefits:
 * - 스토리지 충돌 방지
 * - 업그레이드 가능한 컨트랙트에 안전
 * - 여러 라이브러리/모듈 간 격리
 */

/**
 * @title BasicNamespacedStorage
 * @dev 기본적인 네임스페이스 스토리지 구현
 * Basic namespaced storage implementation
 */
contract BasicNamespacedStorage {
    /**
     * @dev 네임스페이스 계산 (EIP-7201 표준 공식)
     * Calculate namespace using EIP-7201 formula
     */
    function erc7201Slot(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    /**
     * @dev 예제: "example.storage.main" 네임스페이스
     */
    struct MainStorage {
        uint256 value;
        address owner;
        mapping(address => uint256) balances;
    }

    // 네임스페이스 ID
    bytes32 private constant MAIN_STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("example.storage.main")) - 1)) & ~bytes32(uint256(0xff));

    /**
     * @dev 네임스페이스 스토리지 접근
     */
    function _getMainStorage() private pure returns (MainStorage storage $) {
        assembly {
            $.slot := MAIN_STORAGE_LOCATION
        }
    }

    /**
     * @dev 값 설정
     */
    function setValue(uint256 newValue) external {
        MainStorage storage $ = _getMainStorage();
        $.value = newValue;
    }

    /**
     * @dev 값 조회
     */
    function getValue() external view returns (uint256) {
        MainStorage storage $ = _getMainStorage();
        return $.value;
    }

    /**
     * @dev 소유자 설정
     */
    function setOwner(address newOwner) external {
        MainStorage storage $ = _getMainStorage();
        $.owner = newOwner;
    }

    /**
     * @dev 잔액 설정
     */
    function setBalance(address account, uint256 balance) external {
        MainStorage storage $ = _getMainStorage();
        $.balances[account] = balance;
    }

    /**
     * @dev 잔액 조회
     */
    function getBalance(address account) external view returns (uint256) {
        MainStorage storage $ = _getMainStorage();
        return $.balances[account];
    }
}

/**
 * @title MultiNamespaceContract
 * @dev 여러 네임스페이스를 사용하는 컨트랙트
 * Contract using multiple namespaces
 */
contract MultiNamespaceContract {
    // ============ 네임스페이스 1: 사용자 데이터 ============
    struct UserStorage {
        mapping(address => string) names;
        mapping(address => uint256) scores;
        uint256 totalUsers;
    }

    bytes32 private constant USER_STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("example.storage.user")) - 1)) & ~bytes32(uint256(0xff));

    function _getUserStorage() private pure returns (UserStorage storage $) {
        assembly {
            $.slot := USER_STORAGE_LOCATION
        }
    }

    // ============ 네임스페이스 2: 토큰 데이터 ============
    struct TokenStorage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        string name;
        string symbol;
    }

    bytes32 private constant TOKEN_STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("example.storage.token")) - 1)) & ~bytes32(uint256(0xff));

    function _getTokenStorage() private pure returns (TokenStorage storage $) {
        assembly {
            $.slot := TOKEN_STORAGE_LOCATION
        }
    }

    // ============ 네임스페이스 3: 설정 데이터 ============
    struct ConfigStorage {
        address admin;
        bool paused;
        uint256 fee;
        mapping(address => bool) whitelist;
    }

    bytes32 private constant CONFIG_STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("example.storage.config")) - 1)) & ~bytes32(uint256(0xff));

    function _getConfigStorage() private pure returns (ConfigStorage storage $) {
        assembly {
            $.slot := CONFIG_STORAGE_LOCATION
        }
    }

    // ============ 사용자 관련 함수 ============

    function setUserName(address user, string calldata name) external {
        UserStorage storage $ = _getUserStorage();
        $.names[user] = name;
        $.totalUsers++;
    }

    function getUserName(address user) external view returns (string memory) {
        UserStorage storage $ = _getUserStorage();
        return $.names[user];
    }

    // ============ 토큰 관련 함수 ============

    function setTokenBalance(address account, uint256 amount) external {
        TokenStorage storage $ = _getTokenStorage();
        $.balances[account] = amount;
    }

    function getTokenBalance(address account) external view returns (uint256) {
        TokenStorage storage $ = _getTokenStorage();
        return $.balances[account];
    }

    // ============ 설정 관련 함수 ============

    function setAdmin(address admin) external {
        ConfigStorage storage $ = _getConfigStorage();
        $.admin = admin;
    }

    function getAdmin() external view returns (address) {
        ConfigStorage storage $ = _getConfigStorage();
        return $.admin;
    }
}

/**
 * @title UpgradeableWithNamespace
 * @dev 네임스페이스를 사용하는 업그레이드 가능한 컨트랙트
 * Upgradeable contract using namespaces
 */
contract UpgradeableWithNamespace {
    struct AppStorage {
        uint256 version;
        address implementation;
        mapping(bytes4 => address) facets;
    }

    // EIP-7201 네임스페이스
    bytes32 private constant APP_STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("example.upgradeable.app")) - 1)) & ~bytes32(uint256(0xff));

    function _getAppStorage() private pure returns (AppStorage storage $) {
        assembly {
            $.slot := APP_STORAGE_LOCATION
        }
    }

    event Upgraded(address indexed implementation, uint256 version);

    /**
     * @dev 구현 컨트랙트 업그레이드
     */
    function upgradeTo(address newImplementation) external {
        AppStorage storage $ = _getAppStorage();

        require(newImplementation != address(0), "Invalid implementation");
        require(msg.sender == _getAppStorage().implementation, "Not authorized");

        $.implementation = newImplementation;
        $.version++;

        emit Upgraded(newImplementation, $.version);
    }

    /**
     * @dev 현재 버전 조회
     */
    function getVersion() external view returns (uint256) {
        AppStorage storage $ = _getAppStorage();
        return $.version;
    }

    /**
     * @dev 패싯 등록 (Diamond 패턴 스타일)
     */
    function registerFacet(bytes4 selector, address facetAddress) external {
        AppStorage storage $ = _getAppStorage();
        $.facets[selector] = facetAddress;
    }

    /**
     * @dev 패싯 조회
     */
    function getFacet(bytes4 selector) external view returns (address) {
        AppStorage storage $ = _getAppStorage();
        return $.facets[selector];
    }
}

/**
 * @title LibraryWithNamespace
 * @dev 네임스페이스를 사용하는 라이브러리 패턴
 * Library pattern using namespaces
 */
library CounterLib {
    struct CounterStorage {
        uint256 count;
        mapping(address => uint256) userCounts;
    }

    bytes32 constant COUNTER_STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("library.counter.storage")) - 1)) & ~bytes32(uint256(0xff));

    function getStorage() internal pure returns (CounterStorage storage $) {
        assembly {
            $.slot := COUNTER_STORAGE_LOCATION
        }
    }

    function increment() internal {
        CounterStorage storage $ = getStorage();
        $.count++;
        $.userCounts[msg.sender]++;
    }

    function getCount() internal view returns (uint256) {
        CounterStorage storage $ = getStorage();
        return $.count;
    }

    function getUserCount(address user) internal view returns (uint256) {
        CounterStorage storage $ = getStorage();
        return $.userCounts[user];
    }
}

contract UsingCounterLib {
    using CounterLib for *;

    /**
     * @dev 카운터 증가
     */
    function incrementCounter() external {
        CounterLib.increment();
    }

    /**
     * @dev 카운터 조회
     */
    function getCounter() external view returns (uint256) {
        return CounterLib.getCount();
    }

    /**
     * @dev 사용자별 카운터 조회
     */
    function getUserCounter(address user) external view returns (uint256) {
        return CounterLib.getUserCount(user);
    }
}

/**
 * @title NamespaceCalculator
 * @dev 네임스페이스 계산 유틸리티
 * Namespace calculation utility
 */
contract NamespaceCalculator {
    /**
     * @dev EIP-7201 표준 네임스페이스 계산
     */
    function calculateNamespace(string memory id) public pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    /**
     * @dev 여러 네임스페이스 한번에 계산
     */
    function calculateMultipleNamespaces(string[] memory ids)
        external
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory namespaces = new bytes32[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            namespaces[i] = calculateNamespace(ids[i]);
        }

        return namespaces;
    }

    /**
     * @dev 네임스페이스 충돌 확인
     */
    function checkCollision(string memory id1, string memory id2)
        external
        pure
        returns (bool collides)
    {
        bytes32 ns1 = calculateNamespace(id1);
        bytes32 ns2 = calculateNamespace(id2);

        return ns1 == ns2;
    }

    /**
     * @dev 네임스페이스 정보 출력
     */
    function getNamespaceInfo(string memory id)
        external
        pure
        returns (
            bytes32 namespace,
            bytes32 rawHash,
            uint256 rawHashMinus1
        )
    {
        rawHash = keccak256(bytes(id));
        rawHashMinus1 = uint256(rawHash) - 1;
        namespace = keccak256(abi.encode(rawHashMinus1)) & ~bytes32(uint256(0xff));

        return (namespace, rawHash, rawHashMinus1);
    }
}

/**
 * @title ModularSystem
 * @dev 모듈식 시스템에서 네임스페이스 사용
 * Namespace usage in modular systems
 */
contract ModularSystem {
    // ============ 모듈 A: 인증 ============
    struct AuthModule {
        mapping(address => bool) authorized;
        mapping(address => uint256) nonces;
        address admin;
    }

    bytes32 private constant AUTH_MODULE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("module.auth.storage")) - 1)) & ~bytes32(uint256(0xff));

    function _getAuthModule() private pure returns (AuthModule storage $) {
        assembly {
            $.slot := AUTH_MODULE_LOCATION
        }
    }

    // ============ 모듈 B: 토큰 ============
    struct TokenModule {
        mapping(address => uint256) balances;
        uint256 totalSupply;
        string name;
    }

    bytes32 private constant TOKEN_MODULE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("module.token.storage")) - 1)) & ~bytes32(uint256(0xff));

    function _getTokenModule() private pure returns (TokenModule storage $) {
        assembly {
            $.slot := TOKEN_MODULE_LOCATION
        }
    }

    // ============ 모듈 C: 거버넌스 ============
    struct GovernanceModule {
        mapping(uint256 => bool) executed;
        mapping(uint256 => uint256) votes;
        uint256 proposalCount;
    }

    bytes32 private constant GOVERNANCE_MODULE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("module.governance.storage")) - 1)) & ~bytes32(uint256(0xff));

    function _getGovernanceModule() private pure returns (GovernanceModule storage $) {
        assembly {
            $.slot := GOVERNANCE_MODULE_LOCATION
        }
    }

    // ============ 모듈 함수들 ============

    function authorize(address user) external {
        AuthModule storage $ = _getAuthModule();
        $.authorized[user] = true;
    }

    function isAuthorized(address user) external view returns (bool) {
        AuthModule storage $ = _getAuthModule();
        return $.authorized[user];
    }

    function mint(address to, uint256 amount) external {
        TokenModule storage $ = _getTokenModule();
        $.balances[to] += amount;
        $.totalSupply += amount;
    }

    function createProposal() external returns (uint256) {
        GovernanceModule storage $ = _getGovernanceModule();
        uint256 proposalId = $.proposalCount++;
        return proposalId;
    }
}

/**
 * @title StorageCollisionExample
 * @dev 네임스페이스를 사용하지 않았을 때의 충돌 예제
 * Storage collision example without namespaces
 */
contract BadStorageExample {
    // 나쁜 예: 직접 슬롯 사용 (충돌 위험)
    uint256 public value; // slot 0
    address public owner; // slot 1

    // 업그레이드 시 슬롯 순서가 바뀌면 충돌 발생
}

contract GoodStorageExample {
    // 좋은 예: 네임스페이스 사용
    struct Storage {
        uint256 value;
        address owner;
    }

    bytes32 private constant STORAGE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("good.example.storage")) - 1)) & ~bytes32(uint256(0xff));

    function _getStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    // 스토리지 충돌 없이 안전하게 업그레이드 가능
}

/**
 * @title NamespacedStorageBestPractices
 * @dev 네임스페이스 스토리지 모범 사례
 * Best practices for namespaced storage
 */
contract NamespacedStorageBestPractices {
    /**
     * 네임스페이스 명명 규칙:
     * Namespace naming conventions:
     *
     * 1. 역방향 도메인 스타일
     *    Reverse domain style:
     *    "com.company.project.module.storage"
     *
     * 2. ERC 스타일
     *    ERC style:
     *    "erc7201.storage.module"
     *
     * 3. 프로젝트별 스타일
     *    Project-specific style:
     *    "project.module.version.storage"
     *
     * 모범 사례:
     * Best practices:
     *
     * 1. 고유한 네임스페이스 ID 사용
     *    Use unique namespace IDs
     *
     * 2. 문서화
     *    Document all namespaces
     *
     * 3. 버전 관리
     *    Version management
     *
     * 4. 충돌 테스트
     *    Test for collisions
     *
     * 5. 네임스페이스당 하나의 struct
     *    One struct per namespace
     */

    struct ExampleStorage {
        uint256 data;
        address owner;
    }

    // 명확한 네임스페이스 ID
    bytes32 private constant EXAMPLE_STORAGE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("com.example.myproject.main.v1.storage")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function _getExampleStorage() private pure returns (ExampleStorage storage $) {
        assembly {
            $.slot := EXAMPLE_STORAGE_LOCATION
        }
    }

    /**
     * @dev 네임스페이스 정보 조회 (디버깅용)
     */
    function getNamespaceLocation() external pure returns (bytes32) {
        return EXAMPLE_STORAGE_LOCATION;
    }
}

/**
 * @title NamespaceRegistry
 * @dev 네임스페이스 레지스트리 (충돌 방지)
 * Namespace registry for collision prevention
 */
contract NamespaceRegistry {
    mapping(bytes32 => string) public namespaceIds;
    mapping(bytes32 => address) public namespaceOwners;

    event NamespaceRegistered(bytes32 indexed namespace, string id, address owner);

    /**
     * @dev 네임스페이스 등록
     */
    function registerNamespace(string memory id) external {
        bytes32 namespace = keccak256(
            abi.encode(uint256(keccak256(bytes(id))) - 1)
        ) & ~bytes32(uint256(0xff));

        require(namespaceOwners[namespace] == address(0), "Namespace already registered");

        namespaceIds[namespace] = id;
        namespaceOwners[namespace] = msg.sender;

        emit NamespaceRegistered(namespace, id, msg.sender);
    }

    /**
     * @dev 네임스페이스 소유자 확인
     */
    function getNamespaceOwner(bytes32 namespace) external view returns (address) {
        return namespaceOwners[namespace];
    }

    /**
     * @dev ID로 네임스페이스 조회
     */
    function getNamespace(string memory id) external pure returns (bytes32) {
        return keccak256(
            abi.encode(uint256(keccak256(bytes(id))) - 1)
        ) & ~bytes32(uint256(0xff));
    }
}
