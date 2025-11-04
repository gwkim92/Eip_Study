// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1271.sol";

/**
 * @title SessionKeyWallet
 * @dev 세션 키 기능을 가진 스마트 컨트랙트 지갑
 * @dev Smart contract wallet with session key functionality
 *
 * 세션 키를 사용하여 제한된 권한을 임시로 부여할 수 있습니다.
 * Session keys allow granting limited temporary permissions.
 *
 * 사용 사례:
 * Use cases:
 * - 게임 내 자동 거래 (in-game automatic transactions)
 * - DApp 세션 관리 (DApp session management)
 * - 가스리스 트랜잭션 (gasless transactions)
 */
contract SessionKeyWallet is IERC1271 {
    // EIP-1271 magic value
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    // 지갑 소유자
    // Wallet owner
    address public owner;

    /**
     * @dev 세션 키 정보
     * @dev Session key information
     */
    struct SessionKey {
        bool isActive;           // 활성 상태
        uint256 expiresAt;       // 만료 시간
        uint256 spendLimit;      // 지출 한도 (wei)
        uint256 spent;           // 사용한 금액
        address[] allowedTargets; // 허용된 대상 주소들
    }

    // 세션 키 매핑
    // Session key mapping
    mapping(address => SessionKey) public sessionKeys;

    // 트랜잭션 nonce
    // Transaction nonce
    uint256 public nonce;

    /**
     * @dev 세션 키 추가 이벤트
     * @dev Session key added event
     */
    event SessionKeyAdded(
        address indexed key,
        uint256 expiresAt,
        uint256 spendLimit
    );

    /**
     * @dev 세션 키 제거 이벤트
     * @dev Session key removed event
     */
    event SessionKeyRevoked(address indexed key);

    /**
     * @dev 트랜잭션 실행 이벤트
     * @dev Transaction executed event
     */
    event TransactionExecuted(
        address indexed executor,
        address indexed to,
        uint256 value,
        bool isSessionKey
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @dev EIP-1271 서명 검증
     * @dev EIP-1271 signature validation
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
        require(signature.length == 65, "Invalid signature length");

        // 서명 추출
        // Extract signature
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        address signer = ecrecover(hash, v, r, s);

        // 소유자 확인
        // Check owner
        if (signer == owner) {
            return MAGICVALUE;
        }

        // 세션 키 확인
        // Check session key
        SessionKey storage session = sessionKeys[signer];
        if (session.isActive &&
            session.expiresAt > block.timestamp &&
            session.spent < session.spendLimit) {
            return MAGICVALUE;
        }

        return bytes4(0xffffffff);
    }

    /**
     * @dev 세션 키 추가
     * @dev Add session key
     *
     * @param key 세션 키 주소
     * @param key Session key address
     *
     * @param duration 유효 기간 (초)
     * @param duration Valid duration (seconds)
     *
     * @param spendLimit 지출 한도 (wei)
     * @param spendLimit Spend limit (wei)
     *
     * @param allowedTargets 허용된 대상 주소 배열
     * @param allowedTargets Array of allowed target addresses
     */
    function addSessionKey(
        address key,
        uint256 duration,
        uint256 spendLimit,
        address[] memory allowedTargets
    ) external onlyOwner {
        require(key != address(0), "Invalid key");
        require(!sessionKeys[key].isActive, "Key already exists");
        require(duration > 0, "Invalid duration");

        uint256 expiresAt = block.timestamp + duration;

        sessionKeys[key] = SessionKey({
            isActive: true,
            expiresAt: expiresAt,
            spendLimit: spendLimit,
            spent: 0,
            allowedTargets: allowedTargets
        });

        emit SessionKeyAdded(key, expiresAt, spendLimit);
    }

    /**
     * @dev 세션 키 제거
     * @dev Revoke session key
     */
    function revokeSessionKey(address key) external onlyOwner {
        require(sessionKeys[key].isActive, "Key not active");

        delete sessionKeys[key];

        emit SessionKeyRevoked(key);
    }

    /**
     * @dev 세션 키로 트랜잭션 실행
     * @dev Execute transaction with session key
     */
    function executeWithSessionKey(
        address to,
        uint256 value,
        bytes memory data,
        bytes memory signature
    ) external returns (bytes memory) {
        // 트랜잭션 해시 생성
        // Create transaction hash
        bytes32 txHash = keccak256(abi.encodePacked(
            address(this),
            to,
            value,
            data,
            nonce
        ));

        // 서명 추출
        // Extract signature
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        address signer = ecrecover(txHash, v, r, s);
        require(signer != address(0), "Invalid signature");

        bool isOwner = (signer == owner);
        bool isSessionKey = false;

        if (!isOwner) {
            // 세션 키 검증
            // Validate session key
            SessionKey storage session = sessionKeys[signer];

            require(session.isActive, "Session key not active");
            require(session.expiresAt > block.timestamp, "Session key expired");
            require(session.spent + value <= session.spendLimit, "Spend limit exceeded");

            // 허용된 대상 확인
            // Check allowed targets
            if (session.allowedTargets.length > 0) {
                bool targetAllowed = false;
                for (uint256 i = 0; i < session.allowedTargets.length; i++) {
                    if (session.allowedTargets[i] == to) {
                        targetAllowed = true;
                        break;
                    }
                }
                require(targetAllowed, "Target not allowed");
            }

            // 지출 금액 업데이트
            // Update spent amount
            session.spent += value;
            isSessionKey = true;
        }

        nonce++;

        // 트랜잭션 실행
        // Execute transaction
        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "Transaction failed");

        emit TransactionExecuted(signer, to, value, isSessionKey);

        return result;
    }

    /**
     * @dev 세션 키 정보 조회
     * @dev Get session key information
     */
    function getSessionKeyInfo(address key) external view returns (
        bool isActive,
        uint256 expiresAt,
        uint256 spendLimit,
        uint256 spent,
        address[] memory allowedTargets
    ) {
        SessionKey storage session = sessionKeys[key];
        return (
            session.isActive,
            session.expiresAt,
            session.spendLimit,
            session.spent,
            session.allowedTargets
        );
    }

    /**
     * @dev 세션 키 유효성 확인
     * @dev Check if session key is valid
     */
    function isSessionKeyValid(address key) external view returns (bool) {
        SessionKey storage session = sessionKeys[key];
        return session.isActive &&
               session.expiresAt > block.timestamp &&
               session.spent < session.spendLimit;
    }

    /**
     * @dev 소유자 변경
     * @dev Change owner
     */
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }

    receive() external payable {}

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title SocialRecoveryWallet
 * @dev 소셜 복구 기능을 가진 스마트 컨트랙트 지갑
 * @dev Smart contract wallet with social recovery functionality
 *
 * 신뢰할 수 있는 가디언들이 소유자 복구를 도울 수 있습니다.
 * Trusted guardians can help recover ownership.
 */
