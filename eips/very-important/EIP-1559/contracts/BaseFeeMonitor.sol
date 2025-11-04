// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title BaseFeeMonitor
 * @notice EIP-1559 Base Fee 모니터링 및 분석 도구
 * @dev 현재 및 과거 Base Fee를 추적하고 통계를 제공합니다
 */
contract BaseFeeMonitor {
    // ============================================================
    // STORAGE
    // ============================================================

    /// @notice Base Fee 기록 구조체
    struct BaseFeeRecord {
        uint256 blockNumber;
        uint256 baseFee;
        uint256 timestamp;
        uint256 gasUsed;
        uint256 gasLimit;
    }

    /// @notice 최근 Base Fee 기록들 (최대 100개)
    BaseFeeRecord[] public history;

    /// @notice 기록 가능한 최대 개수
    uint256 public constant MAX_HISTORY = 100;

    /// @notice 통계 정보
    struct Statistics {
        uint256 min;
        uint256 max;
        uint256 average;
        uint256 median;
        uint256 sampleCount;
    }

    // ============================================================
    // EVENTS
    // ============================================================

    event BaseFeeRecorded(
        uint256 indexed blockNumber,
        uint256 baseFee,
        uint256 gasUsed,
        uint256 utilization
    );

    event HighBaseFeeAlert(uint256 baseFee, uint256 threshold);
    event LowBaseFeeAlert(uint256 baseFee, uint256 threshold);

    // ============================================================
    // ERRORS
    // ============================================================

    error NoDataAvailable();
    error InvalidBlockNumber();
    error ThresholdTooHigh();

    // ============================================================
    // MAIN FUNCTIONS
    // ============================================================

    /**
     * @notice 현재 Base Fee 조회
     * @return 현재 블록의 Base Fee (wei)
     */
    function getCurrentBaseFee() public view returns (uint256) {
        return block.basefee;
    }

    /**
     * @notice 현재 Base Fee 조회 (gwei 단위)
     * @return Base Fee in gwei
     */
    function getCurrentBaseFeeGwei() public view returns (uint256) {
        return block.basefee / 1 gwei;
    }

    /**
     * @notice 현재 블록 정보와 함께 Base Fee 기록
     * @dev 누구나 호출 가능, 최대 MAX_HISTORY개까지 저장
     */
    function recordBaseFee() external {
        // 최대 개수 초과 시 가장 오래된 것 제거
        if (history.length >= MAX_HISTORY) {
            _removeOldest();
        }

        uint256 currentBaseFee = block.basefee;
        uint256 gasUsed = 0;  // 과거 블록 정보는 가져올 수 없음
        uint256 gasLimit = block.gaslimit;

        history.push(
            BaseFeeRecord({
                blockNumber: block.number,
                baseFee: currentBaseFee,
                timestamp: block.timestamp,
                gasUsed: gasUsed,
                gasLimit: gasLimit
            })
        );

        emit BaseFeeRecorded(
            block.number,
            currentBaseFee,
            gasUsed,
            0  // utilization 계산 불가
        );
    }

    /**
     * @notice 가장 오래된 기록 제거
     */
    function _removeOldest() private {
        for (uint256 i = 0; i < history.length - 1; i++) {
            history[i] = history[i + 1];
        }
        history.pop();
    }

    // ============================================================
    // VIEW FUNCTIONS - BASE FEE INFO
    // ============================================================

    /**
     * @notice Base Fee가 특정 임계값보다 낮은지 확인
     * @param thresholdGwei 임계값 (gwei)
     * @return true if baseFee <= threshold
     */
    function isBaseFeeBelow(uint256 thresholdGwei) public view returns (bool) {
        return block.basefee <= thresholdGwei * 1 gwei;
    }

    /**
     * @notice Base Fee가 특정 임계값보다 높은지 확인
     * @param thresholdGwei 임계값 (gwei)
     * @return true if baseFee >= threshold
     */
    function isBaseFeeAbove(uint256 thresholdGwei) public view returns (bool) {
        return block.basefee >= thresholdGwei * 1 gwei;
    }

    /**
     * @notice Base Fee가 특정 범위 내에 있는지 확인
     * @param minGwei 최소값 (gwei)
     * @param maxGwei 최대값 (gwei)
     * @return true if minGwei <= baseFee <= maxGwei
     */
    function isBaseFeeInRange(uint256 minGwei, uint256 maxGwei)
        public
        view
        returns (bool)
    {
        uint256 currentBaseFee = block.basefee;
        return currentBaseFee >= minGwei * 1 gwei &&
               currentBaseFee <= maxGwei * 1 gwei;
    }

    /**
     * @notice Base Fee 수준 분류
     * @return level 0: Very Low, 1: Low, 2: Medium, 3: High, 4: Very High
     */
    function getBaseFeeLevel() public view returns (uint8 level) {
        uint256 baseFeeGwei = block.basefee / 1 gwei;

        if (baseFeeGwei < 20) {
            return 0;  // Very Low
        } else if (baseFeeGwei < 50) {
            return 1;  // Low
        } else if (baseFeeGwei < 100) {
            return 2;  // Medium
        } else if (baseFeeGwei < 200) {
            return 3;  // High
        } else {
            return 4;  // Very High
        }
    }

    /**
     * @notice Base Fee 수준을 문자열로 반환
     */
    function getBaseFeeDescription() public view returns (string memory) {
        uint8 level = getBaseFeeLevel();

        if (level == 0) return "Very Low (<20 gwei)";
        if (level == 1) return "Low (20-50 gwei)";
        if (level == 2) return "Medium (50-100 gwei)";
        if (level == 3) return "High (100-200 gwei)";
        return "Very High (>200 gwei)";
    }

    // ============================================================
    // BASE FEE PREDICTION
    // ============================================================

    /**
     * @notice 다음 블록의 Base Fee 예측 (간단한 버전)
     * @param currentUtilization 현재 블록 이용률 (0-100)
     * @return predictedBaseFee 예측된 다음 Base Fee
     */
    function predictNextBaseFee(uint256 currentUtilization)
        public
        view
        returns (uint256 predictedBaseFee)
    {
        uint256 currentBaseFee = block.basefee;

        if (currentUtilization == 50) {
            // 타겟과 동일: 유지
            return currentBaseFee;
        } else if (currentUtilization > 50) {
            // 타겟 초과: 증가 (최대 12.5%)
            uint256 utilizationDelta = currentUtilization - 50;
            uint256 increase = (currentBaseFee * utilizationDelta) / 50 / 8;
            return currentBaseFee + increase;
        } else {
            // 타겟 미만: 감소 (최대 12.5%)
            uint256 utilizationDelta = 50 - currentUtilization;
            uint256 decrease = (currentBaseFee * utilizationDelta) / 50 / 8;
            return currentBaseFee - decrease;
        }
    }

    /**
     * @notice N블록 후의 Base Fee 예측
     * @param blocksAhead 예측할 블록 수
     * @param assumedUtilization 가정하는 블록 이용률 (0-100)
     * @return predictedBaseFee 예측된 Base Fee
     */
    function predictBaseFeeAfterBlocks(
        uint256 blocksAhead,
        uint256 assumedUtilization
    ) public view returns (uint256 predictedBaseFee) {
        predictedBaseFee = block.basefee;

        for (uint256 i = 0; i < blocksAhead; i++) {
            predictedBaseFee = _calculateNextBaseFee(
                predictedBaseFee,
                assumedUtilization
            );
        }

        return predictedBaseFee;
    }

    /**
     * @notice 다음 Base Fee 계산 (내부 함수)
     */
    function _calculateNextBaseFee(
        uint256 currentBaseFee,
        uint256 utilization
    ) private pure returns (uint256) {
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
     * @notice 기록된 Base Fee 통계 계산
     * @return stats 통계 정보 (min, max, average, median)
     */
    function getStatistics() public view returns (Statistics memory stats) {
        if (history.length == 0) {
            revert NoDataAvailable();
        }

        uint256[] memory baseFees = new uint256[](history.length);
        uint256 sum = 0;

        // 데이터 수집
        for (uint256 i = 0; i < history.length; i++) {
            baseFees[i] = history[i].baseFee;
            sum += history[i].baseFee;

            // min, max 추적
            if (i == 0 || baseFees[i] < stats.min) {
                stats.min = baseFees[i];
            }
            if (baseFees[i] > stats.max) {
                stats.max = baseFees[i];
            }
        }

        // 평균 계산
        stats.average = sum / history.length;

        // 중앙값 계산 (간단한 정렬)
        _sortArray(baseFees);
        uint256 mid = baseFees.length / 2;
        if (baseFees.length % 2 == 0) {
            stats.median = (baseFees[mid - 1] + baseFees[mid]) / 2;
        } else {
            stats.median = baseFees[mid];
        }

        stats.sampleCount = history.length;

        return stats;
    }

    /**
     * @notice 배열 정렬 (버블 소트)
     * @dev 작은 배열에만 사용 권장
     */
    function _sortArray(uint256[] memory arr) private pure {
        uint256 n = arr.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    (arr[j], arr[j + 1]) = (arr[j + 1], arr[j]);
                }
            }
        }
    }

    /**
     * @notice 최근 N개 기록의 평균 Base Fee
     * @param count 평균을 계산할 최근 기록 수
     */
    function getRecentAverage(uint256 count)
        public
        view
        returns (uint256 average)
    {
        if (history.length == 0) {
            revert NoDataAvailable();
        }

        uint256 actualCount = count > history.length ? history.length : count;
        uint256 sum = 0;

        for (uint256 i = history.length - actualCount; i < history.length; i++) {
            sum += history[i].baseFee;
        }

        return sum / actualCount;
    }

    // ============================================================
    // ALERT FUNCTIONS
    // ============================================================

    /**
     * @notice Base Fee가 임계값을 초과하면 이벤트 발생
     * @param thresholdGwei 임계값 (gwei)
     */
    function checkHighBaseFee(uint256 thresholdGwei) external {
        uint256 currentBaseFee = block.basefee;
        uint256 threshold = thresholdGwei * 1 gwei;

        if (currentBaseFee >= threshold) {
            emit HighBaseFeeAlert(currentBaseFee, threshold);
        }
    }

    /**
     * @notice Base Fee가 임계값 이하이면 이벤트 발생
     * @param thresholdGwei 임계값 (gwei)
     */
    function checkLowBaseFee(uint256 thresholdGwei) external {
        uint256 currentBaseFee = block.basefee;
        uint256 threshold = thresholdGwei * 1 gwei;

        if (currentBaseFee <= threshold) {
            emit LowBaseFeeAlert(currentBaseFee, threshold);
        }
    }

    // ============================================================
    // COST ESTIMATION
    // ============================================================

    /**
     * @notice 특정 가스 사용량에 대한 비용 추정
     * @param gasAmount 사용할 가스량
     * @return costInWei Wei 단위 비용
     * @return costInGwei Gwei 단위 비용
     * @return costInEth ETH 단위 비용 (소수점 3자리)
     */
    function estimateCost(uint256 gasAmount)
        public
        view
        returns (
            uint256 costInWei,
            uint256 costInGwei,
            uint256 costInEth
        )
    {
        costInWei = block.basefee * gasAmount;
        costInGwei = costInWei / 1 gwei;
        costInEth = costInWei / 1 ether;

        return (costInWei, costInGwei, costInEth);
    }

    /**
     * @notice 다양한 시나리오에서의 비용 추정
     * @param gasAmount 사용할 가스량
     * @return minCost 최소 비용 (현재 Base Fee)
     * @return likelyCost 예상 비용 (Base Fee × 1.2)
     * @return maxCost 최대 비용 (Base Fee × 2)
     */
    function estimateCostRange(uint256 gasAmount)
        public
        view
        returns (
            uint256 minCost,
            uint256 likelyCost,
            uint256 maxCost
        )
    {
        uint256 currentBaseFee = block.basefee;

        minCost = currentBaseFee * gasAmount;
        likelyCost = (currentBaseFee * 12 / 10) * gasAmount;  // +20%
        maxCost = (currentBaseFee * 2) * gasAmount;           // +100%

        return (minCost, likelyCost, maxCost);
    }

    // ============================================================
    // UTILITY FUNCTIONS
    // ============================================================

    /**
     * @notice 기록 개수 조회
     */
    function getHistoryLength() public view returns (uint256) {
        return history.length;
    }

    /**
     * @notice 최근 기록 조회
     * @param count 조회할 기록 수
     */
    function getRecentHistory(uint256 count)
        public
        view
        returns (BaseFeeRecord[] memory)
    {
        if (history.length == 0) {
            revert NoDataAvailable();
        }

        uint256 actualCount = count > history.length ? history.length : count;
        BaseFeeRecord[] memory recent = new BaseFeeRecord[](actualCount);

        for (uint256 i = 0; i < actualCount; i++) {
            recent[i] = history[history.length - actualCount + i];
        }

        return recent;
    }

    /**
     * @notice 모든 기록 조회
     */
    function getAllHistory() public view returns (BaseFeeRecord[] memory) {
        return history;
    }

    /**
     * @notice 기록 초기화 (테스트용)
     */
    function clearHistory() external {
        delete history;
    }

    // ============================================================
    // WAIT TIME ESTIMATION
    // ============================================================

    /**
     * @notice Base Fee가 목표치에 도달하는데 필요한 블록 수 추정
     * @param targetBaseFeeGwei 목표 Base Fee (gwei)
     * @param assumedUtilization 가정하는 블록 이용률 (0-100)
     * @return blocks 예상 블록 수 (최대 100)
     */
    function estimateWaitBlocks(
        uint256 targetBaseFeeGwei,
        uint256 assumedUtilization
    ) public view returns (uint256 blocks) {
        uint256 currentBaseFee = block.basefee;
        uint256 targetBaseFee = targetBaseFeeGwei * 1 gwei;

        // 이미 목표치 이하면 0
        if (currentBaseFee <= targetBaseFee) {
            return 0;
        }

        // 최대 100블록까지만 계산
        uint256 simulatedBaseFee = currentBaseFee;
        blocks = 0;

        while (simulatedBaseFee > targetBaseFee && blocks < 100) {
            simulatedBaseFee = _calculateNextBaseFee(
                simulatedBaseFee,
                assumedUtilization
            );
            blocks++;
        }

        return blocks;
    }

    /**
     * @notice 블록 수를 시간으로 변환
     * @param blockCount 블록 수
     * @return seconds 예상 시간 (초)
     */
    function blocksToTime(uint256 blockCount)
        public
        pure
        returns (uint256)
    {
        return blockCount * 12;  // 이더리움 평균 블록 타임 12초
    }
}
