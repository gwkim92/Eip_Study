// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AccountAbstractionExample
 * @dev EIP-4337 Account Abstraction 구현 예제
 *
 * EIP-4337은 스마트 컨트랙트 지갑을 통한 계정 추상화를 가능하게 합니다.
 * 사용자는 EOA 없이도 스마트 컨트랙트 계정으로 트랜잭션을 실행할 수 있습니다.
 *
 * EIP-4337 enables account abstraction through smart contract wallets.
 * Users can execute transactions using smart contract accounts without EOAs.
 *
 * 핵심 구성요소:
 * Key Components:
 * - UserOperation: 사용자가 실행하려는 작업
 * - EntryPoint: UserOperation을 검증하고 실행하는 싱글톤 컨트랙트
 * - Account: 스마트 컨트랙트 지갑
 * - Bundler: UserOperation을 모아서 EntryPoint에 제출
 * - Paymaster: 가스비를 대신 지불하는 컨트랙트 (선택)
 */

/**
 * @dev UserOperation 구조체
 * EIP-4337 표준 UserOperation
 */
struct UserOperation {
    address sender; // 스마트 컨트랙트 계정 주소
    uint256 nonce; // 재실행 방지
    bytes initCode; // 계정 생성 코드 (아직 배포되지 않은 경우)
    bytes callData; // 실제 실행할 호출 데이터
    uint256 callGasLimit; // 호출에 사용할 가스
    uint256 verificationGasLimit; // 검증에 사용할 가스
    uint256 preVerificationGas; // 번들러 보상
    uint256 maxFeePerGas; // 최대 가스 가격
    uint256 maxPriorityFeePerGas; // 우선 수수료
    bytes paymasterAndData; // Paymaster 주소 + 데이터
    bytes signature; // 서명
}

/**
 * @dev IEntryPoint 인터페이스 (간소화 버전)
 */
interface IEntryPoint {
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;
    function getNonce(address sender, uint192 key) external view returns (uint256);
}

/**
 * @dev IAccount 인터페이스
 */
interface IAccount {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

/**
 * @title SimpleAccount
 * @dev 기본적인 스마트 컨트랙트 계정 구현
 * Basic smart contract account implementation
 */
contract SimpleAccount is IAccount {
    IEntryPoint private immutable _entryPoint;
    address public owner;

    uint256 private _nonce;

    event AccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);
    event AccountExecuted(address indexed target, uint256 value, bytes data);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");
        _;
    }

    constructor(IEntryPoint entryPoint_, address owner_) {
        _entryPoint = entryPoint_;
        owner = owner_;
        emit AccountInitialized(entryPoint_, owner_);
    }

    /**
     * @dev UserOperation 검증
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
        // 서명 검증
        bytes32 hash = _getEthSignedMessageHash(userOpHash);
        address signer = _recoverSigner(hash, userOp.signature);

        if (signer != owner) {
            return 1; // 검증 실패
        }

        // 가스비 지불
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Failed to pay for gas");
        }

        return 0; // 검증 성공
    }

    /**
     * @dev 작업 실행
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyEntryPoint
    {
        _call(target, value, data);
    }

    /**
     * @dev 배치 실행
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external onlyEntryPoint {
        require(
            targets.length == values.length && targets.length == datas.length,
            "Length mismatch"
        );

        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], datas[i]);
        }
    }

    /**
     * @dev 내부 호출 함수
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        emit AccountExecuted(target, value, data);
    }

    /**
     * @dev 서명 복구
     */
    function _recoverSigner(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
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

    /**
     * @dev Ethereum 서명 메시지 해시
     */
    function _getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    /**
     * @dev EntryPoint 주소 조회
     */
    function entryPoint() public view returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @dev 이더 수령
     */
    receive() external payable {}
}

/**
 * @title AccountFactory
 * @dev 스마트 컨트랙트 계정 팩토리
 * Smart contract account factory
 */
