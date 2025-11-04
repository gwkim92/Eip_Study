// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EIP7702Example
 * @dev EIP-7702 Set EOA Account Code 개념 및 예제
 *
 * EIP-7702는 EOA(Externally Owned Account)가 트랜잭션 실행 중에
 * 임시로 스마트 컨트랙트 코드를 가질 수 있게 합니다.
 *
 * EIP-7702 allows EOAs to temporarily have smart contract code
 * during transaction execution.
 *
 * 주요 특징:
 * Key Features:
 * - EOA가 트랜잭션 내에서만 컨트랙트처럼 동작
 * - 트랜잭션 종료 후 다시 일반 EOA로 복원
 * - Account Abstraction을 더 쉽게 구현
 * - 기존 EOA를 스마트 컨트랙트 지갑으로 업그레이드 가능
 *
 * 주의: EIP-7702는 프로토콜 레벨 변경이므로,
 * 이 예제는 개념적 구현과 사용 패턴을 보여줍니다.
 */

/**
 * @title DelegationContract
 * @dev EOA에 설정할 수 있는 위임 컨트랙트
 * Delegation contract that can be set for EOAs
 */
contract DelegationContract {
    // 트랜잭션 실행 권한 확인
    mapping(address => bool) public authorizedCallers;

    // 실행 기록
    event Executed(address indexed target, uint256 value, bytes data, bool success);
    event AuthorizedCallerAdded(address indexed caller);
    event AuthorizedCallerRemoved(address indexed caller);

    /**
     * @dev 호출자 인증
     */
    function addAuthorizedCaller(address caller) external {
        require(msg.sender == address(this), "Only self");
        authorizedCallers[caller] = true;
        emit AuthorizedCallerAdded(caller);
    }

    /**
     * @dev 호출자 인증 제거
     */
    function removeAuthorizedCaller(address caller) external {
        require(msg.sender == address(this), "Only self");
        authorizedCallers[caller] = false;
        emit AuthorizedCallerRemoved(caller);
    }

    /**
     * @dev 임의의 컨트랙트 호출 실행
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory)
    {
        // 인증된 호출자만 실행 가능
        require(authorizedCallers[msg.sender] || msg.sender == address(this), "Not authorized");

        (bool success, bytes memory result) = target.call{value: value}(data);

        emit Executed(target, value, data, success);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        return result;
    }

    /**
     * @dev 배치 실행
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (bytes[] memory) {
        require(authorizedCallers[msg.sender] || msg.sender == address(this), "Not authorized");
        require(
            targets.length == values.length && targets.length == datas.length,
            "Length mismatch"
        );

        bytes[] memory results = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call{value: values[i]}(datas[i]);

            emit Executed(targets[i], values[i], datas[i], success);

            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }

            results[i] = result;
        }

        return results;
    }

    /**
     * @dev 이더 수령
     */
    receive() external payable {}
}

/**
 * @title SessionBasedDelegation
 * @dev 세션 기반 위임 컨트랙트
 * Session-based delegation contract
 */
contract SessionBasedDelegation {
    struct Session {
        address operator;
        uint256 validUntil;
        uint256 gasLimit;
        uint256 gasUsed;
        bool active;
    }

    mapping(bytes32 => Session) public sessions;

    event SessionCreated(bytes32 indexed sessionId, address indexed operator, uint256 validUntil);
    event SessionRevoked(bytes32 indexed sessionId);
    event SessionExecuted(bytes32 indexed sessionId, uint256 gasUsed);

    /**
     * @dev 세션 생성
     */
    function createSession(
        address operator,
        uint256 duration,
        uint256 gasLimit,
        uint256 nonce
    ) external returns (bytes32 sessionId) {
        sessionId = keccak256(abi.encodePacked(msg.sender, operator, nonce, block.timestamp));

        sessions[sessionId] = Session({
            operator: operator,
            validUntil: block.timestamp + duration,
            gasLimit: gasLimit,
            gasUsed: 0,
            active: true
        });

        emit SessionCreated(sessionId, operator, block.timestamp + duration);
        return sessionId;
    }

    /**
     * @dev 세션 사용하여 실행
     */
    function executeWithSession(
        bytes32 sessionId,
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        Session storage session = sessions[sessionId];

        require(session.active, "Session not active");
        require(session.operator == msg.sender, "Not session operator");
        require(block.timestamp <= session.validUntil, "Session expired");

        uint256 gasBefore = gasleft();

        (bool success, bytes memory result) = target.call{value: value}(data);

        uint256 gasUsed = gasBefore - gasleft();
        session.gasUsed += gasUsed;

        require(session.gasUsed <= session.gasLimit, "Gas limit exceeded");

        emit SessionExecuted(sessionId, gasUsed);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        return result;
    }

    /**
     * @dev 세션 취소
     */
    function revokeSession(bytes32 sessionId) external {
        Session storage session = sessions[sessionId];
        require(session.active, "Session not active");

        session.active = false;
        emit SessionRevoked(sessionId);
    }

    receive() external payable {}
}

