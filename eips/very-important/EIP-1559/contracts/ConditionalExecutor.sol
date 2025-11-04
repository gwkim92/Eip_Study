// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title ConditionalExecutor
 * @notice Base Fee에 따라 조건부로 작업을 실행하는 스마트 컨트랙트
 * @dev 가스비가 낮을 때만 작업을 실행하거나, 높을 때 작업을 예약하는 기능 제공
 */
contract ConditionalExecutor {
    // ============================================================
    // STORAGE
    // ============================================================

    /// @notice 작업 구조체
    struct Task {
        bytes32 taskId;
        address creator;
        bytes data;
        uint256 maxBaseFeeGwei;
        uint256 createdAt;
        uint256 executedAt;
        bool executed;
    }

    /// @notice 작업 ID -> 작업 정보
    mapping(bytes32 => Task) public tasks;

    /// @notice 모든 작업 ID 리스트
    bytes32[] public taskIds;

    /// @notice 실행된 작업 개수
    uint256 public executedCount;

    /// @notice 컨트랙트 소유자
    address public owner;

    // ============================================================
    // MODIFIERS
    // ============================================================

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier maxBaseFee(uint256 maxFeeGwei) {
        require(
            block.basefee <= maxFeeGwei * 1 gwei,
            "Base fee too high"
        );
        _;
    }

    // ============================================================
    // EVENTS
    // ============================================================

    event TaskScheduled(
        bytes32 indexed taskId,
        address indexed creator,
        uint256 maxBaseFee,
        uint256 timestamp
    );

    event TaskExecuted(
        bytes32 indexed taskId,
        address indexed executor,
        uint256 actualBaseFee,
        uint256 timestamp
    );

    event TaskCancelled(
        bytes32 indexed taskId,
        address indexed canceller,
        uint256 timestamp
    );

    event BaseFeeConditionMet(uint256 baseFee, uint256 threshold);
    event BaseFeeConditionFailed(uint256 baseFee, uint256 threshold);

    // ============================================================
    // ERRORS
    // ============================================================

    error TaskNotFound(bytes32 taskId);
    error TaskAlreadyExecuted(bytes32 taskId);
    error BaseFeeT ooHigh(uint256 current, uint256 max);
    error Unauthorized(address caller);
    error TaskExecutionFailed(bytes32 taskId);

    // ============================================================
    // CONSTRUCTOR
    // ============================================================

    constructor() {
        owner = msg.sender;
    }

    // ============================================================
    // TASK SCHEDULING
    // ============================================================

    /**
     * @notice 가스비가 낮을 때 실행될 작업 예약
     * @param taskId 작업 고유 ID
     * @param taskData 실행할 작업 데이터 (calldata)
     * @param maxBaseFeeGwei 최대 허용 Base Fee (gwei)
     */
    function scheduleTask(
        bytes32 taskId,
        bytes calldata taskData,
        uint256 maxBaseFeeGwei
    ) external {
        require(tasks[taskId].creator == address(0), "Task already exists");

        tasks[taskId] = Task({
            taskId: taskId,
            creator: msg.sender,
            data: taskData,
            maxBaseFeeGwei: maxBaseFeeGwei,
            createdAt: block.timestamp,
            executedAt: 0,
            executed: false
        });

        taskIds.push(taskId);

        emit TaskScheduled(
            taskId,
            msg.sender,
            maxBaseFeeGwei * 1 gwei,
            block.timestamp
        );
    }

    /**
     * @notice 작업 실행 (Base Fee 조건 만족 시)
     * @param taskId 실행할 작업 ID
     */
    function executeTask(bytes32 taskId) external {
        Task storage task = tasks[taskId];

        if (task.creator == address(0)) {
            revert TaskNotFound(taskId);
        }

        if (task.executed) {
            revert TaskAlreadyExecuted(taskId);
        }

        uint256 currentBaseFee = block.basefee;
        uint256 maxBaseFee = task.maxBaseFeeGwei * 1 gwei;

        if (currentBaseFee > maxBaseFee) {
            revert BaseFeeT ooHigh(currentBaseFee, maxBaseFee);
        }

        // 작업 실행
        (bool success, ) = address(this).call(task.data);
        if (!success) {
            revert TaskExecutionFailed(taskId);
        }

        // 상태 업데이트
        task.executed = true;
        task.executedAt = block.timestamp;
        executedCount++;

        emit TaskExecuted(taskId, msg.sender, currentBaseFee, block.timestamp);
    }

    /**
     * @notice 작업 취소
     * @param taskId 취소할 작업 ID
     */
    function cancelTask(bytes32 taskId) external {
        Task storage task = tasks[taskId];

        if (task.creator == address(0)) {
            revert TaskNotFound(taskId);
        }

        if (task.creator != msg.sender && msg.sender != owner) {
            revert Unauthorized(msg.sender);
        }

        if (task.executed) {
            revert TaskAlreadyExecuted(taskId);
        }

        // 작업 삭제
        delete tasks[taskId];

        emit TaskCancelled(taskId, msg.sender, block.timestamp);
    }

    // ============================================================
    // BASE FEE CONDITIONS
    // ============================================================

    /**
     * @notice Base Fee가 특정 값 이하일 때만 실행
     * @param maxFeeGwei 최대 허용 Base Fee (gwei)
     */
    function executeIfBaseFeeBelow(uint256 maxFeeGwei)
        external
        maxBaseFee(maxFeeGwei)
    {
        // Base Fee 조건을 만족하면 이 함수 실행 가능
        emit BaseFeeConditionMet(block.basefee, maxFeeGwei * 1 gwei);
    }

    /**
     * @notice Base Fee가 범위 내에 있을 때만 실행
     * @param minFeeGwei 최소 Base Fee (gwei)
     * @param maxFeeGwei 최대 Base Fee (gwei)
     */
    function executeInBaseFeeRange(uint256 minFeeGwei, uint256 maxFeeGwei)
        external
    {
        uint256 currentBaseFee = block.basefee;
        uint256 minFee = minFeeGwei * 1 gwei;
        uint256 maxFee = maxFeeGwei * 1 gwei;

        require(
            currentBaseFee >= minFee && currentBaseFee <= maxFee,
            "Base fee out of range"
        );

        emit BaseFeeConditionMet(currentBaseFee, maxFee);
    }

    /**
     * @notice Base Fee 레벨에 따라 다른 로직 실행
     * @dev 0: Very Low, 1: Low, 2: Medium, 3: High, 4: Very High
     */
    function executeByBaseFeeLevel() external {
        uint256 baseFeeGwei = block.basefee / 1 gwei;
        uint8 level;

        if (baseFeeGwei < 20) {
            level = 0;  // Very Low
            _executeVeryLowGasLogic();
        } else if (baseFeeGwei < 50) {
            level = 1;  // Low
            _executeLowGasLogic();
        } else if (baseFeeGwei < 100) {
            level = 2;  // Medium
            _executeMediumGasLogic();
        } else if (baseFeeGwei < 200) {
            level = 3;  // High
            _executeHighGasLogic();
        } else {
            level = 4;  // Very High
            revert("Base fee too high for execution");
        }

        level;  // 사용 표시
    }

    // ============================================================
    // INTERNAL LOGIC (Example)
    // ============================================================

    function _executeVeryLowGasLogic() private pure {
        // 복잡한 작업 수행
    }

    function _executeLowGasLogic() private pure {
        // 보통 작업 수행
    }

    function _executeMediumGasLogic() private pure {
        // 간단한 작업 수행
    }

    function _executeHighGasLogic() private pure {
        // 최소한의 작업만
    }

    // ============================================================
    // BATCH PROCESSING
    // ============================================================

    /**
     * @notice 배치 크기를 Base Fee에 따라 동적 조정
     * @param items 처리할 아이템 배열
     */
    function dynamicBatchProcess(uint256[] calldata items) external {
        uint256 baseFeeGwei = block.basefee / 1 gwei;
        uint256 batchSize;

        if (baseFeeGwei < 20) {
            batchSize = items.length;  // 모두 처리
        } else if (baseFeeGwei < 50) {
            batchSize = items.length * 75 / 100;  // 75% 처리
        } else if (baseFeeGwei < 100) {
            batchSize = items.length / 2;  // 50% 처리
        } else {
            batchSize = items.length / 10;  // 10% 처리
            if (batchSize == 0) batchSize = 1;
        }

        for (uint256 i = 0; i < batchSize; i++) {
            _processItem(items[i]);
        }
    }

    function _processItem(uint256 item) private pure {
        // 아이템 처리 로직
        item;
    }

    // ============================================================
    // QUERY FUNCTIONS
    // ============================================================

    /**
     * @notice 작업 실행 가능 여부 확인
     * @param taskId 확인할 작업 ID
     * @return canExecute 실행 가능 여부
     * @return reason 이유 (0: 실행 가능, 1: Base Fee 높음, 2: 이미 실행됨, 3: 작업 없음)
     */
    function canExecuteTask(bytes32 taskId)
        external
        view
        returns (bool canExecute, uint8 reason)
    {
        Task memory task = tasks[taskId];

        if (task.creator == address(0)) {
            return (false, 3);  // 작업 없음
        }

        if (task.executed) {
            return (false, 2);  // 이미 실행됨
        }

        uint256 currentBaseFee = block.basefee;
        uint256 maxBaseFee = task.maxBaseFeeGwei * 1 gwei;

        if (currentBaseFee > maxBaseFee) {
            return (false, 1);  // Base Fee 높음
        }

        return (true, 0);  // 실행 가능
    }

    /**
     * @notice 실행 가능한 모든 작업 조회
     * @return executableTasks 실행 가능한 작업 ID 배열
     */
    function getExecutableTasks() external view returns (bytes32[] memory) {
        uint256 count = 0;
        uint256 currentBaseFee = block.basefee;

        // 실행 가능한 작업 개수 계산
        for (uint256 i = 0; i < taskIds.length; i++) {
            Task memory task = tasks[taskIds[i]];
            if (!task.executed &&
                currentBaseFee <= task.maxBaseFeeGwei * 1 gwei) {
                count++;
            }
        }

        // 배열 생성 및 채우기
        bytes32[] memory executableTasks = new bytes32[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < taskIds.length; i++) {
            Task memory task = tasks[taskIds[i]];
            if (!task.executed &&
                currentBaseFee <= task.maxBaseFeeGwei * 1 gwei) {
                executableTasks[index] = taskIds[i];
                index++;
            }
        }

        return executableTasks;
    }

    /**
     * @notice 대기 중인 모든 작업 조회
     */
    function getPendingTasks() external view returns (bytes32[] memory) {
        uint256 count = 0;

        for (uint256 i = 0; i < taskIds.length; i++) {
            if (!tasks[taskIds[i]].executed) {
                count++;
            }
        }

        bytes32[] memory pendingTasks = new bytes32[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < taskIds.length; i++) {
            if (!tasks[taskIds[i]].executed) {
                pendingTasks[index] = taskIds[i];
                index++;
            }
        }

        return pendingTasks;
    }

    /**
     * @notice 작업 실행까지 예상 대기 블록 수
     * @param taskId 작업 ID
     * @param assumedUtilization 가정하는 블록 이용률 (0-100)
     * @return blocks 예상 블록 수 (최대 100)
     */
    function estimateWaitBlocks(bytes32 taskId, uint256 assumedUtilization)
        external
        view
        returns (uint256 blocks)
    {
        Task memory task = tasks[taskId];

        if (task.creator == address(0)) {
            revert TaskNotFound(taskId);
        }

        uint256 currentBaseFee = block.basefee;
        uint256 targetBaseFee = task.maxBaseFeeGwei * 1 gwei;

        // 이미 실행 가능하면 0
        if (currentBaseFee <= targetBaseFee) {
            return 0;
        }

        // Base Fee 감소 시뮬레이션
        uint256 simulatedBaseFee = currentBaseFee;
        blocks = 0;

        while (simulatedBaseFee > targetBaseFee && blocks < 100) {
            simulatedBaseFee = _predictNextBaseFee(
                simulatedBaseFee,
                assumedUtilization
            );
            blocks++;
        }

        return blocks;
    }

    /**
     * @notice 다음 Base Fee 예측 (내부 함수)
     */
    function _predictNextBaseFee(uint256 currentBaseFee, uint256 utilization)
        private
        pure
        returns (uint256)
    {
        if (utilization == 50) {
            return currentBaseFee;
        } else if (utilization > 50) {
            uint256 delta = (currentBaseFee * (utilization - 50)) / 50 / 8;
            return currentBaseFee + delta;
        } else {
            uint256 delta = (currentBaseFee * (50 - utilization)) / 50 / 8;
            return currentBaseFee - delta;
        }
    }

    // ============================================================
    // STATISTICS
    // ============================================================

    /**
     * @notice 작업 통계 조회
     * @return total 전체 작업 수
     * @return pending 대기 중인 작업 수
     * @return executed 실행된 작업 수
     */
    function getTaskStatistics()
        external
        view
        returns (
            uint256 total,
            uint256 pending,
            uint256 executed
        )
    {
        total = taskIds.length;
        executed = executedCount;
        pending = total - executed;

        return (total, pending, executed);
    }

    // ============================================================
    // ADMIN FUNCTIONS
    // ============================================================

    /**
     * @notice 소유자 변경
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    /**
     * @notice 긴급 정지 (모든 대기 작업 취소)
     */
    function emergencyStop() external onlyOwner {
        for (uint256 i = 0; i < taskIds.length; i++) {
            if (!tasks[taskIds[i]].executed) {
                delete tasks[taskIds[i]];
            }
        }
    }
}

/**
 * @title SimpleConditionalExample
 * @notice 간단한 조건부 실행 예제
 */
contract SimpleConditionalExample {
    uint256 public counter;

    event OperationExecuted(uint256 baseFee, uint256 newCounter);

    /**
     * @notice Base Fee가 50 gwei 이하일 때만 실행
     */
    function incrementIfCheap() external {
        require(block.basefee <= 50 gwei, "Gas too expensive");

        counter++;
        emit OperationExecuted(block.basefee, counter);
    }

    /**
     * @notice Base Fee 레벨에 따라 다른 증가폭
     */
    function adaptiveIncrement() external {
        uint256 baseFeeGwei = block.basefee / 1 gwei;
        uint256 increment;

        if (baseFeeGwei < 20) {
            increment = 10;  // 가스 저렴: 많이 증가
        } else if (baseFeeGwei < 50) {
            increment = 5;   // 가스 보통: 보통 증가
        } else if (baseFeeGwei < 100) {
            increment = 2;   // 가스 높음: 조금 증가
        } else {
            increment = 1;   // 가스 매우 높음: 최소 증가
        }

        counter += increment;
        emit OperationExecuted(block.basefee, counter);
    }
}
