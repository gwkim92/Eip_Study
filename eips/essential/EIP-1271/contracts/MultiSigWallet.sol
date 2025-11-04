// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1271.sol";

/**
 * @title MultiSigWallet
 * @dev EIP-1271을 구현한 멀티시그 지갑 (Gnosis Safe 스타일)
 * @dev Multi-signature wallet implementing EIP-1271 (Gnosis Safe style)
 *
 * 여러 소유자가 있고, 일정 수 이상의 서명이 있어야 트랜잭션을 실행할 수 있습니다.
 * Multiple owners exist, and a certain number of signatures are required to execute transactions.
 */
contract MultiSigWallet is IERC1271 {
    // Magic value for EIP-1271
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    // 소유자 주소 배열
    // Array of owner addresses
    address[] public owners;

    // 소유자 여부를 빠르게 확인하기 위한 매핑
    // Mapping for quick owner verification
    mapping(address => bool) public isOwner;

    // 필요한 서명 개수 (임계값)
    // Required number of signatures (threshold)
    uint256 public threshold;

    // 재사용 방지를 위한 nonce
    // Nonce for replay protection
    uint256 public nonce;

    /**
     * @dev 소유자 추가 이벤트
     * @dev Owner added event
     */
    event OwnerAdded(address indexed owner);

    /**
     * @dev 소유자 제거 이벤트
     * @dev Owner removed event
     */
    event OwnerRemoved(address indexed owner);

    /**
     * @dev 임계값 변경 이벤트
     * @dev Threshold changed event
     */
    event ThresholdChanged(uint256 threshold);

    /**
     * @dev 트랜잭션 실행 이벤트
     * @dev Transaction execution event
     */
    event Executed(address indexed to, uint256 value, bytes data, uint256 nonce);

    /**
     * @dev 생성자
     * @dev Constructor
     *
     * @param _owners 소유자 주소 배열
     * @param _owners Array of owner addresses
     *
     * @param _threshold 필요한 서명 개수
     * @param _threshold Required number of signatures
     */
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Owners required");
        require(
            _threshold > 0 && _threshold <= _owners.length,
            "Invalid threshold"
        );

        // 소유자 초기화 및 중복 확인
        // Initialize owners and check for duplicates
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }

        threshold = _threshold;
        emit ThresholdChanged(_threshold);
    }

    /**
     * @dev 소유자만 호출 가능한 modifier
     * @dev Modifier to restrict access to owners only
     */
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    /**
     * @dev EIP-1271 서명 검증 구현
     * @dev Implementation of EIP-1271 signature verification
     *
     * 여러 소유자의 서명을 연결한 형태로 받습니다.
     * Receives concatenated signatures from multiple owners.
     *
     * @param hash 서명된 메시지 해시
     * @param hash Hash of the signed message
     *
     * @param signatures 연결된 서명들 (각 65바이트)
     * @param signatures Concatenated signatures (65 bytes each)
     *
     * @return magicValue 유효한 서명이면 0x1626ba7e
     * @return magicValue 0x1626ba7e if valid
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signatures
    ) external view override returns (bytes4 magicValue) {
        // 서명 개수 확인
        // Check signature count
        require(signatures.length % 65 == 0, "Invalid signatures length");
        uint256 signatureCount = signatures.length / 65;

        require(signatureCount >= threshold, "Not enough signatures");
        require(signatureCount <= owners.length, "Too many signatures");

        // 서명자 주소를 저장할 배열
        // Array to store signer addresses
        address[] memory signers = new address[](signatureCount);

        // 각 서명 검증
        // Verify each signature
        for (uint256 i = 0; i < signatureCount; i++) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            // 65바이트씩 서명 추출
            // Extract 65-byte signature
            uint256 offset = i * 65;
            assembly {
                r := mload(add(signatures, add(offset, 32)))
                s := mload(add(signatures, add(offset, 64)))
                v := byte(0, mload(add(signatures, add(offset, 96))))
            }

            if (v < 27) {
                v += 27;
            }

            // 서명자 복구
            // Recover signer
            address signer = ecrecover(hash, v, r, s);

            // 유효한 소유자인지 확인
            // Check if valid owner
            require(signer != address(0), "Invalid signature");
            require(isOwner[signer], "Not owner");

            // 중복 서명 확인
            // Check for duplicate signatures
            for (uint256 j = 0; j < i; j++) {
                require(signers[j] != signer, "Duplicate signature");
            }

            signers[i] = signer;
        }

        return MAGICVALUE;
    }

    /**
     * @dev 서명을 사용하여 트랜잭션 실행
     * @dev Execute transaction using signatures
     *
     * @param to 대상 주소
     * @param to Target address
     *
     * @param value 전송할 ETH 양
     * @param value Amount of ETH to send
     *
     * @param data 호출 데이터
     * @param data Call data
     *
     * @param signatures 소유자들의 서명
     * @param signatures Signatures from owners
     */
    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bytes memory signatures
    ) external returns (bytes memory) {
        // 트랜잭션 해시 생성
        // Create transaction hash
        bytes32 txHash = getTransactionHash(to, value, data, nonce);

        // EIP-1271로 서명 검증
        // Verify signatures with EIP-1271
        require(
            this.isValidSignature(txHash, signatures) == MAGICVALUE,
            "Invalid signatures"
        );

        // nonce 증가 (재사용 방지)
        // Increment nonce (replay protection)
        nonce++;

        // 트랜잭션 실행
        // Execute transaction
        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "Transaction failed");

        emit Executed(to, value, data, nonce - 1);

        return result;
    }

    /**
     * @dev 트랜잭션 해시 생성
     * @dev Create transaction hash
     */
    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            getDomainSeparator(),
            keccak256(abi.encode(
                keccak256("Transaction(address to,uint256 value,bytes data,uint256 nonce)"),
                to,
                value,
                keccak256(data),
                _nonce
            ))
        ));
    }

    /**
     * @dev EIP-712 도메인 분리자 가져오기
     * @dev Get EIP-712 domain separator
     */
    function getDomainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("MultiSigWallet")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    /**
     * @dev 소유자 추가 (멀티시그 실행 필요)
     * @dev Add owner (requires multisig execution)
     */
    function addOwner(address owner) external onlyWallet {
        require(owner != address(0), "Invalid owner");
        require(!isOwner[owner], "Already owner");

        isOwner[owner] = true;
        owners.push(owner);

        emit OwnerAdded(owner);
    }

    /**
     * @dev 소유자 제거 (멀티시그 실행 필요)
     * @dev Remove owner (requires multisig execution)
     */
    function removeOwner(address owner) external onlyWallet {
        require(isOwner[owner], "Not owner");
        require(owners.length > threshold, "Cannot remove: threshold");

        isOwner[owner] = false;

        // 배열에서 소유자 제거
        // Remove owner from array
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        emit OwnerRemoved(owner);
    }

    /**
     * @dev 임계값 변경 (멀티시그 실행 필요)
     * @dev Change threshold (requires multisig execution)
     */
    function changeThreshold(uint256 _threshold) external onlyWallet {
        require(
            _threshold > 0 && _threshold <= owners.length,
            "Invalid threshold"
        );

        threshold = _threshold;
        emit ThresholdChanged(_threshold);
    }

    /**
     * @dev 지갑 자신만 호출 가능 (멀티시그로 실행된 경우)
     * @dev Only callable by wallet itself (when executed via multisig)
     */
    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet");
        _;
    }

    /**
     * @dev 소유자 목록 가져오기
     * @dev Get list of owners
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev 소유자 수 가져오기
     * @dev Get owner count
     */
    function getOwnerCount() external view returns (uint256) {
        return owners.length;
    }

    /**
     * @dev ETH 수신 가능
     * @dev Allow receiving ETH
     */
    receive() external payable {}

    /**
     * @dev 현재 잔액 조회
     * @dev Get current balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title TimelockedMultiSigWallet
 * @dev 시간 잠금 기능이 있는 멀티시그 지갑
 * @dev Multi-signature wallet with timelock functionality
 *
 * 트랜잭션을 즉시 실행하지 않고 일정 시간 후에 실행할 수 있습니다.
 * Transactions can be executed after a certain time delay instead of immediately.
 */
