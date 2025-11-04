// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ProxyAdmin
 * @notice 프록시 컨트랙트를 관리하는 관리자 컨트랙트
 * @dev 이 컨트랙트는 여러 프록시의 업그레이드와 관리를 중앙화합니다.
 *
 * 핵심 개념:
 * - 프록시와 관리자의 분리: 프록시의 admin이 이 컨트랙트가 됨
 * - 다중 프록시 관리: 하나의 ProxyAdmin이 여러 프록시를 관리할 수 있음
 * - 소유권 기반 접근 제어: owner만이 업그레이드와 관리 작업 수행 가능
 * - 안전한 업그레이드: 업그레이드 전 검증 로직 포함
 */
contract ProxyAdmin {
    // ============ 상태 변수 ============

    /**
     * @dev ProxyAdmin 컨트랙트의 소유자
     * 이 주소만이 프록시 업그레이드와 관리 작업을 수행할 수 있습니다.
     */
    address public owner;

    /**
     * @dev 관리 중인 프록시들의 목록
     * 선택적으로 사용되며, 관리 편의를 위해 프록시 주소를 추적합니다.
     */
    address[] public managedProxies;

    /**
     * @dev 프록시 주소 -> 관리 여부 매핑
     */
    mapping(address => bool) public isManaged;

    // ============ 이벤트 ============

    /**
     * @dev 소유권 이전 이벤트
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev 프록시가 관리 목록에 추가됨
     */
    event ProxyAdded(address indexed proxy);

    /**
     * @dev 프록시가 관리 목록에서 제거됨
     */
    event ProxyRemoved(address indexed proxy);

    /**
     * @dev 프록시가 업그레이드됨
     */
    event ProxyUpgraded(address indexed proxy, address indexed implementation);

    /**
     * @dev 프록시의 관리자가 변경됨
     */
    event ProxyAdminChanged(address indexed proxy, address indexed newAdmin);

    // ============ Modifiers ============

    /**
     * @dev 소유자만 호출 가능하도록 제한
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "ProxyAdmin: caller is not the owner");
        _;
    }

    // ============ 생성자 ============

    /**
     * @dev ProxyAdmin 생성자
     * 배포자를 초기 소유자로 설정합니다.
     */
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============ 소유권 관리 ============

    /**
     * @dev 소유권을 새로운 주소로 이전
     * @param newOwner 새로운 소유자 주소
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ProxyAdmin: new owner is zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    // ============ 프록시 관리 ============

    /**
     * @dev 관리 목록에 프록시 추가
     * @param proxy 추가할 프록시 주소
     *
     * 이 함수는 선택적입니다. 프록시를 추가하지 않아도
     * 업그레이드 함수들은 정상 작동합니다.
     */
    function addProxy(address proxy) external onlyOwner {
        require(proxy != address(0), "ProxyAdmin: proxy is zero address");
        require(!isManaged[proxy], "ProxyAdmin: proxy already managed");

        managedProxies.push(proxy);
        isManaged[proxy] = true;
        emit ProxyAdded(proxy);
    }

    /**
     * @dev 관리 목록에서 프록시 제거
     * @param proxy 제거할 프록시 주소
     */
    function removeProxy(address proxy) external onlyOwner {
        require(isManaged[proxy], "ProxyAdmin: proxy not managed");

        // 배열에서 프록시 찾아서 제거
        for (uint256 i = 0; i < managedProxies.length; i++) {
            if (managedProxies[i] == proxy) {
                managedProxies[i] = managedProxies[managedProxies.length - 1];
                managedProxies.pop();
                break;
            }
        }

        isManaged[proxy] = false;
        emit ProxyRemoved(proxy);
    }

    /**
     * @dev 관리 중인 모든 프록시 주소 조회
     * @return 프록시 주소 배열
     */
    function getManagedProxies() external view returns (address[] memory) {
        return managedProxies;
    }

    /**
     * @dev 관리 중인 프록시 개수 조회
     * @return 프록시 개수
     */
    function getManagedProxyCount() external view returns (uint256) {
        return managedProxies.length;
    }

    // ============ 프록시 업그레이드 기능 ============

    /**
     * @dev 프록시의 현재 구현 컨트랙트 주소 조회
     * @param proxy 프록시 주소
     * @return 구현 컨트랙트 주소
     */
    function getProxyImplementation(address proxy) external view returns (address) {
        // EIP-1967 IMPLEMENTATION_SLOT에서 읽기
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

        address implementation;
        assembly {
            implementation := sload(slot)
        }
        return implementation;
    }

    /**
     * @dev 프록시의 현재 관리자 주소 조회
     * @param proxy 프록시 주소
     * @return 관리자 주소
     */
    function getProxyAdmin(address proxy) external view returns (address) {
        // EIP-1967 ADMIN_SLOT에서 읽기
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

        address admin;
        assembly {
            admin := sload(slot)
        }
        return admin;
    }

    /**
     * @dev 프록시를 새로운 구현으로 업그레이드
     * @param proxy 업그레이드할 프록시 주소
     * @param implementation 새로운 구현 컨트랙트 주소
     *
     * 이 함수는 프록시의 upgradeTo 함수를 호출합니다.
     */
    function upgrade(address proxy, address implementation) external onlyOwner {
        require(proxy != address(0), "ProxyAdmin: proxy is zero address");
        require(implementation != address(0), "ProxyAdmin: implementation is zero address");
        require(_isContract(implementation), "ProxyAdmin: implementation is not a contract");

        // 프록시의 upgradeTo 함수 호출
        (bool success, ) = proxy.call(
            abi.encodeWithSignature("upgradeTo(address)", implementation)
        );
        require(success, "ProxyAdmin: upgrade failed");

        emit ProxyUpgraded(proxy, implementation);
    }

    /**
     * @dev 프록시를 업그레이드하고 초기화 함수 호출
     * @param proxy 업그레이드할 프록시 주소
     * @param implementation 새로운 구현 컨트랙트 주소
     * @param data 초기화 함수 호출 데이터
     *
     * V1에서 V2로 업그레이드하면서 initializeV2() 같은 함수를 호출할 때 사용합니다.
     */
    function upgradeAndCall(
        address proxy,
        address implementation,
        bytes calldata data
    ) external payable onlyOwner {
        require(proxy != address(0), "ProxyAdmin: proxy is zero address");
        require(implementation != address(0), "ProxyAdmin: implementation is zero address");
        require(_isContract(implementation), "ProxyAdmin: implementation is not a contract");

        // 프록시의 upgradeToAndCall 함수 호출
        (bool success, ) = proxy.call{value: msg.value}(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)",
                implementation,
                data
            )
        );
        require(success, "ProxyAdmin: upgrade and call failed");

        emit ProxyUpgraded(proxy, implementation);
    }

    /**
     * @dev 프록시의 관리자를 변경
     * @param proxy 프록시 주소
     * @param newAdmin 새로운 관리자 주소
     *
     * 주의: 이 함수를 호출하면 ProxyAdmin이 해당 프록시를 더 이상 관리할 수 없게 됩니다.
     */
    function changeProxyAdmin(address proxy, address newAdmin) external onlyOwner {
        require(proxy != address(0), "ProxyAdmin: proxy is zero address");
        require(newAdmin != address(0), "ProxyAdmin: new admin is zero address");

        // 프록시의 changeAdmin 함수 호출
        (bool success, ) = proxy.call(
            abi.encodeWithSignature("changeAdmin(address)", newAdmin)
        );
        require(success, "ProxyAdmin: change admin failed");

        emit ProxyAdminChanged(proxy, newAdmin);
    }

    // ============ 배치 업그레이드 기능 ============

    /**
     * @dev 여러 프록시를 동일한 구현으로 일괄 업그레이드
     * @param proxies 업그레이드할 프록시 주소 배열
     * @param implementation 새로운 구현 컨트랙트 주소
     *
     * 여러 프록시를 동시에 업그레이드해야 할 때 사용합니다.
     * 하나라도 실패하면 전체 트랜잭션이 revert됩니다.
     */
    function batchUpgrade(address[] calldata proxies, address implementation) external onlyOwner {
        require(implementation != address(0), "ProxyAdmin: implementation is zero address");
        require(_isContract(implementation), "ProxyAdmin: implementation is not a contract");

        for (uint256 i = 0; i < proxies.length; i++) {
            address proxy = proxies[i];
            require(proxy != address(0), "ProxyAdmin: proxy is zero address");

            (bool success, ) = proxy.call(
                abi.encodeWithSignature("upgradeTo(address)", implementation)
            );
            require(success, "ProxyAdmin: batch upgrade failed");

            emit ProxyUpgraded(proxy, implementation);
        }
    }

    // ============ 유틸리티 함수 ============

    /**
     * @dev 주소가 컨트랙트인지 확인
     * @param account 확인할 주소
     * @return true if account is a contract
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev 프록시를 통해 임의의 함수 호출 (읽기 전용)
     * @param proxy 프록시 주소
     * @param data 호출 데이터
     * @return 호출 결과
     *
     * 프록시의 상태를 조회하는 데 사용할 수 있습니다.
     */
    function callProxy(address proxy, bytes calldata data) external view returns (bytes memory) {
        require(proxy != address(0), "ProxyAdmin: proxy is zero address");

        (bool success, bytes memory returnData) = proxy.staticcall(data);
        require(success, "ProxyAdmin: call failed");

        return returnData;
    }

    /**
     * @dev ETH를 받을 수 있도록 함
     * upgradeAndCall에서 msg.value를 전달해야 할 수 있습니다.
     */
    receive() external payable {}

    /**
     * @dev 컨트랙트에 남아있는 ETH를 인출
     * @param recipient 인출 받을 주소
     */
    function withdraw(address payable recipient) external onlyOwner {
        require(recipient != address(0), "ProxyAdmin: recipient is zero address");
        uint256 balance = address(this).balance;
        require(balance > 0, "ProxyAdmin: no balance to withdraw");

        (bool success, ) = recipient.call{value: balance}("");
        require(success, "ProxyAdmin: withdraw failed");
    }
}

