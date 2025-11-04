// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EIP1967Proxy
 * @author EIP-1967 Standard Implementation
 * @notice EIP-1967 표준을 따르는 완전한 프록시 구현
 * @dev 이 프록시는 특정 스토리지 슬롯을 사용하여 구현 주소와 관리자 주소를 저장합니다.
 *
 * EIP-1967 핵심 개념:
 * - IMPLEMENTATION_SLOT: 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
 * - ADMIN_SLOT: 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
 * - BEACON_SLOT: 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50
 *
 * 이러한 슬롯은 keccak256("eip1967.proxy.implementation") - 1 형태로 계산됩니다.
 * 이는 스토리지 충돌을 방지하기 위한 것입니다.
 */
contract EIP1967Proxy {
    /**
     * @dev EIP-1967에서 정의한 구현 컨트랙트 주소를 저장하는 스토리지 슬롯
     * bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
     */
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev EIP-1967에서 정의한 프록시 관리자 주소를 저장하는 스토리지 슬롯
     * bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
     */
    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev 구현 컨트랙트가 업그레이드될 때 발생하는 이벤트
     * @param implementation 새로운 구현 컨트랙트의 주소
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev 프록시의 관리자가 변경될 때 발생하는 이벤트
     * @param previousAdmin 이전 관리자 주소
     * @param newAdmin 새로운 관리자 주소
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev 프록시 생성자
     * @param _logic 초기 구현 컨트랙트 주소
     * @param _admin 프록시 관리자 주소
     * @param _data 초기화 함수 호출을 위한 데이터 (비어있을 수 있음)
     *
     * 생성 시점에 구현 컨트랙트와 관리자를 설정하고,
     * _data가 제공되면 초기화 함수를 delegatecall로 실행합니다.
     */
    constructor(address _logic, address _admin, bytes memory _data) payable {
        // 구현 컨트랙트 주소 설정
        _setImplementation(_logic);
        emit Upgraded(_logic);

        // 관리자 주소 설정
        _setAdmin(_admin);
        emit AdminChanged(address(0), _admin);

        // 초기화 데이터가 있으면 실행
        if (_data.length > 0) {
            (bool success, ) = _logic.delegatecall(_data);
            require(success, "EIP1967Proxy: initialization failed");
        }
    }

    /**
     * @dev 관리자만 호출 가능하도록 제한하는 modifier
     */
    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "EIP1967Proxy: caller is not admin");
        _;
    }

    /**
     * @dev fallback 함수 - 모든 호출을 구현 컨트랙트로 위임합니다.
     *
     * 작동 방식:
     * 1. 구현 컨트랙트 주소를 스토리지에서 로드
     * 2. delegatecall을 사용하여 호출 위임
     * 3. 결과를 그대로 반환
     *
     * delegatecall의 특징:
     * - 프록시의 컨텍스트(storage, msg.sender, msg.value)를 유지
     * - 구현 컨트랙트의 코드만 실행
     */
    fallback() external payable {
        _delegate(_getImplementation());
    }

    /**
     * @dev receive 함수 - ETH를 직접 받을 수 있도록 함
     */
    receive() external payable {}

    /**
     * @dev 프록시를 새로운 구현 컨트랙트로 업그레이드
     * @param newImplementation 새로운 구현 컨트랙트 주소
     *
     * 관리자만 호출할 수 있으며, 업그레이드 시 Upgraded 이벤트를 발생시킵니다.
     */
    function upgradeTo(address newImplementation) external onlyAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev 프록시를 업그레이드하고 초기화 함수를 호출
     * @param newImplementation 새로운 구현 컨트랙트 주소
     * @param data 초기화 함수 호출 데이터
     *
     * 업그레이드와 동시에 새로운 구현 컨트랙트의 초기화가 필요한 경우 사용합니다.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data)
        external
        payable
        onlyAdmin
    {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            (bool success, ) = newImplementation.delegatecall(data);
            require(success, "EIP1967Proxy: upgrade call failed");
        }
    }

    /**
     * @dev 프록시의 관리자 변경
     * @param newAdmin 새로운 관리자 주소
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "EIP1967Proxy: new admin is zero address");
        address previousAdmin = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(previousAdmin, newAdmin);
    }

    /**
     * @dev 현재 관리자 주소 조회
     * @return admin 현재 관리자 주소
     */
    function admin() external view returns (address) {
        return _getAdmin();
    }

    /**
     * @dev 현재 구현 컨트랙트 주소 조회
     * @return implementation 현재 구현 컨트랙트 주소
     */
    function implementation() external view returns (address) {
        return _getImplementation();
    }

    /**
     * @dev 내부 함수: 호출을 구현 컨트랙트로 위임
     * @param _implementation 위임할 구현 컨트랙트 주소
     *
     * 어셈블리를 사용하여 최적화된 delegatecall 구현:
     * 1. calldatacopy로 calldata 복사
     * 2. delegatecall 실행
     * 3. returndatacopy로 반환 데이터 복사
     * 4. 성공/실패에 따라 return 또는 revert
     */
    function _delegate(address _implementation) internal {
        assembly {
            // calldata를 메모리에 복사
            // calldatacopy(t, f, s): 메모리 위치 t에 calldata의 f부터 s 바이트 복사
            calldatacopy(0, 0, calldatasize())

            // delegatecall 실행
            // delegatecall(g, a, in, insize, out, outsize)
            // g: 가스, a: 주소, in: 입력 메모리 시작, insize: 입력 크기
            // out: 출력 메모리 시작, outsize: 출력 크기
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // 반환 데이터를 메모리에 복사
            // returndatacopy(t, f, s): 메모리 위치 t에 returndata의 f부터 s 바이트 복사
            returndatacopy(0, 0, returndatasize())

            // 결과에 따라 처리
            switch result
            case 0 {
                // delegatecall 실패: revert
                revert(0, returndatasize())
            }
            default {
                // delegatecall 성공: return
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev 내부 함수: 구현 컨트랙트 주소를 스토리지에서 가져오기
     * @return impl 구현 컨트랙트 주소
     *
     * 어셈블리를 사용하여 특정 스토리지 슬롯에서 주소를 로드합니다.
     * sload(slot): 지정된 슬롯에서 32바이트를 읽어옵니다.
     */
    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev 내부 함수: 구현 컨트랙트 주소를 스토리지에 저장
     * @param newImplementation 새로운 구현 컨트랙트 주소
     *
     * 어셈블리를 사용하여 특정 스토리지 슬롯에 주소를 저장합니다.
     * sstore(slot, value): 지정된 슬롯에 32바이트 값을 저장합니다.
     */
    function _setImplementation(address newImplementation) private {
        require(
            newImplementation.code.length > 0,
            "EIP1967Proxy: implementation is not a contract"
        );

        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    /**
     * @dev 내부 함수: 관리자 주소를 스토리지에서 가져오기
     * @return adm 관리자 주소
     */
    function _getAdmin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev 내부 함수: 관리자 주소를 스토리지에 저장
     * @param newAdmin 새로운 관리자 주소
     */
    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
}