contract AccountFactory {
    IEntryPoint public immutable entryPoint;

    event AccountCreated(address indexed account, address indexed owner);

    constructor(IEntryPoint entryPoint_) {
        entryPoint = entryPoint_;
    }

    /**
     * @dev 새 계정 생성
     */
    function createAccount(address owner, uint256 salt) external returns (SimpleAccount) {
        address addr = getAddress(owner, salt);

        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SimpleAccount(payable(addr));
        }

        SimpleAccount account = new SimpleAccount{salt: bytes32(salt)}(entryPoint, owner);

        emit AccountCreated(address(account), owner);
        return account;
    }

    /**
     * @dev 계정 주소 계산 (CREATE2)
     */
    function getAddress(address owner, uint256 salt) public view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            bytes32(salt),
                            keccak256(
                                abi.encodePacked(
                                    type(SimpleAccount).creationCode,
                                    abi.encode(entryPoint, owner)
                                )
                            )
                        )
                    )
                )
            )
        );
    }
}

/**
 * @title SimplePaymaster
 * @dev 가스비를 대신 지불하는 Paymaster
 * Paymaster that pays for gas
 */
contract SimplePaymaster {
    IEntryPoint public immutable entryPoint;
    address public owner;

    mapping(address => bool) public allowedAccounts;

    event PaymasterDeposited(uint256 amount);
    event PaymasterWithdrawn(address indexed to, uint256 amount);
    event AccountAllowed(address indexed account);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(IEntryPoint entryPoint_) {
        entryPoint = entryPoint_;
        owner = msg.sender;
    }

    /**
     * @dev 계정 허용
     */
    function allowAccount(address account) external onlyOwner {
        allowedAccounts[account] = true;
        emit AccountAllowed(account);
    }

    /**
     * @dev Paymaster에 입금
     */
    function deposit() external payable {
        emit PaymasterDeposited(msg.value);
    }

    /**
     * @dev Paymaster에서 출금
     */
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdrawal failed");
        emit PaymasterWithdrawn(to, amount);
    }

    /**
     * @dev 이더 수령
     */
    receive() external payable {
        emit PaymasterDeposited(msg.value);
    }
}

/**
 * @title MultiSigAccount
 * @dev 다중 서명 스마트 컨트랙트 계정
 * Multi-signature smart contract account
 */
contract MultiSigAccount is IAccount {
    IEntryPoint private immutable _entryPoint;

    address[] public owners;
    uint256 public requiredSignatures;

    mapping(address => bool) public isOwner;

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequiredSignaturesChanged(uint256 required);

    constructor(
        IEntryPoint entryPoint_,
        address[] memory owners_,
        uint256 requiredSignatures_
    ) {
        require(owners_.length >= requiredSignatures_, "Invalid signatures requirement");
        require(requiredSignatures_ > 0, "Required signatures must be > 0");

        _entryPoint = entryPoint_;
        requiredSignatures = requiredSignatures_;

        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);

            emit OwnerAdded(owner);
        }
    }

    /**
     * @dev UserOperation 검증 (다중 서명)
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        // 서명 검증
        if (!_validateSignatures(userOpHash, userOp.signature)) {
            return 1; // 검증 실패
        }

        // 가스비 지불
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Failed to pay for gas");
        }

        return 0; // 검증 성공
    }

    /**
     * @dev 다중 서명 검증
     */
    function _validateSignatures(bytes32 hash, bytes memory signatures)
        internal
        view
        returns (bool)
    {
        require(signatures.length == requiredSignatures * 65, "Invalid signatures length");

        bytes32 ethSignedHash = _getEthSignedMessageHash(hash);
        address[] memory signers = new address[](requiredSignatures);

        for (uint256 i = 0; i < requiredSignatures; i++) {
            bytes memory sig = new bytes(65);

            for (uint256 j = 0; j < 65; j++) {
                sig[j] = signatures[i * 65 + j];
            }

            address signer = _recoverSigner(ethSignedHash, sig);

            // 소유자 확인 및 중복 확인
            if (!isOwner[signer]) {
                return false;
            }

            for (uint256 j = 0; j < i; j++) {
                if (signers[j] == signer) {
                    return false; // 중복 서명
                }
            }

            signers[i] = signer;
        }

        return true;
    }

    function _recoverSigner(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
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

    function _getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    receive() external payable {}
}