/**
 * @title TimelockProxyAdmin
 * @notice 시간 지연 기능이 있는 프록시 관리자
 * @dev 중요한 업그레이드에 대해 시간 지연을 적용하여 보안을 강화합니다.
 *
 * 핵심 개념:
 * - 업그레이드 제안: 즉시 실행되지 않고 제안됨
 * - 시간 지연: 최소 대기 시간 후에만 실행 가능
 * - 취소 가능: 실행 전까지 취소 가능
 *
 * 이점:
 * - 사용자들이 업그레이드를 확인할 시간 확보
 * - 악의적인 업그레이드 방지
 * - 거버넌스와 통합 가능
 */
contract TimelockProxyAdmin {
    // ============ 상태 변수 ============

    address public owner;
    uint256 public constant MIN_DELAY = 2 days; // 최소 2일 대기
    uint256 public constant MAX_DELAY = 30 days; // 최대 30일 대기
    uint256 public delay;

    /**
     * @dev 업그레이드 제안 구조체
     */
    struct UpgradeProposal {
        address proxy;              // 업그레이드할 프록시 주소
        address implementation;     // 새로운 구현 주소
        bytes data;                // 초기화 데이터 (선택적)
        uint256 scheduledTime;     // 실행 가능 시간
        bool executed;             // 실행 여부
        bool cancelled;            // 취소 여부
    }

    // 제안 ID -> 제안 정보
    mapping(bytes32 => UpgradeProposal) public proposals;

    // ============ 이벤트 ============

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DelayChanged(uint256 oldDelay, uint256 newDelay);
    event UpgradeScheduled(
        bytes32 indexed proposalId,
        address indexed proxy,
        address indexed implementation,
        uint256 scheduledTime
    );
    event UpgradeExecuted(bytes32 indexed proposalId, address indexed proxy);
    event UpgradeCancelled(bytes32 indexed proposalId);

    // ============ Modifiers ============

    modifier onlyOwner() {
        require(msg.sender == owner, "TimelockProxyAdmin: caller is not the owner");
        _;
    }

    // ============ 생성자 ============

    /**
     * @dev TimelockProxyAdmin 생성자
     * @param _delay 초기 시간 지연 (초 단위)
     */
    constructor(uint256 _delay) {
        require(_delay >= MIN_DELAY, "TimelockProxyAdmin: delay too short");
        require(_delay <= MAX_DELAY, "TimelockProxyAdmin: delay too long");

        owner = msg.sender;
        delay = _delay;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============ 관리 함수 ============

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TimelockProxyAdmin: new owner is zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @dev 시간 지연 변경
     * @param newDelay 새로운 지연 시간
     */
    function setDelay(uint256 newDelay) external onlyOwner {
        require(newDelay >= MIN_DELAY, "TimelockProxyAdmin: delay too short");
        require(newDelay <= MAX_DELAY, "TimelockProxyAdmin: delay too long");

        uint256 oldDelay = delay;
        delay = newDelay;
        emit DelayChanged(oldDelay, newDelay);
    }

    // ============ 업그레이드 함수 ============

    /**
     * @dev 업그레이드 예약
     * @param proxy 업그레이드할 프록시 주소
     * @param implementation 새로운 구현 주소
     * @param data 초기화 데이터
     * @return proposalId 제안 ID
     */
    function scheduleUpgrade(
        address proxy,
        address implementation,
        bytes calldata data
    ) external onlyOwner returns (bytes32) {
        require(proxy != address(0), "TimelockProxyAdmin: proxy is zero address");
        require(implementation != address(0), "TimelockProxyAdmin: implementation is zero address");

        // 제안 ID 생성
        bytes32 proposalId = keccak256(abi.encode(proxy, implementation, data, block.timestamp));
        require(proposals[proposalId].scheduledTime == 0, "TimelockProxyAdmin: proposal already exists");

        // 실행 가능 시간 계산
        uint256 scheduledTime = block.timestamp + delay;

        // 제안 저장
        proposals[proposalId] = UpgradeProposal({
            proxy: proxy,
            implementation: implementation,
            data: data,
            scheduledTime: scheduledTime,
            executed: false,
            cancelled: false
        });

        emit UpgradeScheduled(proposalId, proxy, implementation, scheduledTime);
        return proposalId;
    }

    /**
     * @dev 예약된 업그레이드 실행
     * @param proposalId 제안 ID
     */
    function executeUpgrade(bytes32 proposalId) external onlyOwner {
        UpgradeProposal storage proposal = proposals[proposalId];

        require(proposal.scheduledTime != 0, "TimelockProxyAdmin: proposal does not exist");
        require(!proposal.executed, "TimelockProxyAdmin: proposal already executed");
        require(!proposal.cancelled, "TimelockProxyAdmin: proposal cancelled");
        require(block.timestamp >= proposal.scheduledTime, "TimelockProxyAdmin: delay not passed");

        proposal.executed = true;

        // 업그레이드 실행
        if (proposal.data.length > 0) {
            (bool success, ) = proposal.proxy.call(
                abi.encodeWithSignature(
                    "upgradeToAndCall(address,bytes)",
                    proposal.implementation,
                    proposal.data
                )
            );
            require(success, "TimelockProxyAdmin: upgrade failed");
        } else {
            (bool success, ) = proposal.proxy.call(
                abi.encodeWithSignature("upgradeTo(address)", proposal.implementation)
            );
            require(success, "TimelockProxyAdmin: upgrade failed");
        }

        emit UpgradeExecuted(proposalId, proposal.proxy);
    }

    /**
     * @dev 예약된 업그레이드 취소
     * @param proposalId 제안 ID
     */
    function cancelUpgrade(bytes32 proposalId) external onlyOwner {
        UpgradeProposal storage proposal = proposals[proposalId];

        require(proposal.scheduledTime != 0, "TimelockProxyAdmin: proposal does not exist");
        require(!proposal.executed, "TimelockProxyAdmin: proposal already executed");
        require(!proposal.cancelled, "TimelockProxyAdmin: proposal already cancelled");

        proposal.cancelled = true;
        emit UpgradeCancelled(proposalId);
    }

    /**
     * @dev 제안 정보 조회
     * @param proposalId 제안 ID
     * @return proposal 제안 정보
     */
    function getProposal(bytes32 proposalId) external view returns (UpgradeProposal memory) {
        return proposals[proposalId];
    }

    /**
     * @dev 제안이 실행 가능한지 확인
     * @param proposalId 제안 ID
     * @return 실행 가능 여부
     */
    function isProposalReady(bytes32 proposalId) external view returns (bool) {
        UpgradeProposal storage proposal = proposals[proposalId];

        return proposal.scheduledTime != 0 &&
               !proposal.executed &&
               !proposal.cancelled &&
               block.timestamp >= proposal.scheduledTime;
    }
}
