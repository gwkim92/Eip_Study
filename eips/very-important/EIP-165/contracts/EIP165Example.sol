// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EIP165Example
 * @dev EIP-165의 기본 구현 예제
 *
 * EIP-165는 컨트랙트가 어떤 인터페이스를 지원하는지 표준화된 방식으로
 * 공개할 수 있게 해줍니다.
 */

// ERC-165 표준 인터페이스
interface IERC165 {
    /**
     * @dev 컨트랙트가 특정 인터페이스를 구현하는지 확인
     * @param interfaceId 확인하고자 하는 인터페이스 식별자
     * @return bool 인터페이스를 구현하면 true, 아니면 false
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @title BasicERC165
 * @dev 가장 기본적인 ERC-165 구현
 */
contract BasicERC165 is IERC165 {
    /**
     * @dev ERC-165 인터페이스만 지원하는 기본 구현
     * interfaceId 계산: bytes4(keccak256('supportsInterface(bytes4)'))
     * = 0x01ffc9a7
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 현재 지원하는 인터페이스 ID를 반환하는 헬퍼 함수
     */
    function getERC165InterfaceId() public pure returns (bytes4) {
        return type(IERC165).interfaceId; // 0x01ffc9a7
    }
}

/**
 * @title CustomInterface
 * @dev 커스텀 인터페이스 예제
 */
interface ICustomInterface {
    function customFunction() external pure returns (string memory);
    function anotherFunction(uint256 value) external pure returns (uint256);
}

/**
 * @title ERC165WithCustomInterface
 * @dev ERC-165와 커스텀 인터페이스를 함께 구현
 */
contract ERC165WithCustomInterface is IERC165, ICustomInterface {
    /**
     * @dev 두 개의 인터페이스를 지원
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(ICustomInterface).interfaceId;
    }

    /**
     * @dev 커스텀 인터페이스 구현
     */
    function customFunction() external pure override returns (string memory) {
        return "Custom function implementation";
    }

    function anotherFunction(uint256 value) external pure override returns (uint256) {
        return value * 2;
    }

    /**
     * @dev 인터페이스 ID 조회 함수들
     */
    function getCustomInterfaceId() public pure returns (bytes4) {
        return type(ICustomInterface).interfaceId;
    }

    function calculateInterfaceId() public pure returns (bytes4) {
        // 수동으로 계산하는 방법
        bytes4 selector1 = bytes4(keccak256("customFunction()"));
        bytes4 selector2 = bytes4(keccak256("anotherFunction(uint256)"));
        return selector1 ^ selector2;
    }
}

/**
 * @title MappingBasedERC165
 * @dev 매핑을 사용한 더 유연한 ERC-165 구현
 * 런타임에 인터페이스를 등록/제거할 수 있습니다
 */
contract MappingBasedERC165 is IERC165 {
    // 지원하는 인터페이스를 저장하는 매핑
    mapping(bytes4 => bool) private _supportedInterfaces;

    // 인터페이스 등록 이벤트
    event InterfaceRegistered(bytes4 indexed interfaceId);
    event InterfaceUnregistered(bytes4 indexed interfaceId);

    constructor() {
        // 생성자에서 ERC-165 인터페이스 등록
        _registerInterface(type(IERC165).interfaceId);
    }

    /**
     * @dev 인터페이스 지원 여부 확인
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev 새로운 인터페이스 등록
     * @param interfaceId 등록할 인터페이스 ID
     */
    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
        emit InterfaceRegistered(interfaceId);
    }

    /**
     * @dev 인터페이스 등록 해제
     * @param interfaceId 제거할 인터페이스 ID
     */
    function _unregisterInterface(bytes4 interfaceId) internal {
        require(interfaceId != type(IERC165).interfaceId, "Cannot unregister ERC165");
        _supportedInterfaces[interfaceId] = false;
        emit InterfaceUnregistered(interfaceId);
    }

    /**
     * @dev 지원하는 모든 인터페이스 확인 (테스트용)
     * 주의: 이 함수는 매핑을 순회할 수 없으므로 실제로는 구현 불가
     * 대신 특정 인터페이스들을 체크하는 함수 제공
     */
    function checkMultipleInterfaces(bytes4[] memory interfaceIds)
        public
        view
        returns (bool[] memory)
    {
        bool[] memory results = new bool[](interfaceIds.length);
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            results[i] = _supportedInterfaces[interfaceIds[i]];
        }
        return results;
    }
}

/**
 * @title ExtendableMappingERC165
 * @dev MappingBasedERC165를 상속하여 실제로 사용 가능한 확장 구현
 */
contract ExtendableMappingERC165 is MappingBasedERC165, ICustomInterface {
    constructor() {
        // 커스텀 인터페이스 등록
        _registerInterface(type(ICustomInterface).interfaceId);
    }

    function customFunction() external pure override returns (string memory) {
        return "Extendable implementation";
    }

    function anotherFunction(uint256 value) external pure override returns (uint256) {
        return value * 3;
    }

    /**
     * @dev 새로운 인터페이스를 동적으로 추가 (예제용 - 실제로는 권한 제어 필요)
     */
    function registerNewInterface(bytes4 interfaceId) external {
        _registerInterface(interfaceId);
    }
}

