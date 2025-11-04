// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1271.sol";

/**
 * @title EIP1271Integration
 * @dev EIP-1271을 기존 DApp에 통합하는 예제
 * @dev Examples of integrating EIP-1271 into existing DApps
 */

/**
 * @title TokenTransferWithSignature
 * @dev 서명을 사용한 토큰 전송 (메타 트랜잭션)
 * @dev Token transfer using signatures (meta-transactions)
 */
contract TokenTransferWithSignature {
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    // EIP-712 도메인 및 타입 해시
    // EIP-712 domain and type hashes
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 private constant TRANSFER_TYPEHASH = keccak256(
        "Transfer(address from,address to,uint256 amount,uint256 nonce,uint256 deadline)"
    );

    bytes32 public immutable DOMAIN_SEPARATOR;

    // 토큰 잔액
    // Token balances
    mapping(address => uint256) public balances;

    // nonce 매핑
    // Nonce mapping
    mapping(address => uint256) public nonces;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event MetaTransfer(address indexed from, address indexed to, uint256 amount, address indexed relayer);

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes("TokenTransferWithSignature")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    /**
     * @dev 토큰 발행 (테스트용)
     * @dev Mint tokens (for testing)
     */
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }

    /**
     * @dev 일반 전송
     * @dev Regular transfer
     */
    function transfer(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
    }

    /**
     * @dev 서명을 사용한 전송 (EOA 및 스마트 컨트랙트 지갑 지원)
     * @dev Transfer using signature (supports EOA and smart contract wallets)
     *
     * @param from 보낸 사람
     * @param from Sender
     *
     * @param to 받는 사람
     * @param to Recipient
     *
     * @param amount 전송할 양
     * @param amount Amount to transfer
     *
     * @param deadline 서명 만료 시간
     * @param deadline Signature deadline
     *
     * @param signature 서명 데이터
     * @param signature Signature data
     */
    function transferWithSignature(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) external {
        require(block.timestamp <= deadline, "Signature expired");
        require(balances[from] >= amount, "Insufficient balance");

        // 서명 해시 생성
        // Create signature hash
        bytes32 structHash = keccak256(abi.encode(
            TRANSFER_TYPEHASH,
            from,
            to,
            amount,
            nonces[from],
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        // 서명 검증 (EOA 및 컨트랙트 지원)
        // Verify signature (supports EOA and contracts)
        require(_verifySignature(from, digest, signature), "Invalid signature");

        // nonce 증가
        // Increment nonce
        nonces[from]++;

        // 전송 실행
        // Execute transfer
        balances[from] -= amount;
        balances[to] += amount;

        emit MetaTransfer(from, to, amount, msg.sender);
    }

    /**
     * @dev 서명 검증 (EOA 및 스마트 컨트랙트 지원)
     * @dev Verify signature (supports EOA and smart contracts)
     */
    function _verifySignature(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (bool) {
        // 컨트랙트 여부 확인
        // Check if contract
        if (_isContract(signer)) {
            // 스마트 컨트랙트: EIP-1271
            // Smart contract: EIP-1271
            try IERC1271(signer).isValidSignature(digest, signature)
                returns (bytes4 magicValue) {
                return magicValue == MAGICVALUE;
            } catch {
                return false;
            }
        } else {
            // EOA: ecrecover
            if (signature.length != 65) {
                return false;
            }

            bytes32 r;
            bytes32 s;
            uint8 v;

            assembly {
                r := mload(add(signature, 32))
                s := mload(add(signature, 64))
                v := byte(0, mload(add(signature, 96)))
            }

            if (v < 27) {
                v += 27;
            }

            address recoveredSigner = ecrecover(digest, v, r, s);
            return recoveredSigner != address(0) && recoveredSigner == signer;
        }
    }

    /**
     * @dev 주소가 컨트랙트인지 확인
     * @dev Check if address is a contract
     */
    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

/**
 * @title DAOGovernance
 * @dev EIP-1271을 사용한 DAO 거버넌스
 * @dev DAO governance using EIP-1271
 */
contract DAOGovernance {
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    /**
     * @dev 제안 구조체
     * @dev Proposal struct
     */
    struct Proposal {
        string description;
        address target;
        bytes data;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    // 제안 매핑
    // Proposal mapping
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // 투표권 (단순화를 위해 balance 사용)
    // Voting power (using balance for simplicity)
    mapping(address => uint256) public votingPower;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    /**
     * @dev 제안 생성
     * @dev Create proposal
     */
    function createProposal(
        string memory description,
        address target,
        bytes memory data,
        uint256 votingPeriod
    ) external returns (uint256) {
        uint256 proposalId = proposalCount++;

        Proposal storage proposal = proposals[proposalId];
        proposal.description = description;
        proposal.target = target;
        proposal.data = data;
        proposal.deadline = block.timestamp + votingPeriod;
        proposal.executed = false;

        emit ProposalCreated(proposalId, description);

        return proposalId;
    }

    /**
     * @dev 투표 (직접)
     * @dev Vote (direct)
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp < proposal.deadline, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 weight = votingPower[msg.sender];
        require(weight > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    /**
     * @dev 서명을 사용한 투표 (스마트 컨트랙트 지갑 지원)
     * @dev Vote using signature (supports smart contract wallets)
     */
    function voteWithSignature(
        uint256 proposalId,
        address voter,
        bool support,
        bytes memory signature
    ) external {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp < proposal.deadline, "Voting ended");
        require(!proposal.hasVoted[voter], "Already voted");

        // 투표 해시 생성
        // Create vote hash
        bytes32 voteHash = keccak256(abi.encodePacked(
            address(this),
            proposalId,
            voter,
            support
        ));

        // 서명 검증
        // Verify signature
        require(_verifySignature(voter, voteHash, signature), "Invalid signature");

        uint256 weight = votingPower[voter];
        require(weight > 0, "No voting power");

        proposal.hasVoted[voter] = true;

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit VoteCast(proposalId, voter, support, weight);
    }

    /**
     * @dev 제안 실행
     * @dev Execute proposal
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.deadline, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;

        (bool success,) = proposal.target.call(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev 투표권 설정 (테스트용)
     * @dev Set voting power (for testing)
     */
    function setVotingPower(address voter, uint256 power) external {
        votingPower[voter] = power;
    }

    /**
     * @dev 서명 검증
     * @dev Verify signature
     */
    function _verifySignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) private view returns (bool) {
        if (_isContract(signer)) {
            try IERC1271(signer).isValidSignature(hash, signature)
                returns (bytes4 magicValue) {
                return magicValue == MAGICVALUE;
            } catch {
                return false;
            }
        } else {
            if (signature.length != 65) {
                return false;
            }

            bytes32 r;
            bytes32 s;
            uint8 v;

            assembly {
                r := mload(add(signature, 32))
                s := mload(add(signature, 64))
                v := byte(0, mload(add(signature, 96)))
            }

            if (v < 27) {
                v += 27;
            }

            address recoveredSigner = ecrecover(hash, v, r, s);
            return recoveredSigner != address(0) && recoveredSigner == signer;
        }
    }

    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

/**
 * @title PermitToken
 * @dev EIP-2612 스타일 permit 함수 (EIP-1271 지원)
 * @dev EIP-2612 style permit function (with EIP-1271 support)
 */
contract PermitToken {
    bytes4 private constant MAGICVALUE = 0x1626ba7e;

    string public name = "Permit Token";
    string public symbol = "PMT";
    uint8 public decimals = 18;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => uint256) public nonces;

    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 private constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    /**
     * @dev Permit 함수 (EIP-1271 지원)
     * @dev Permit function (with EIP-1271 support)
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            nonces[owner]++,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        // EIP-1271 지원 서명 검증
        // EIP-1271 compatible signature verification
        require(_verifySignature(owner, digest, signature), "Invalid signature");

        allowances[owner][spender] = value;

        emit Approval(owner, spender, value);
    }

    function _verifySignature(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (bool) {
        if (_isContract(signer)) {
            try IERC1271(signer).isValidSignature(digest, signature)
                returns (bytes4 magicValue) {
                return magicValue == MAGICVALUE;
            } catch {
                return false;
            }
        } else {
            if (signature.length != 65) {
                return false;
            }

            bytes32 r;
            bytes32 s;
            uint8 v;

            assembly {
                r := mload(add(signature, 32))
                s := mload(add(signature, 64))
                v := byte(0, mload(add(signature, 96)))
            }

            if (v < 27) {
                v += 27;
            }

            address recoveredSigner = ecrecover(digest, v, r, s);
            return recoveredSigner != address(0) && recoveredSigner == signer;
        }
    }

    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }
}
