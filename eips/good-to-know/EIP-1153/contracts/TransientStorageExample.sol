// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24; // Transient storage requires 0.8.24+

/**
 * @title TransientStorageExample
 * @dev EIP-1153 Transient Storage Opcodes 구현 예제
 *
 * EIP-1153은 TSTORE와 TLOAD라는 새로운 opcodes를 도입합니다.
 * Transient storage는 트랜잭션 내에서만 유지되는 임시 저장소입니다.
 *
 * EIP-1153 introduces TSTORE and TLOAD opcodes.
 * Transient storage persists only within a single transaction.
 *
 * 주요 특징:
 * Key Features:
 * - 트랜잭션 종료 시 자동으로 초기화됨
 * - SSTORE보다 훨씬 저렴 (가스 비용 절감)
 * - 재진입 공격 방어에 유용
 * - 트랜잭션 간 통신에 사용 불가
 *
 * 가스 비용:
 * Gas Costs:
 * - TSTORE: ~100 gas (vs SSTORE: ~20,000 gas)
 * - TLOAD: ~100 gas (vs SLOAD: ~2,100 gas)
 */

/**
 * @title BasicTransientStorage
 * @dev 기본적인 Transient Storage 사용 예제
 * Basic transient storage usage
 */
contract BasicTransientStorage {
    /**
     * @dev Transient storage에 값 저장 및 읽기
     * Store and read from transient storage
     */
    function demonstrateTransientStorage(uint256 value) external returns (uint256) {
        // Transient storage에 저장
        assembly {
            tstore(0, value) // slot 0에 value 저장
        }

        // Transient storage에서 읽기
        uint256 retrieved;
        assembly {
            retrieved := tload(0) // slot 0에서 읽기
        }

        return retrieved; // 같은 값 반환
    }

    /**
     * @dev 트랜잭션 종료 후 transient storage는 초기화됨
     */
    function checkTransientAfterTransaction() external view returns (uint256) {
        uint256 value;
        assembly {
            value := tload(0) // 항상 0 반환 (새 트랜잭션)
        }
        return value;
    }

    /**
     * @dev 여러 슬롯 사용
     */
    function useMultipleSlots() external returns (uint256, uint256, uint256) {
        assembly {
            tstore(0, 100)
            tstore(1, 200)
            tstore(2, 300)
        }

        uint256 a;
        uint256 b;
        uint256 c;

        assembly {
            a := tload(0)
            b := tload(1)
            c := tload(2)
        }

        return (a, b, c);
    }
}

/**
 * @title ReentrancyGuardTransient
 * @dev Transient storage를 사용한 재진입 방어
 * Reentrancy guard using transient storage
 */
