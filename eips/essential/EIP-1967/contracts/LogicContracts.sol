// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LogicContracts
 * @notice 프록시 패턴에서 사용되는 로직 컨트랙트들의 예제
 * @dev 이 파일은 업그레이드 가능한 컨트랙트의 V1과 V2 버전을 포함합니다.
 *
 * 프록시 패턴의 핵심 개념:
 * 1. 초기화 함수: constructor 대신 initialize 함수 사용
 * 2. 스토리지 레이아웃: 업그레이드 시 기존 변수 순서와 타입 유지
 * 3. 초기화 가드: 한 번만 초기화되도록 보장
 */

/**
 * @title LogicV1
 * @notice 첫 번째 버전의 로직 컨트랙트
 * @dev 기본적인 counter 기능을 제공하는 초기 구현
 *
 * 스토리지 레이아웃:
 * slot 0: initialized (bool)
 * slot 1: owner (address)
 * slot 2: counter (uint256)
 * slot 3: name (string)
 */
contract LogicV1 {
    // ============ 상태 변수 ============

    /**
     * @dev 초기화 여부를 나타내는 플래그
     * 프록시 패턴에서는 constructor를 사용할 수 없으므로
     * initialize 함수가 한 번만 호출되도록 보장합니다.
     */
    bool private initialized;

    /**
     * @dev 컨트랙트의 소유자 주소
     */
    address public owner;

    /**
     * @dev 카운터 값
     */
    uint256 public counter;

    /**
     * @dev 컨트랙트 이름
     */
    string public name;

    // ============ 이벤트 ============

    /**
     * @dev 초기화 완료 시 발생하는 이벤트
     */
    event Initialized(address indexed owner, string name);

    /**
     * @dev 카운터 증가 시 발생하는 이벤트
     */
    event CounterIncremented(uint256 newValue);

    /**
     * @dev 카운터 감소 시 발생하는 이벤트
     */
    event CounterDecremented(uint256 newValue);

    /**
     * @dev 소유자 변경 시 발생하는 이벤트
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Modifiers ============

    /**
     * @dev 소유자만 호출 가능하도록 제한
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "LogicV1: caller is not the owner");
        _;
    }

    // ============ 초기화 함수 ============

    /**
     * @dev 컨트랙트 초기화 함수 (constructor 대신 사용)
     * @param _owner 초기 소유자 주소
     * @param _name 컨트랙트 이름
     *
     * 주의사항:
     * - 프록시를 통해 배포 시 한 번만 호출되어야 함
     * - initialized 플래그로 재호출 방지
     * - 프록시 생성자나 upgradeToAndCall에서 호출됨
     */
    function initialize(address _owner, string memory _name) external {
        require(!initialized, "LogicV1: already initialized");
        require(_owner != address(0), "LogicV1: owner is zero address");

        initialized = true;
        owner = _owner;
        name = _name;
        counter = 0;

        emit Initialized(_owner, _name);
    }

    // ============ 핵심 기능 ============

    /**
     * @dev 카운터를 1 증가시킵니다.
     * @return 새로운 카운터 값
     */
    function increment() external returns (uint256) {
        counter += 1;
        emit CounterIncremented(counter);
        return counter;
    }

    /**
     * @dev 카운터를 1 감소시킵니다.
     * @return 새로운 카운터 값
     */
    function decrement() external returns (uint256) {
        require(counter > 0, "LogicV1: counter is already zero");
        counter -= 1;
        emit CounterDecremented(counter);
        return counter;
    }

    /**
     * @dev 현재 카운터 값을 조회합니다.
     * @return 현재 카운터 값
     */
    function getCounter() external view returns (uint256) {
        return counter;
    }

    /**
     * @dev 컨트랙트 정보를 조회합니다.
     * @return _name 컨트랙트 이름
     * @return _counter 현재 카운터 값
     * @return _owner 소유자 주소
     */
    function getInfo() external view returns (string memory _name, uint256 _counter, address _owner) {
        return (name, counter, owner);
    }

    // ============ 관리 기능 ============

    /**
     * @dev 소유권을 이전합니다.
     * @param newOwner 새로운 소유자 주소
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "LogicV1: new owner is zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @dev 컨트랙트의 버전을 반환합니다.
     * @return 버전 문자열
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}

/**
 * @title LogicV2
 * @notice 두 번째 버전의 로직 컨트랙트 (업그레이드된 버전)
 * @dev V1의 모든 기능을 유지하면서 새로운 기능을 추가한 구현
 *
 * 스토리지 레이아웃 (V1과 호환):
 * slot 0: initialized (bool)
 * slot 1: owner (address)
 * slot 2: counter (uint256)
 * slot 3: name (string)
 * slot 4: multiplier (uint256) - 새로 추가
 * slot 5: totalOperations (uint256) - 새로 추가
 *
 * 주요 변경사항:
 * 1. multiplier 기능 추가
 * 2. 배치 증가 기능 추가
 * 3. 총 연산 횟수 추적
 * 4. 리셋 기능 추가
 */
contract LogicV2 {
    // ============ 상태 변수 (V1과 동일한 순서 유지) ============

    bool private initialized;
    address public owner;
    uint256 public counter;
    string public name;

    // ============ 새로운 상태 변수 (V2에서 추가) ============

    /**
     * @dev 카운터 증가 시 곱할 값
     * 기본값은 1이며, 변경 가능
     */
    uint256 public multiplier;

    /**
     * @dev 총 연산 횟수 (증가/감소 호출 횟수)
     */
    uint256 public totalOperations;

    // ============ 이벤트 ============

    event Initialized(address indexed owner, string name);
    event CounterIncremented(uint256 newValue);
    event CounterDecremented(uint256 newValue);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // V2에서 추가된 이벤트
    event MultiplierChanged(uint256 oldMultiplier, uint256 newMultiplier);
    event CounterReset(uint256 previousValue);
    event BatchIncrement(uint256 amount, uint256 newValue);

    // ============ Modifiers ============

    modifier onlyOwner() {
        require(msg.sender == owner, "LogicV2: caller is not the owner");
        _;
    }

    // ============ 초기화 함수 ============

    /**
     * @dev V1과 동일한 초기화 함수 (호환성 유지)
     * @param _owner 초기 소유자 주소
     * @param _name 컨트랙트 이름
     */
    function initialize(address _owner, string memory _name) external {
        require(!initialized, "LogicV2: already initialized");
        require(_owner != address(0), "LogicV2: owner is zero address");

        initialized = true;
        owner = _owner;
        name = _name;
        counter = 0;
        multiplier = 1; // V2 기본값 설정

        emit Initialized(_owner, _name);
    }

    /**
     * @dev V2 전용 재초기화 함수
     * @param _multiplier 초기 multiplier 값
     *
     * V1에서 V2로 업그레이드 후 새로운 변수를 초기화하는 데 사용됩니다.
     * upgradeToAndCall에서 이 함수를 호출 데이터로 전달합니다.
     */
    function initializeV2(uint256 _multiplier) external {
        require(initialized, "LogicV2: not initialized");
        require(multiplier == 0, "LogicV2: V2 already initialized");
        require(_multiplier > 0, "LogicV2: multiplier must be greater than 0");

        multiplier = _multiplier;
        totalOperations = 0;
    }

    // ============ V1 기능 (유지) ============

    /**
     * @dev 카운터를 multiplier만큼 증가시킵니다.
     * @return 새로운 카운터 값
     */
    function increment() external returns (uint256) {
        counter += multiplier;
        totalOperations += 1;
        emit CounterIncremented(counter);
        return counter;
    }

    /**
     * @dev 카운터를 1 감소시킵니다.
     * @return 새로운 카운터 값
     */
    function decrement() external returns (uint256) {
        require(counter > 0, "LogicV2: counter is already zero");
        counter -= 1;
        totalOperations += 1;
        emit CounterDecremented(counter);
        return counter;
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }

    function getInfo() external view returns (string memory _name, uint256 _counter, address _owner) {
        return (name, counter, owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "LogicV2: new owner is zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    // ============ V2 새로운 기능 ============

    /**
     * @dev 카운터를 지정한 양만큼 증가시킵니다.
     * @param amount 증가시킬 양
     * @return 새로운 카운터 값
     */
    function incrementBy(uint256 amount) external returns (uint256) {
        require(amount > 0, "LogicV2: amount must be greater than 0");
        counter += amount * multiplier;
        totalOperations += 1;
        emit BatchIncrement(amount, counter);
        return counter;
    }

    /**
     * @dev multiplier 값을 변경합니다.
     * @param newMultiplier 새로운 multiplier 값
     */
    function setMultiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier > 0, "LogicV2: multiplier must be greater than 0");
        uint256 oldMultiplier = multiplier;
        multiplier = newMultiplier;
        emit MultiplierChanged(oldMultiplier, newMultiplier);
    }

    /**
     * @dev 카운터를 0으로 리셋합니다.
     */
    function resetCounter() external onlyOwner {
        uint256 previousValue = counter;
        counter = 0;
        emit CounterReset(previousValue);
    }

    /**
     * @dev 총 연산 횟수를 조회합니다.
     * @return 총 연산 횟수
     */
    function getTotalOperations() external view returns (uint256) {
        return totalOperations;
    }

    /**
     * @dev V2의 확장된 정보를 조회합니다.
     * @return _name 컨트랙트 이름
     * @return _counter 현재 카운터 값
     * @return _owner 소유자 주소
     * @return _multiplier 현재 multiplier 값
     * @return _totalOps 총 연산 횟수
     */
    function getInfoV2() external view returns (
        string memory _name,
        uint256 _counter,
        address _owner,
        uint256 _multiplier,
        uint256 _totalOps
    ) {
        return (name, counter, owner, multiplier, totalOperations);
    }

    /**
     * @dev 컨트랙트의 버전을 반환합니다.
     * @return 버전 문자열
     */
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}

/**
 * @title LogicV3
 * @notice 세 번째 버전의 로직 컨트랙트 (잘못된 업그레이드 예제)
 * @dev 스토리지 레이아웃 충돌을 보여주는 나쁜 예제
 *
 * 경고: 이 컨트랙트는 스토리지 레이아웃을 변경하여 데이터 손상을 일으킬 수 있습니다!
 *
 * 잘못된 스토리지 레이아웃:
 * slot 0: initialized (bool)
 * slot 1: newVariable (uint256) <- 문제: owner를 덮어씀!
 * slot 2: owner (address) <- 문제: 위치가 변경됨!
 * slot 3: counter (uint256)
 * slot 4: name (string)
 */
contract LogicV3_BAD_EXAMPLE {
    // ❌ 잘못된 예: 기존 변수 사이에 새 변수 삽입
    bool private initialized;
    uint256 public newVariable; // 이것은 owner의 슬롯을 차지하게 됨!
    address public owner;
    uint256 public counter;
    string public name;

    /**
     * @dev 이 컨트랙트로 업그레이드하면 데이터가 손상됩니다.
     * owner 값이 newVariable 슬롯으로 해석되고,
     * counter 값이 owner 슬롯으로 해석됩니다.
     *
     * 올바른 방법:
     * 1. 기존 변수의 순서와 타입을 절대 변경하지 않기
     * 2. 새 변수는 항상 끝에 추가하기
     * 3. 변수를 삭제하지 않기 (주석 처리하고 deprecated 표시)
     */
}
