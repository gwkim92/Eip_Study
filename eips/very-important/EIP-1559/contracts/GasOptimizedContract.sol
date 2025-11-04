// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title GasOptimizedContract
 * @notice EIP-1559 환경에서 가스 최적화 베스트 프랙티스 예제
 * @dev 이 컨트랙트는 다양한 가스 최적화 기법을 보여줍니다
 */
contract GasOptimizedContract {
    // ============================================================
    // 1. STORAGE PACKING (스토리지 패킹)
    // ============================================================

    // ❌ 비효율적인 방법: 각각 별도 슬롯 사용
    // uint256 public inefficientValue1;  // Slot 0
    // uint256 public inefficientValue2;  // Slot 1
    // uint256 public inefficientValue3;  // Slot 2
    // 총 3개 슬롯 = 3 × SSTORE 비용

    // ✅ 효율적인 방법: 구조체로 패킹
    struct PackedData {
        uint128 value1;
        uint128 value2;  // Slot 0에 value1, value2 함께 저장
        uint256 value3;  // Slot 1
    }

    PackedData public packedData;  // 총 2개 슬롯만 사용

    /**
     * @notice 패킹된 데이터 저장 (가스 절약)
     */
    function setPackedData(uint128 v1, uint128 v2, uint256 v3) external {
        packedData.value1 = v1;
        packedData.value2 = v2;
        packedData.value3 = v3;
        // 가스 절약: ~20,000 gas 절약
    }

    // ✅ 더 효율적: 비트 패킹
    uint256 private _bitPacked;

    /**
     * @notice 비트 레벨 패킹 (최대 절약)
     * @dev 2개의 uint128을 하나의 uint256에 저장
     */
    function setBitPacked(uint128 v1, uint128 v2) external {
        _bitPacked = uint256(v1) | (uint256(v2) << 128);
        // 1번의 SSTORE만 사용 = ~40,000 gas 절약
    }

    function getBitPackedValue1() external view returns (uint128) {
        return uint128(_bitPacked);
    }

    function getBitPackedValue2() external view returns (uint128) {
        return uint128(_bitPacked >> 128);
    }

    // ============================================================
    // 2. CALLDATA vs MEMORY (데이터 위치 최적화)
    // ============================================================

    /**
     * @notice ✅ 효율적: calldata 사용 (읽기만 할 경우)
     * @dev calldata는 메모리 복사 비용이 없음
     */
    function processArrayCalldata(uint256[] calldata data)
        external
        pure
        returns (uint256 sum)
    {
        for (uint256 i = 0; i < data.length; i++) {
            sum += data[i];
        }
        // calldata: ~3 gas per word (복사 비용 없음)
    }

    /**
     * @notice ❌ 비효율적: memory 사용 (불필요한 복사)
     * @dev 외부에서 전달된 배열을 메모리로 복사하는 비용 발생
     */
    function processArrayMemory(uint256[] memory data)
        external
        pure
        returns (uint256 sum)
    {
        for (uint256 i = 0; i < data.length; i++) {
            sum += data[i];
        }
        // memory: ~3 gas per word + 복사 비용
    }

    // ============================================================
    // 3. BATCH OPERATIONS (배치 작업 최적화)
    // ============================================================

    mapping(address => uint256) public balances;

    /**
     * @notice 여러 주소에 일괄 전송 (배치 처리)
     * @dev 개별 호출보다 가스 효율적
     */
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            balances[recipients[i]] += amounts[i];
        }
        // 배치로 처리하면 트랜잭션 오버헤드 감소
    }

    // ============================================================
    // 4. BASE FEE 기반 동적 처리
    // ============================================================

    uint256 public constant LOW_GAS_THRESHOLD = 20 gwei;
    uint256 public constant HIGH_GAS_THRESHOLD = 100 gwei;

    /**
     * @notice Base Fee에 따라 처리량 동적 조정
     * @dev 가스비 높을 때는 적게, 낮을 때는 많이 처리
     */
    function adaptiveBatchProcess(uint256[] calldata data) external {
        uint256 baseFee = block.basefee;
        uint256 processCount;

        if (baseFee < LOW_GAS_THRESHOLD) {
            // 가스비 저렴: 모두 처리
            processCount = data.length;
        } else if (baseFee < HIGH_GAS_THRESHOLD) {
            // 가스비 보통: 절반만 처리
            processCount = data.length / 2;
        } else {
            // 가스비 비쌈: 최소한만 처리
            processCount = data.length / 10;
            if (processCount == 0) processCount = 1;
        }

        for (uint256 i = 0; i < processCount; i++) {
            // 데이터 처리...
            _processData(data[i]);
        }
    }

    function _processData(uint256 data) private pure {
        // 실제 데이터 처리 로직
        data;  // 사용 표시
    }

    // ============================================================
    // 5. IMMUTABLE vs CONSTANT (불변 변수 최적화)
    // ============================================================

    // ✅ constant: 컴파일 타임에 결정, 바이트코드에 직접 삽입
    uint256 public constant CONSTANT_VALUE = 100;

    // ✅ immutable: 생성자에서 한 번만 설정, storage 대신 코드에 저장
    address public immutable IMMUTABLE_OWNER;
    uint256 public immutable IMMUTABLE_DEPLOY_TIME;

    // ❌ 일반 변수: storage에 저장 (비효율적)
    // address public owner;  // 매번 SLOAD 필요 (~2100 gas)

    constructor() {
        IMMUTABLE_OWNER = msg.sender;
        IMMUTABLE_DEPLOY_TIME = block.timestamp;
        // immutable은 생성 후 코드에 저장되어 SLOAD 비용 없음 (~100 gas)
    }

    // ============================================================
    // 6. SHORT CIRCUIT EVALUATION (단축 평가)
    // ============================================================

    /**
     * @notice ✅ 효율적: 빠른 실패 조건을 먼저 검사
     */
    function efficientCheck(address user, uint256 amount) external view returns (bool) {
        // 가스 비용이 낮은 검사를 먼저 수행
        if (user == address(0)) return false;  // 간단한 검사
        if (amount == 0) return false;         // 간단한 검사
        if (balances[user] < amount) return false;  // storage 읽기 (비용 높음)

        return true;
    }

    /**
     * @notice ❌ 비효율적: 비싼 검사를 먼저 수행
     */
    function inefficientCheck(address user, uint256 amount) external view returns (bool) {
        if (balances[user] < amount) return false;  // 비싼 검사를 먼저
        if (amount == 0) return false;
        if (user == address(0)) return false;

        return true;
    }

    // ============================================================
    // 7. EVENTS vs STORAGE (이벤트 활용)
    // ============================================================

    // ✅ 이벤트 사용: 가스 효율적 (로그 스토리지는 저렴)
    event DataProcessed(address indexed user, uint256 value, uint256 timestamp);

    // ❌ storage 배열: 매우 비쌈
    // struct ProcessRecord {
    //     address user;
    //     uint256 value;
    //     uint256 timestamp;
    // }
    // ProcessRecord[] public records;  // 비효율적!

    /**
     * @notice 이벤트로 기록 (권장)
     */
    function processWithEvent(uint256 value) external {
        // 비즈니스 로직...

        emit DataProcessed(msg.sender, value, block.timestamp);
        // 이벤트는 ~375 gas (storage는 ~20,000 gas)
    }

    // ============================================================
    // 8. UNCHECKED ARITHMETIC (체크 안된 연산)
    // ============================================================

    /**
     * @notice Solidity 0.8+ 오버플로우 체크 비활성화
     * @dev 오버플로우가 불가능한 경우에만 사용
     */
    function sumWithUnchecked(uint256[] calldata numbers)
        external
        pure
        returns (uint256 sum)
    {
        unchecked {
            // 루프에서 i++는 오버플로우 불가능
            for (uint256 i = 0; i < numbers.length; ++i) {
                sum += numbers[i];
            }
        }
        // unchecked 사용 시 ~100 gas per iteration 절약
    }

    // ============================================================
    // 9. MAPPING vs ARRAY (자료구조 선택)
    // ============================================================

    // ✅ 특정 키 접근이 필요한 경우: mapping
    mapping(address => bool) public whitelist;

    function addToWhitelist(address user) external {
        whitelist[user] = true;
        // O(1) 시간, ~20,000 gas
    }

    // ❌ 반복 필요한 경우만 array (비효율적)
    address[] public whitelistArray;

    function addToWhitelistArray(address user) external {
        whitelistArray.push(user);
        // O(1) 시간이지만 전체 조회는 O(n)
        // 배열 길이가 길어질수록 가스 증가
    }

    // ============================================================
    // 10. FUNCTION VISIBILITY (함수 가시성)
    // ============================================================

    /**
     * @notice external이 public보다 가스 효율적
     * @dev calldata를 직접 사용 가능
     */
    function externalFunction(uint256[] calldata data)
        external
        pure
        returns (uint256)
    {
        // calldata 직접 사용
        return data.length;
    }

    // public은 내부 호출 시 memory로 복사됨
    function publicFunction(uint256[] calldata data)
        public
        pure
        returns (uint256)
    {
        return data.length;
    }

    // ============================================================
    // 11. DELETE vs ZERO ASSIGNMENT (삭제 최적화)
    // ============================================================

    mapping(address => uint256) public deposits;

    /**
     * @notice ✅ delete 사용 (가스 환불 가능)
     */
    function withdrawOptimized(address user) external {
        uint256 amount = deposits[user];
        delete deposits[user];  // 가스 환불 가능 (EIP-3529 이후 제한적)

        // 실제 전송 로직...
        amount;
    }

    /**
     * @notice 0으로 설정 (같은 효과, 명시적)
     */
    function withdrawExplicit(address user) external {
        uint256 amount = deposits[user];
        deposits[user] = 0;  // delete와 동일한 효과

        amount;
    }

    // ============================================================
    // 12. CUSTOM ERRORS (커스텀 에러)
    // ============================================================

    // ✅ 효율적: Custom Errors (Solidity 0.8.4+)
    error InsufficientBalance(address user, uint256 requested, uint256 available);
    error Unauthorized(address caller);

    function transferWithCustomError(address to, uint256 amount) external {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(msg.sender, amount, balances[msg.sender]);
        }
        // ~50% 가스 절약 (vs require with string)

        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    // ❌ 비효율적: require with string
    function transferWithString(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        // 문자열 저장으로 가스 많이 소모

        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
}

/**
 * @title GasComparison
 * @notice 다양한 패턴의 가스 비교
 */
contract GasComparison {
    // 가스 비용 비교 테스트를 위한 컨트랙트

    uint256 public value1;
    uint256 public value2;

    /**
     * @notice 개별 저장: 2 × SSTORE
     * 가스: ~42,000
     */
    function storeIndividually(uint256 v1, uint256 v2) external {
        value1 = v1;
        value2 = v2;
    }

    struct Combined {
        uint128 val1;
        uint128 val2;
    }
    Combined public combined;

    /**
     * @notice 패킹 저장: 1 × SSTORE
     * 가스: ~21,000
     */
    function storePacked(uint128 v1, uint128 v2) external {
        combined.val1 = v1;
        combined.val2 = v2;
    }

    /**
     * @notice 가스 비교 결과
     * 패킹 사용 시 약 50% 가스 절약!
     */
}