contract TimelockedMultiSigWallet is MultiSigWallet {
    // 시간 잠금 기간 (초)
    // Timelock period (seconds)
    uint256 public timelockPeriod;

    // 대기 중인 트랜잭션
    // Pending transactions
    struct PendingTransaction {
        address to;
        uint256 value;
        bytes data;
        uint256 executeAfter;
        bool executed;
    }

    mapping(bytes32 => PendingTransaction) public pendingTransactions;

    event TransactionQueued(bytes32 indexed txHash, uint256 executeAfter);
    event TransactionExecuted(bytes32 indexed txHash);
    event TransactionCancelled(bytes32 indexed txHash);

    constructor(
        address[] memory _owners,
        uint256 _threshold,
        uint256 _timelockPeriod
    ) MultiSigWallet(_owners, _threshold) {
        timelockPeriod = _timelockPeriod;
    }

    /**
     * @dev 트랜잭션을 큐에 추가
     * @dev Queue a transaction
     */
    function queueTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bytes memory signatures
    ) external returns (bytes32) {
        bytes32 txHash = getTransactionHash(to, value, data, nonce);

        // 서명 검증
        // Verify signatures
        require(
            this.isValidSignature(txHash, signatures) == 0x1626ba7e,
            "Invalid signatures"
        );

        uint256 executeAfter = block.timestamp + timelockPeriod;

        pendingTransactions[txHash] = PendingTransaction({
            to: to,
            value: value,
            data: data,
            executeAfter: executeAfter,
            executed: false
        });

        nonce++;

        emit TransactionQueued(txHash, executeAfter);

        return txHash;
    }

    /**
     * @dev 큐에 있는 트랜잭션 실행
     * @dev Execute queued transaction
     */
    function executeQueuedTransaction(bytes32 txHash) external returns (bytes memory) {
        PendingTransaction storage pending = pendingTransactions[txHash];

        require(pending.to != address(0), "Transaction not found");
        require(!pending.executed, "Already executed");
        require(block.timestamp >= pending.executeAfter, "Timelock not expired");

        pending.executed = true;

        (bool success, bytes memory result) = pending.to.call{value: pending.value}(pending.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(txHash);

        return result;
    }

    /**
     * @dev 대기 중인 트랜잭션 취소
     * @dev Cancel pending transaction
     */
    function cancelTransaction(bytes32 txHash) external onlyWallet {
        PendingTransaction storage pending = pendingTransactions[txHash];

        require(pending.to != address(0), "Transaction not found");
        require(!pending.executed, "Already executed");

        delete pendingTransactions[txHash];

        emit TransactionCancelled(txHash);
    }
}