/**
 * @title MultiSigDelegation
 * @dev 다중 서명 위임 컨트랙트
 * Multi-signature delegation contract
 */
contract MultiSigDelegation {
    address[] public signers;
    uint256 public requiredSignatures;

    mapping(address => bool) public isSigner;
    mapping(bytes32 => mapping(address => bool)) public confirmations;
    mapping(bytes32 => bool) public executed;

    event SignerAdded(address indexed signer);
    event TransactionProposed(bytes32 indexed txHash, address indexed proposer);
    event TransactionConfirmed(bytes32 indexed txHash, address indexed signer);
    event TransactionExecuted(bytes32 indexed txHash, bool success);

    constructor(address[] memory signers_, uint256 requiredSignatures_) {
        require(signers_.length >= requiredSignatures_, "Invalid config");
        require(requiredSignatures_ > 0, "Required signatures must be > 0");

        for (uint256 i = 0; i < signers_.length; i++) {
            address signer = signers_[i];
            require(signer != address(0), "Invalid signer");
            require(!isSigner[signer], "Duplicate signer");

            isSigner[signer] = true;
            signers.push(signer);

            emit SignerAdded(signer);
        }

        requiredSignatures = requiredSignatures_;
    }

    /**
     * @dev 트랜잭션 제안
     */
    function proposeTransaction(address target, uint256 value, bytes memory data)
        external
        returns (bytes32)
    {
        require(isSigner[msg.sender], "Not a signer");

        bytes32 txHash = keccak256(abi.encodePacked(target, value, data, block.timestamp));

        require(!executed[txHash], "Already executed");

        confirmations[txHash][msg.sender] = true;

        emit TransactionProposed(txHash, msg.sender);
        emit TransactionConfirmed(txHash, msg.sender);

        return txHash;
    }

    /**
     * @dev 트랜잭션 승인
     */
    function confirmTransaction(bytes32 txHash) external {
        require(isSigner[msg.sender], "Not a signer");
        require(!executed[txHash], "Already executed");
        require(!confirmations[txHash][msg.sender], "Already confirmed");

        confirmations[txHash][msg.sender] = true;

        emit TransactionConfirmed(txHash, msg.sender);
    }

    /**
     * @dev 트랜잭션 실행
     */
    function executeTransaction(
        bytes32 txHash,
        address target,
        uint256 value,
        bytes memory data
    ) external {
        require(!executed[txHash], "Already executed");
        require(_isConfirmed(txHash), "Not enough confirmations");

        executed[txHash] = true;

        (bool success, ) = target.call{value: value}(data);

        emit TransactionExecuted(txHash, success);

        require(success, "Transaction failed");
    }

    /**
     * @dev 충분한 승인 확인
     */
    function _isConfirmed(bytes32 txHash) internal view returns (bool) {
        uint256 count = 0;

        for (uint256 i = 0; i < signers.length; i++) {
            if (confirmations[txHash][signers[i]]) {
                count++;
            }
        }

        return count >= requiredSignatures;
    }

    receive() external payable {}
}

/**
 * @title RecoveryDelegation
 * @dev 소셜 복구 기능이 있는 위임 컨트랙트
 * Delegation contract with social recovery
 */