/**
 * @title InvalidInterfaceChecker
 * @dev EIP-165에서 금지된 인터페이스 ID를 올바르게 처리하는 예제
 */
contract InvalidInterfaceChecker is IERC165 {
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        // 0xffffffff는 무효한 인터페이스 ID로, 항상 false를 반환해야 함
        if (interfaceId == 0xffffffff) {
            return false;
        }

        return interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 무효한 인터페이스 ID인지 확인
     */
    function isInvalidInterfaceId(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0xffffffff;
    }
}

/**
 * @title ERC165Checker
 * @dev 다른 컨트랙트의 ERC-165 지원 여부를 확인하는 유틸리티
 */
library ERC165Checker {
    // ERC-165 인터페이스 ID
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev 컨트랙트가 ERC-165를 지원하는지 확인
     */
    function supportsERC165(address account) internal view returns (bool) {
        return _supportsERC165Interface(account, _INTERFACE_ID_ERC165);
    }

    /**
     * @dev 컨트랙트가 특정 인터페이스를 지원하는지 확인
     */
    function supportsInterface(address account, bytes4 interfaceId)
        internal
        view
        returns (bool)
    {
        return
            supportsERC165(account) &&
            _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev 여러 인터페이스를 모두 지원하는지 확인
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds)
        internal
        view
        returns (bool)
    {
        if (!supportsERC165(account)) {
            return false;
        }

        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev 내부 헬퍼 함수: 실제 supportsInterface 호출
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId)
        private
        view
        returns (bool)
    {
        // 낮은 수준의 staticcall로 가스 제한과 함께 호출
        (bool success, bytes memory result) = account.staticcall{gas: 30000}(
            abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId)
        );

        // 호출이 성공하고, 반환값이 있으며, true를 반환하는지 확인
        return (success && result.length == 32 && abi.decode(result, (bool)));
    }
}

/**
 * @title SafeInterfaceConsumer
 * @dev ERC165Checker 라이브러리를 사용하는 예제
 */
contract SafeInterfaceConsumer {
    using ERC165Checker for address;

    event InterfaceChecked(address indexed target, bytes4 indexed interfaceId, bool supported);

    /**
     * @dev 안전하게 인터페이스를 확인하고 사용
     */
    function safelyUseInterface(address target, bytes4 interfaceId) external returns (bool) {
        // ERC-165 지원 확인
        require(target.supportsERC165(), "Target does not support ERC165");

        // 특정 인터페이스 지원 확인
        bool supported = target.supportsInterface(interfaceId);

        emit InterfaceChecked(target, interfaceId, supported);

        return supported;
    }

    /**
     * @dev 여러 인터페이스를 한 번에 확인
     */
    function checkMultipleInterfaces(address target, bytes4[] memory interfaceIds)
        external
        view
        returns (bool)
    {
        return target.supportsAllInterfaces(interfaceIds);
    }
}

/**
 * @title InterfaceIdCalculator
 * @dev 인터페이스 ID 계산 예제 및 헬퍼
 */
contract InterfaceIdCalculator {
    /**
     * @dev 함수 선택자를 계산하는 예제
     */
    function calculateSelector(string memory signature) public pure returns (bytes4) {
        return bytes4(keccak256(bytes(signature)));
    }

    /**
     * @dev 두 개의 선택자를 XOR
     */
    function xorSelectors(bytes4 selector1, bytes4 selector2)
        public
        pure
        returns (bytes4)
    {
        return selector1 ^ selector2;
    }

    /**
     * @dev 여러 선택자를 XOR하여 인터페이스 ID 계산
     */
    function calculateInterfaceId(bytes4[] memory selectors)
        public
        pure
        returns (bytes4)
    {
        require(selectors.length > 0, "Need at least one selector");

        bytes4 interfaceId = selectors[0];
        for (uint256 i = 1; i < selectors.length; i++) {
            interfaceId = interfaceId ^ selectors[i];
        }

        return interfaceId;
    }

    /**
     * @dev 실제 계산 예제: ICustomInterface의 인터페이스 ID
     */
    function getCustomInterfaceIdManually() public pure returns (bytes4) {
        bytes4 selector1 = bytes4(keccak256("customFunction()"));
        bytes4 selector2 = bytes4(keccak256("anotherFunction(uint256)"));
        return selector1 ^ selector2;
    }

    /**
     * @dev 컴파일러를 사용한 자동 계산과 비교
     */
    function compareInterfaceIds() public pure returns (bool) {
        bytes4 manual = getCustomInterfaceIdManually();
        bytes4 automatic = type(ICustomInterface).interfaceId;
        return manual == automatic;
    }
}