contract ReentrancyGuardTransient {
    // Transient storage 슬롯
    uint256 private constant REENTRANCY_GUARD_SLOT = 0;

    error ReentrancyDetected();

    /**
     * @dev Transient storage를 사용한 재진입 방어 modifier
     * 기존 SSTORE/SLOAD보다 훨씬 저렴
     */
    modifier nonReentrant() {
        uint256 status;

        assembly {
            status := tload(REENTRANCY_GUARD_SLOT)
        }

        if (status == 1) {
            revert ReentrancyDetected();
        }

        assembly {
            tstore(REENTRANCY_GUARD_SLOT, 1)
        }

        _;

        assembly {
            tstore(REENTRANCY_GUARD_SLOT, 0)
        }
    }

    /**
     * @dev 재진입 방어가 필요한 함수
     */
    function withdraw(uint256 amount) external nonReentrant {
        // 인출 로직
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}

/**
 * @title TransientLockMechanism
 * @dev Transient storage를 사용한 락 메커니즘
 * Lock mechanism using transient storage
 */
contract TransientLockMechanism {
    uint256 private constant LOCK_SLOT = 0;

    error AlreadyLocked();
    error NotLocked();

    event Locked(address indexed locker);
    event Unlocked(address indexed locker);

    /**
     * @dev 락 획득
     */
    function acquireLock() external {
        uint256 lockStatus;

        assembly {
            lockStatus := tload(LOCK_SLOT)
        }

        if (lockStatus != 0) {
            revert AlreadyLocked();
        }

        assembly {
            tstore(LOCK_SLOT, caller())
        }

        emit Locked(msg.sender);
    }

    /**
     * @dev 락 해제
     */
    function releaseLock() external {
        address currentLocker;

        assembly {
            currentLocker := tload(LOCK_SLOT)
        }

        if (currentLocker == address(0)) {
            revert NotLocked();
        }

        require(currentLocker == msg.sender, "Not lock owner");

        assembly {
            tstore(LOCK_SLOT, 0)
        }

        emit Unlocked(msg.sender);
    }

    /**
     * @dev 현재 락 상태 확인
     */
    function isLocked() external view returns (bool, address) {
        address locker;

        assembly {
            locker := tload(LOCK_SLOT)
        }

        return (locker != address(0), locker);
    }

    /**
     * @dev 락이 필요한 함수
     */
    function lockedOperation() external view returns (string memory) {
        address locker;

        assembly {
            locker := tload(LOCK_SLOT)
        }

        require(locker == msg.sender, "Must acquire lock first");
        return "Operation executed";
    }
}

/**
 * @title TransientCounter
 * @dev 트랜잭션 내 호출 횟수 추적
 * Track call count within a transaction
 */
contract TransientCounter {
    uint256 private constant COUNTER_SLOT = 0;

    event CallRecorded(uint256 callNumber);

    /**
     * @dev 호출 횟수 증가
     */
    function incrementCounter() external returns (uint256) {
        uint256 count;

        assembly {
            count := tload(COUNTER_SLOT)
            count := add(count, 1)
            tstore(COUNTER_SLOT, count)
        }

        emit CallRecorded(count);
        return count;
    }

    /**
     * @dev 현재 카운터 값 조회
     */
    function getCounter() external view returns (uint256) {
        uint256 count;

        assembly {
            count := tload(COUNTER_SLOT)
        }

        return count;
    }

    /**
     * @dev 여러 번 호출하는 함수
     */
    function multipleOperations() external returns (uint256[] memory) {
        uint256[] memory counts = new uint256[](3);

        counts[0] = this.incrementCounter();
        counts[1] = this.incrementCounter();
        counts[2] = this.incrementCounter();

        return counts; // [1, 2, 3]
    }
}

/**
 * @title TransientContextData
 * @dev 트랜잭션 컨텍스트 데이터 저장
 * Store transaction context data
 */
contract TransientContextData {
    struct Context {
        address initiator;
        uint256 startTime;
        uint256 gasAtStart;
    }

    uint256 private constant INITIATOR_SLOT = 0;
    uint256 private constant START_TIME_SLOT = 1;
    uint256 private constant GAS_AT_START_SLOT = 2;

    /**
     * @dev 트랜잭션 컨텍스트 초기화
     */
    function initializeContext() external {
        assembly {
            tstore(INITIATOR_SLOT, caller())
            tstore(START_TIME_SLOT, timestamp())
            tstore(GAS_AT_START_SLOT, gas())
        }
    }

    /**
     * @dev 컨텍스트 조회
     */
    function getContext() external view returns (Context memory) {
        Context memory ctx;

        assembly {
            mstore(ctx, tload(INITIATOR_SLOT))
            mstore(add(ctx, 0x20), tload(START_TIME_SLOT))
            mstore(add(ctx, 0x40), tload(GAS_AT_START_SLOT))
        }

        return ctx;
    }

    /**
     * @dev 실행 시간 계산
     */
    function getExecutionTime() external view returns (uint256) {
        uint256 startTime;

        assembly {
            startTime := tload(START_TIME_SLOT)
        }

        if (startTime == 0) {
            return 0;
        }

        return block.timestamp - startTime;
    }
}

/**
 * @title FlashLoanWithTransient
 * @dev Transient storage를 사용한 플래시 론
 * Flash loan using transient storage
 */
contract FlashLoanWithTransient {
    uint256 private constant FLASH_LOAN_SLOT = 0;
    uint256 private constant BORROWER_SLOT = 1;

    error FlashLoanInProgress();
    error FlashLoanNotRepaid();
    error Unauthorized();

    event FlashLoanExecuted(address indexed borrower, uint256 amount);

    mapping(address => uint256) public balances;

    /**
     * @dev 플래시 론 실행
     */
    function flashLoan(uint256 amount, bytes calldata data) external {
        uint256 loanAmount;

        assembly {
            loanAmount := tload(FLASH_LOAN_SLOT)
        }

        if (loanAmount != 0) {
            revert FlashLoanInProgress();
        }

        uint256 balanceBefore = address(this).balance;

        // 플래시 론 상태 저장
        assembly {
            tstore(FLASH_LOAN_SLOT, amount)
            tstore(BORROWER_SLOT, caller())
        }

        // 빌려주기
        (bool success, ) = msg.sender.call{value: amount}(data);
        require(success, "Flash loan callback failed");

        // 상환 확인
        uint256 balanceAfter = address(this).balance;
        if (balanceAfter < balanceBefore + amount) {
            revert FlashLoanNotRepaid();
        }

        // 상태 초기화
        assembly {
            tstore(FLASH_LOAN_SLOT, 0)
            tstore(BORROWER_SLOT, 0)
        }

        emit FlashLoanExecuted(msg.sender, amount);
    }

    /**
     * @dev 현재 플래시 론 정보
     */
    function getFlashLoanInfo() external view returns (uint256 amount, address borrower) {
        assembly {
            amount := tload(FLASH_LOAN_SLOT)
            borrower := tload(BORROWER_SLOT)
        }
    }

    receive() external payable {}
}

/**
 * @title TransientWhitelist
 * @dev 트랜잭션 내에서만 유효한 화이트리스트
 * Transaction-scoped whitelist
 */
contract TransientWhitelist {
    uint256 private constant WHITELIST_BASE_SLOT = 1000;

    event AddressWhitelisted(address indexed account);
    event AddressRemoved(address indexed account);

    /**
     * @dev 주소 화이트리스트 추가
     */
    function addToWhitelist(address account) external {
        uint256 slot = WHITELIST_BASE_SLOT + uint256(uint160(account));

        assembly {
            tstore(slot, 1)
        }

        emit AddressWhitelisted(account);
    }

    /**
     * @dev 화이트리스트 제거
     */
    function removeFromWhitelist(address account) external {
        uint256 slot = WHITELIST_BASE_SLOT + uint256(uint160(account));

        assembly {
            tstore(slot, 0)
        }

        emit AddressRemoved(account);
    }

    /**
     * @dev 화이트리스트 확인
     */
    function isWhitelisted(address account) external view returns (bool) {
        uint256 slot = WHITELIST_BASE_SLOT + uint256(uint160(account));
        uint256 status;

        assembly {
            status := tload(slot)
        }

        return status == 1;
    }

    /**
     * @dev 화이트리스트 전용 함수
     */
    function whitelistOnlyFunction() external view returns (string memory) {
        uint256 slot = WHITELIST_BASE_SLOT + uint256(uint160(msg.sender));
        uint256 status;

        assembly {
            status := tload(slot)
        }

        require(status == 1, "Not whitelisted");
        return "Access granted";
    }
}

/**
 * @title GasComparisonTransient
 * @dev Transient storage vs 일반 storage 가스 비교
 * Gas comparison: transient vs regular storage
 */
contract GasComparisonTransient {
    uint256 public regularStorage;

    event GasMeasured(string operation, uint256 gasUsed);

    /**
     * @dev 일반 storage 사용
     */
    function useRegularStorage(uint256 value) external returns (uint256 gasUsed) {
        uint256 gasBefore = gasleft();

        regularStorage = value;
        uint256 retrieved = regularStorage;

        gasUsed = gasBefore - gasleft();
        emit GasMeasured("Regular Storage", gasUsed);

        return retrieved;
    }

    /**
     * @dev Transient storage 사용
     */
    function useTransientStorage(uint256 value) external returns (uint256 gasUsed) {
        uint256 gasBefore = gasleft();

        assembly {
            tstore(0, value)
        }

        uint256 retrieved;
        assembly {
            retrieved := tload(0)
        }

        gasUsed = gasBefore - gasleft();
        emit GasMeasured("Transient Storage", gasUsed);

        return retrieved;
    }

    /**
     * @dev 가스 비교 실행
     */
    function compareGas(uint256 value)
        external
        returns (uint256 regularGas, uint256 transientGas, uint256 savings)
    {
        regularGas = this.useRegularStorage(value);
        transientGas = this.useTransientStorage(value);
        savings = regularGas - transientGas;

        return (regularGas, transientGas, savings);
    }
}

/**
 * @title MultiContractTransient
 * @dev 여러 컨트랙트 간 transient storage 공유
 * Transient storage sharing across contracts
 */
contract TransientStorageProvider {
    uint256 private constant SHARED_SLOT = 9999;

    function setSharedValue(uint256 value) external {
        assembly {
            tstore(SHARED_SLOT, value)
        }
    }

    function getSharedValue() external view returns (uint256) {
        uint256 value;
        assembly {
            value := tload(SHARED_SLOT)
        }
        return value;
    }
}

contract TransientStorageConsumer {
    TransientStorageProvider public provider;

    constructor(TransientStorageProvider _provider) {
        provider = _provider;
    }

    /**
     * @dev 다른 컨트랙트에서 설정한 값 사용
     * 주의: Transient storage는 컨트랙트별로 격리되어 있음
     */
    function useSharedValue() external {
        // Provider에 값 설정
        provider.setSharedValue(12345);

        // Provider에서 값 읽기
        uint256 value = provider.getSharedValue();

        require(value == 12345, "Value mismatch");
    }
}

/**
 * @title TransientStorageBestPractices
 * @dev Transient storage 사용 모범 사례
 * Best practices for transient storage
 */
contract TransientStorageBestPractices {
    /**
     * Transient Storage 사용이 적합한 경우:
     * When to use transient storage:
     *
     * 1. 재진입 방어
     *    Reentrancy guards
     *    - 기존 SSTORE보다 ~99% 저렴
     *
     * 2. 트랜잭션 내 임시 플래그
     *    Temporary flags within a transaction
     *    - 락, 상태 추적 등
     *
     * 3. 플래시 론
     *    Flash loans
     *    - 대출/상환 상태 추적
     *
     * 4. 가스 최적화가 중요한 배치 작업
     *    Gas-sensitive batch operations
     *
     * 5. 트랜잭션 컨텍스트 데이터
     *    Transaction context data
     *
     * 사용하면 안 되는 경우:
     * When NOT to use:
     *
     * 1. 영구 저장이 필요한 경우
     *    Persistent storage needed
     *
     * 2. 트랜잭션 간 데이터 공유
     *    Cross-transaction data sharing
     *
     * 3. 외부에서 읽어야 하는 상태
     *    State that needs to be read externally
     *
     * 가스 절감:
     * Gas savings:
     * - SSTORE: ~20,000 gas → TSTORE: ~100 gas
     * - SLOAD: ~2,100 gas → TLOAD: ~100 gas
     * - 재진입 방어: ~95% 가스 절감
     */

    uint256 private constant TEMP_SLOT = 0;

    /**
     * @dev 모범 사례: 재진입 방어
     */
    function bestPracticeReentrancy() external {
        // Transient storage로 재진입 체크
        uint256 entered;
        assembly {
            entered := tload(TEMP_SLOT)
        }
        require(entered == 0, "Reentrancy");

        assembly {
            tstore(TEMP_SLOT, 1)
        }

        // 작업 수행
        _doWork();

        assembly {
            tstore(TEMP_SLOT, 0)
        }
    }

    function _doWork() internal pure {
        // 실제 작업
    }
}