contract RecoveryDelegation {
    address public owner;
    address[] public guardians;
    mapping(address => bool) public isGuardian;

    address public proposedOwner;
    mapping(address => bool) public recoveryApprovals;
    uint256 public recoveryApprovalsCount;
    uint256 public requiredApprovals;

    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event RecoveryProposed(address indexed newOwner);
    event RecoveryApproved(address indexed guardian, address indexed newOwner);
    event RecoveryExecuted(address indexed oldOwner, address indexed newOwner);

    constructor(address owner_, address[] memory guardians_, uint256 requiredApprovals_) {
        require(guardians_.length >= requiredApprovals_, "Invalid config");

        owner = owner_;
        requiredApprovals = requiredApprovals_;

        for (uint256 i = 0; i < guardians_.length; i++) {
            address guardian = guardians_[i];
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
     * @dev 복구 제안
     */
    function proposeRecovery(address newOwner) external onlyGuardian {
        require(newOwner != address(0), "Invalid new owner");

        proposedOwner = newOwner;
        recoveryApprovalsCount = 0;

        // 기존 승인 초기화
        for (uint256 i = 0; i < guardians.length; i++) {
            recoveryApprovals[guardians[i]] = false;
        }

        emit RecoveryProposed(newOwner);
    }

    /**
     * @dev 복구 승인
     */
    function approveRecovery() external onlyGuardian {
        require(proposedOwner != address(0), "No recovery proposed");
        require(!recoveryApprovals[msg.sender], "Already approved");

        recoveryApprovals[msg.sender] = true;
        recoveryApprovalsCount++;

        emit RecoveryApproved(msg.sender, proposedOwner);
    }

    /**
     * @dev 복구 실행
     */
    function executeRecovery() external {
        require(proposedOwner != address(0), "No recovery proposed");
        require(recoveryApprovalsCount >= requiredApprovals, "Not enough approvals");

        address oldOwner = owner;
        owner = proposedOwner;

        proposedOwner = address(0);
        recoveryApprovalsCount = 0;

        emit RecoveryExecuted(oldOwner, owner);
    }

    /**
     * @dev 가디언 추가 (소유자 전용)
     */
    function addGuardian(address guardian) external onlyOwner {
        require(guardian != address(0), "Invalid guardian");
        require(!isGuardian[guardian], "Already guardian");

        isGuardian[guardian] = true;
        guardians.push(guardian);

        emit GuardianAdded(guardian);
    }

    /**
     * @dev 실행 함수
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (bytes memory)
    {
        (bool success, bytes memory result) = target.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        return result;
    }

    receive() external payable {}
}

/**
 * @title GaslessTransactionDelegation
 * @dev 가스 없는 트랜잭션 위임
 * Gasless transaction delegation
 */
contract GaslessTransactionDelegation {
    mapping(address => uint256) public nonces;

    event Executed(
        address indexed signer,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 nonce
    );

    /**
     * @dev 메타 트랜잭션 실행
     */
    function executeMetaTransaction(
        address signer,
        address target,
        uint256 value,
        bytes calldata data,
        uint256 nonce,
        bytes calldata signature
    ) external payable returns (bytes memory) {
        require(nonce == nonces[signer], "Invalid nonce");

        // 서명 검증
        bytes32 hash = keccak256(
            abi.encodePacked(signer, target, value, data, nonce, address(this))
        );

        bytes32 ethSignedHash = getEthSignedMessageHash(hash);
        require(recoverSigner(ethSignedHash, signature) == signer, "Invalid signature");

        nonces[signer]++;

        // 실행
        (bool success, bytes memory result) = target.call{value: value}(data);

        emit Executed(signer, target, value, data, nonce);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        return result;
    }

    /**
     * @dev Ethereum 서명 메시지 해시
     */
    function getEthSignedMessageHash(bytes32 messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    /**
     * @dev 서명 복구
     */
    function recoverSigner(bytes32 hash, bytes memory signature) public pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return ecrecover(hash, v, r, s);
    }

    receive() external payable {}
}

/**
 * @title EIP7702Helper
 * @dev EIP-7702 헬퍼 함수
 * Helper functions for EIP-7702
 */
contract EIP7702Helper {
    /**
     * EIP-7702 사용 시나리오:
     * Use Cases:
     *
     * 1. EOA를 스마트 컨트랙트 지갑으로 업그레이드
     *    Upgrade EOA to smart contract wallet
     *
     * 2. 임시로 멀티시그 기능 사용
     *    Temporarily use multisig functionality
     *
     * 3. 가스 없는 트랜잭션 실행
     *    Execute gasless transactions
     *
     * 4. 배치 트랜잭션 실행
     *    Execute batch transactions
     *
     * 5. 소셜 복구 구현
     *    Implement social recovery
     *
     * 장점:
     * Benefits:
     * - 기존 EOA 유지하면서 스마트 컨트랙트 기능 사용
     * - 트랜잭션 종료 후 다시 일반 EOA로 복원
     * - Account Abstraction보다 간단한 구현
     * - 기존 인프라와 호환
     */

    /**
     * @dev 위임 컨트랙트 정보 조회
     */
    function getDelegationInfo(address delegation)
        external
        view
        returns (
            bool exists,
            uint256 codeSize,
            bytes32 codeHash
        )
    {
        codeSize = delegation.code.length;
        exists = codeSize > 0;

        assembly {
            codeHash := extcodehash(delegation)
        }

        return (exists, codeSize, codeHash);
    }
}

/**
 * @title EIP7702BestPractices
 * @dev EIP-7702 모범 사례
 */
contract EIP7702BestPractices {
    /**
     * EIP-7702 모범 사례:
     * Best Practices:
     *
     * 1. 보안
     *    Security:
     *    - 위임 컨트랙트 코드 검증
     *    - 권한 관리 철저히
     *    - 서명 검증 강화
     *
     * 2. 가스 효율성
     *    Gas Efficiency:
     *    - 배치 작업 활용
     *    - 최적화된 위임 컨트랙트
     *
     * 3. 사용자 경험
     *    User Experience:
     *    - 간단한 설정 과정
     *    - 명확한 권한 표시
     *    - 복구 메커니즘
     *
     * 4. 호환성
     *    Compatibility:
     *    - 표준 인터페이스 준수
     *    - 기존 도구와 호환
     */
}