contract SocialRecoveryWallet is IERC1271 {
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    address public owner;
    address[] public guardians;
    mapping(address => bool) public isGuardian;

    uint256 public recoveryThreshold;
    uint256 public recoveryLockPeriod;

    /**
     * @dev 복구 요청 정보
     * @dev Recovery request information
     */
    struct RecoveryRequest {
        address proposedOwner;
        uint256 approvalCount;
        uint256 requestTime;
        mapping(address => bool) hasApproved;
        bool executed;
    }

    RecoveryRequest public activeRecovery;

    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event RecoveryInitiated(address indexed proposedOwner);
    event RecoverySupported(address indexed guardian);
    event RecoveryExecuted(address indexed newOwner);
    event RecoveryCancelled();

    constructor(
        address[] memory _guardians,
        uint256 _recoveryThreshold,
        uint256 _recoveryLockPeriod
    ) {
        require(_guardians.length > 0, "Guardians required");
        require(
            _recoveryThreshold > 0 && _recoveryThreshold <= _guardians.length,
            "Invalid threshold"
        );

        owner = msg.sender;
        recoveryThreshold = _recoveryThreshold;
        recoveryLockPeriod = _recoveryLockPeriod;

        for (uint256 i = 0; i < _guardians.length; i++) {
            address guardian = _guardians[i];
            require(guardian != address(0), "Invalid guardian");
            require(!isGuardian[guardian], "Duplicate guardian");

            isGuardian[guardian] = true;
            guardians.push(guardian);

            emit GuardianAdded(guardian);
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "Not guardian");
        _;
    }

    /**
     * @dev EIP-1271 서명 검증
     * @dev EIP-1271 signature validation
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        address signer = ecrecover(hash, v, r, s);

        return (signer == owner) ? MAGICVALUE : bytes4(0xffffffff);
    }

    /**
     * @dev 복구 시작
     * @dev Initiate recovery
     */
    function initiateRecovery(address newOwner) external onlyGuardian {
        require(newOwner != address(0), "Invalid new owner");
        require(newOwner != owner, "Same as current owner");
        require(!activeRecovery.executed, "Recovery already executed");

        // 새로운 복구 요청 시작
        // Start new recovery request
        activeRecovery.proposedOwner = newOwner;
        activeRecovery.approvalCount = 1;
        activeRecovery.requestTime = block.timestamp;
        activeRecovery.hasApproved[msg.sender] = true;
        activeRecovery.executed = false;

        emit RecoveryInitiated(newOwner);
        emit RecoverySupported(msg.sender);
    }

    /**
     * @dev 복구 지원
     * @dev Support recovery
     */
    function supportRecovery() external onlyGuardian {
        require(activeRecovery.proposedOwner != address(0), "No active recovery");
        require(!activeRecovery.executed, "Recovery already executed");
        require(!activeRecovery.hasApproved[msg.sender], "Already supported");

        activeRecovery.hasApproved[msg.sender] = true;
        activeRecovery.approvalCount++;

        emit RecoverySupported(msg.sender);

        // 임계값 도달 시 자동 실행
        // Auto-execute when threshold is reached
        if (activeRecovery.approvalCount >= recoveryThreshold &&
            block.timestamp >= activeRecovery.requestTime + recoveryLockPeriod) {
            _executeRecovery();
        }
    }

    /**
     * @dev 복구 실행
     * @dev Execute recovery
     */
    function executeRecovery() external {
        require(activeRecovery.proposedOwner != address(0), "No active recovery");
        require(!activeRecovery.executed, "Recovery already executed");
        require(activeRecovery.approvalCount >= recoveryThreshold, "Insufficient approvals");
        require(
            block.timestamp >= activeRecovery.requestTime + recoveryLockPeriod,
            "Lock period not expired"
        );

        _executeRecovery();
    }

    /**
     * @dev 내부 복구 실행 함수
     * @dev Internal recovery execution function
     */
    function _executeRecovery() private {
        address newOwner = activeRecovery.proposedOwner;
        activeRecovery.executed = true;

        owner = newOwner;

        emit RecoveryExecuted(newOwner);
    }

    /**
     * @dev 복구 취소 (소유자만)
     * @dev Cancel recovery (owner only)
     */
    function cancelRecovery() external onlyOwner {
        require(activeRecovery.proposedOwner != address(0), "No active recovery");
        require(!activeRecovery.executed, "Recovery already executed");

        delete activeRecovery;

        emit RecoveryCancelled();
    }

    /**
     * @dev 가디언 추가
     * @dev Add guardian
     */
    function addGuardian(address guardian) external onlyOwner {
        require(guardian != address(0), "Invalid guardian");
        require(!isGuardian[guardian], "Already guardian");

        isGuardian[guardian] = true;
        guardians.push(guardian);

        emit GuardianAdded(guardian);
    }

    /**
     * @dev 가디언 제거
     * @dev Remove guardian
     */
    function removeGuardian(address guardian) external onlyOwner {
        require(isGuardian[guardian], "Not guardian");

        isGuardian[guardian] = false;

        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == guardian) {
                guardians[i] = guardians[guardians.length - 1];
                guardians.pop();
                break;
            }
        }

        emit GuardianRemoved(guardian);
    }

    /**
     * @dev 가디언 목록 조회
     * @dev Get guardian list
     */
    function getGuardians() external view returns (address[] memory) {
        return guardians;
    }

    receive() external payable {}
}