/**
 * @title SessionKeyAccount
 * @dev 세션 키를 지원하는 계정
 * Account with session key support
 */
contract SessionKeyAccount is IAccount {
    IEntryPoint private immutable _entryPoint;
    address public mainOwner;

    struct SessionKey {
        address key;
        uint256 validUntil;
        uint256 gasLimit;
        address[] allowedTargets;
    }

    mapping(address => SessionKey) public sessionKeys;

    event SessionKeyAdded(address indexed sessionKey, uint256 validUntil);
    event SessionKeyRevoked(address indexed sessionKey);

    constructor(IEntryPoint entryPoint_, address mainOwner_) {
        _entryPoint = entryPoint_;
        mainOwner = mainOwner_;
    }

    /**
     * @dev 세션 키 추가
     */
    function addSessionKey(
        address sessionKey,
        uint256 validUntil,
        uint256 gasLimit,
        address[] calldata allowedTargets
    ) external {
        require(msg.sender == mainOwner, "Not main owner");

        sessionKeys[sessionKey] = SessionKey({
            key: sessionKey,
            validUntil: validUntil,
            gasLimit: gasLimit,
            allowedTargets: allowedTargets
        });

        emit SessionKeyAdded(sessionKey, validUntil);
    }

    /**
     * @dev 세션 키 취소
     */
    function revokeSessionKey(address sessionKey) external {
        require(msg.sender == mainOwner, "Not main owner");
        delete sessionKeys[sessionKey];
        emit SessionKeyRevoked(sessionKey);
    }

    /**
     * @dev UserOperation 검증
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        require(msg.sender == address(_entryPoint), "Not EntryPoint");

        bytes32 hash = _getEthSignedMessageHash(userOpHash);
        address signer = _recoverSigner(hash, userOp.signature);

        // 메인 소유자 확인
        if (signer == mainOwner) {
            if (missingAccountFunds > 0) {
                (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
                require(success, "Failed to pay for gas");
            }
            return 0;
        }

        // 세션 키 확인
        SessionKey memory session = sessionKeys[signer];

        if (session.key == address(0)) {
            return 1; // 유효하지 않은 세션 키
        }

        if (block.timestamp > session.validUntil) {
            return 1; // 만료된 세션 키
        }

        if (userOp.callGasLimit > session.gasLimit) {
            return 1; // 가스 한도 초과
        }

        // 가스비 지불
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Failed to pay for gas");
        }

        return 0;
    }

    function _recoverSigner(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
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

    function _getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    receive() external payable {}
}

/**
 * @title AccountAbstractionHelper
 * @dev Account Abstraction 헬퍼 함수
 * Helper functions for Account Abstraction
 */
contract AccountAbstractionHelper {
    /**
     * @dev UserOperation 해시 계산
     */
    function getUserOpHash(UserOperation calldata userOp, address entryPoint, uint256 chainId)
        external
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                keccak256(userOp.paymasterAndData),
                entryPoint,
                chainId
            )
        );
    }

    /**
     * @dev UserOperation 패킹
     */
    function packUserOp(UserOperation calldata userOp) external pure returns (bytes memory) {
        return abi.encode(userOp);
    }
}

/**
 * @title AccountAbstractionBestPractices
 * @dev Account Abstraction 모범 사례
 */
contract AccountAbstractionBestPractices {
    /**
     * EIP-4337 Account Abstraction 모범 사례:
     * Best Practices:
     *
     * 1. 보안
     *    Security:
     *    - 서명 검증 철저히 수행
     *    - Nonce 관리로 재실행 방지
     *    - 가스 한도 설정
     *
     * 2. 가스 효율성
     *    Gas Efficiency:
     *    - Paymaster 활용
     *    - 배치 작업 지원
     *    - 최적화된 검증 로직
     *
     * 3. 사용자 경험
     *    User Experience:
     *    - 세션 키로 반복 승인 불필요
     *    - 소셜 복구 지원
     *    - 멀티시그 옵션
     *
     * 4. 호환성
     *    Compatibility:
     *    - 표준 인터페이스 준수
     *    - EntryPoint 버전 관리
     *    - 업그레이드 가능 설계
     */
}
