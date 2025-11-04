// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage, Proposal, StakeInfo} from "./AppStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";

/**
 * @title ERC20Facet
 * @notice ERC20 기본 기능을 구현하는 Facet
 * @dev transfer, approve, balanceOf 등 핵심 기능 제공
 */
contract ERC20Facet {
    AppStorage internal s;

    // ============================================
    // Events
    // ============================================

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ============================================
    // External Functions
    // ============================================

    /**
     * @notice 토큰 전송
     * @param to 받는 주소
     * @param amount 전송할 토큰 양
     * @return success 성공 여부
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "ERC20: transfer to zero address");
        require(!s.paused, "ERC20: transfers paused");
        require(!s.blacklist[msg.sender], "ERC20: sender blacklisted");
        require(!s.blacklist[to], "ERC20: recipient blacklisted");

        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @notice 승인된 토큰 전송
     * @param from 보내는 주소
     * @param to 받는 주소
     * @param amount 전송할 토큰 양
     * @return success 성공 여부
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(to != address(0), "ERC20: transfer to zero address");
        require(!s.paused, "ERC20: transfers paused");
        require(!s.blacklist[from], "ERC20: sender blacklisted");
        require(!s.blacklist[to], "ERC20: recipient blacklisted");

        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @notice 지출 승인
     * @param spender 승인받을 주소
     * @param amount 승인할 토큰 양
     * @return success 성공 여부
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "ERC20: approve to zero address");

        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @notice 계정의 토큰 잔액 조회
     * @param account 조회할 주소
     * @return balance 토큰 잔액
     */
    function balanceOf(address account) external view returns (uint256) {
        return s.balances[account];
    }

    /**
     * @notice 승인된 지출 한도 조회
     * @param owner 토큰 소유자
     * @param spender 지출자
     * @return allowance 승인된 토큰 양
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return s.allowances[owner][spender];
    }

    /**
     * @notice 총 발행량 조회
     * @return totalSupply 총 발행량
     */
    function totalSupply() external view returns (uint256) {
        return s.totalSupply;
    }

    /**
     * @notice 토큰 이름 조회
     * @return name 토큰 이름
     */
    function name() external view returns (string memory) {
        return s.name;
    }

    /**
     * @notice 토큰 심볼 조회
     * @return symbol 토큰 심볼
     */
    function symbol() external view returns (string memory) {
        return s.symbol;
    }

    /**
     * @notice 소수점 자리수 조회
     * @return decimals 소수점 자리수
     */
    function decimals() external view returns (uint8) {
        return s.decimals;
    }

    // ============================================
    // Internal Functions
    // ============================================

    function _transfer(address from, address to, uint256 amount) internal {
        require(s.balances[from] >= amount, "ERC20: insufficient balance");

        unchecked {
            s.balances[from] -= amount;
            s.balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        s.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = s.allowances[owner][spender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");

        unchecked {
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}

/**
 * @title ERC20AdvancedFacet
 * @notice ERC20 고급 기능을 구현하는 Facet
 * @dev mint, burn, permit 등 추가 기능 제공
 */
contract ERC20AdvancedFacet {
    AppStorage internal s;

    // ============================================
    // Events
    // ============================================

    event Transfer(address indexed from, address indexed to, uint256 value);

    // ============================================
    // External Functions
    // ============================================

    /**
     * @notice 토큰 발행
     * @param to 받을 주소
     * @param amount 발행할 토큰 양
     */
    function mint(address to, uint256 amount) external {
        LibDiamond.enforceIsContractOwner();
        require(to != address(0), "ERC20: mint to zero address");

        s.totalSupply += amount;
        unchecked {
            s.balances[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice 토큰 소각
     * @param amount 소각할 토큰 양
     */
    function burn(uint256 amount) external {
        address account = msg.sender;
        require(s.balances[account] >= amount, "ERC20: burn amount exceeds balance");

        unchecked {
            s.balances[account] -= amount;
            s.totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    /**
     * @notice 다른 계정의 토큰 소각 (승인 필요)
     * @param account 소각할 계정
     * @param amount 소각할 토큰 양
     */
    function burnFrom(address account, uint256 amount) external {
        require(s.balances[account] >= amount, "ERC20: burn amount exceeds balance");

        uint256 currentAllowance = s.allowances[account][msg.sender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");

        unchecked {
            s.allowances[account][msg.sender] = currentAllowance - amount;
            s.balances[account] -= amount;
            s.totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    /**
     * @notice 지출 한도 증가
     * @param spender 지출자
     * @param addedValue 증가시킬 양
     * @return success 성공 여부
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        address owner = msg.sender;
        s.allowances[owner][spender] += addedValue;
        return true;
    }

    /**
     * @notice 지출 한도 감소
     * @param spender 지출자
     * @param subtractedValue 감소시킬 양
     * @return success 성공 여부
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = s.allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");

        unchecked {
            s.allowances[owner][spender] = currentAllowance - subtractedValue;
        }
        return true;
    }
}

/**
 * @title GovernanceFacet
 * @notice 거버넌스 기능을 구현하는 Facet
 * @dev 제안 생성, 투표, 실행 기능 제공
 */
contract GovernanceFacet {
    AppStorage internal s;

    // ============================================
    // Events
    // ============================================

    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);

    // ============================================
    // External Functions
    // ============================================

    /**
     * @notice 제안 생성
     * @param description 제안 설명
     * @return proposalId 생성된 제안 ID
     */
    function propose(string calldata description) external returns (uint256) {
        require(
            s.balances[msg.sender] >= s.proposalThreshold,
            "Governance: insufficient tokens to propose"
        );

        uint256 proposalId = s.proposalCount++;
        Proposal storage proposal = s.proposals[proposalId];

        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.deadline = block.timestamp + s.votingPeriod;
        proposal.executed = false;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    /**
     * @notice 제안에 투표
     * @param proposalId 제안 ID
     * @param support 찬성(true) 또는 반대(false)
     */
    function vote(uint256 proposalId, bool support) external {
        require(proposalId < s.proposalCount, "Governance: invalid proposal");

        Proposal storage proposal = s.proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Governance: voting ended");
        require(!proposal.hasVoted[msg.sender], "Governance: already voted");

        uint256 votes = s.balances[msg.sender];
        require(votes > 0, "Governance: no voting power");

        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /**
     * @notice 제안 실행
     * @param proposalId 제안 ID
     */
    function executeProposal(uint256 proposalId) external {
        require(proposalId < s.proposalCount, "Governance: invalid proposal");

        Proposal storage proposal = s.proposals[proposalId];
        require(block.timestamp >= proposal.deadline, "Governance: voting not ended");
        require(!proposal.executed, "Governance: already executed");
        require(proposal.forVotes > proposal.againstVotes, "Governance: proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice 제안 정보 조회
     * @param proposalId 제안 ID
     * @return proposer 제안자
     * @return description 설명
     * @return forVotes 찬성표
     * @return againstVotes 반대표
     * @return deadline 마감 시간
     * @return executed 실행 여부
     */
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 deadline,
            bool executed
        )
    {
        require(proposalId < s.proposalCount, "Governance: invalid proposal");

        Proposal storage proposal = s.proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.deadline,
            proposal.executed
        );
    }

    /**
     * @notice 거버넌스 설정 변경
     * @param proposalThreshold 최소 제안 임계값
     * @param votingPeriod 투표 기간
     */
    function setGovernanceConfig(uint256 proposalThreshold, uint256 votingPeriod) external {
        LibDiamond.enforceIsContractOwner();
        s.proposalThreshold = proposalThreshold;
        s.votingPeriod = votingPeriod;
    }
}

/**
 * @title StakingFacet
 * @notice 스테이킹 기능을 구현하는 Facet
 * @dev 토큰 스테이킹, 언스테이킹, 보상 청구 기능 제공
 */
contract StakingFacet {
    AppStorage internal s;

    // ============================================
    // Events
    // ============================================

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    // ============================================
    // External Functions
    // ============================================

    /**
     * @notice 토큰 스테이킹
     * @param amount 스테이킹할 토큰 양
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Staking: amount must be positive");
        require(s.balances[msg.sender] >= amount, "Staking: insufficient balance");

        // 기존 보상 업데이트
        _updateRewards(msg.sender);

        // 잔액 이동
        s.balances[msg.sender] -= amount;

        // 스테이킹 정보 업데이트
        s.stakes[msg.sender].amount += amount;
        s.stakes[msg.sender].timestamp = block.timestamp;
        s.totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice 토큰 언스테이킹
     * @param amount 언스테이킹할 토큰 양
     */
    function unstake(uint256 amount) external {
        StakeInfo storage stakeInfo = s.stakes[msg.sender];
        require(amount > 0, "Staking: amount must be positive");
        require(stakeInfo.amount >= amount, "Staking: insufficient staked amount");
        require(
            block.timestamp >= stakeInfo.timestamp + s.minStakingPeriod,
            "Staking: min staking period not met"
        );

        // 기존 보상 업데이트
        _updateRewards(msg.sender);

        // 스테이킹 정보 업데이트
        stakeInfo.amount -= amount;
        s.totalStaked -= amount;

        // 잔액 이동
        s.balances[msg.sender] += amount;

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice 스테이킹 보상 청구
     */
    function claimRewards() external {
        _updateRewards(msg.sender);

        StakeInfo storage stakeInfo = s.stakes[msg.sender];
        uint256 rewards = stakeInfo.rewards;
        require(rewards > 0, "Staking: no rewards to claim");

        stakeInfo.rewards = 0;
        s.balances[msg.sender] += rewards;

        emit RewardsClaimed(msg.sender, rewards);
    }

    /**
     * @notice 스테이킹 정보 조회
     * @param account 조회할 주소
     * @return amount 스테이킹한 양
     * @return rewards 누적 보상
     * @return timestamp 스테이킹 시작 시간
     */
    function getStakeInfo(address account)
        external
        view
        returns (uint256 amount, uint256 rewards, uint256 timestamp)
    {
        StakeInfo storage stakeInfo = s.stakes[account];
        uint256 pendingRewards = _calculateRewards(account);

        return (
            stakeInfo.amount,
            stakeInfo.rewards + pendingRewards,
            stakeInfo.timestamp
        );
    }

    /**
     * @notice 스테이킹 설정 변경
     * @param rewardRate 블록당 보상률
     * @param minStakingPeriod 최소 스테이킹 기간
     */
    function setStakingConfig(uint256 rewardRate, uint256 minStakingPeriod) external {
        LibDiamond.enforceIsContractOwner();
        s.rewardRate = rewardRate;
        s.minStakingPeriod = minStakingPeriod;
    }

    // ============================================
    // Internal Functions
    // ============================================

    function _updateRewards(address account) internal {
        StakeInfo storage stakeInfo = s.stakes[account];
        if (stakeInfo.amount > 0) {
            uint256 rewards = _calculateRewards(account);
            stakeInfo.rewards += rewards;
            stakeInfo.timestamp = block.timestamp;
        }
    }

    function _calculateRewards(address account) internal view returns (uint256) {
        StakeInfo storage stakeInfo = s.stakes[account];
        if (stakeInfo.amount == 0) {
            return 0;
        }

        uint256 elapsed = block.timestamp - stakeInfo.timestamp;
        return (stakeInfo.amount * s.rewardRate * elapsed) / 1e18;
    }
}

/**
 * @title AdminFacet
 * @notice 관리자 기능을 구현하는 Facet
 * @dev 일시 중지, 블랙리스트, 화이트리스트 등 관리 기능 제공
 */
contract AdminFacet {
    AppStorage internal s;

    // ============================================
    // Events
    // ============================================

    event Paused(address account);
    event Unpaused(address account);
    event Blacklisted(address account);
    event Unblacklisted(address account);
    event Whitelisted(address account);
    event Unwhitelisted(address account);

    // ============================================
    // External Functions
    // ============================================

    /**
     * @notice 컨트랙트 일시 중지
     */
    function pause() external {
        LibDiamond.enforceIsContractOwner();
        require(!s.paused, "Admin: already paused");
        s.paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice 컨트랙트 일시 중지 해제
     */
    function unpause() external {
        LibDiamond.enforceIsContractOwner();
        require(s.paused, "Admin: not paused");
        s.paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice 블랙리스트 추가
     * @param account 추가할 주소
     */
    function blacklist(address account) external {
        LibDiamond.enforceIsContractOwner();
        require(!s.blacklist[account], "Admin: already blacklisted");
        s.blacklist[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @notice 블랙리스트 제거
     * @param account 제거할 주소
     */
    function unblacklist(address account) external {
        LibDiamond.enforceIsContractOwner();
        require(s.blacklist[account], "Admin: not blacklisted");
        s.blacklist[account] = false;
        emit Unblacklisted(account);
    }

    /**
     * @notice 화이트리스트 추가
     * @param account 추가할 주소
     */
    function whitelist(address account) external {
        LibDiamond.enforceIsContractOwner();
        require(!s.whitelist[account], "Admin: already whitelisted");
        s.whitelist[account] = true;
        emit Whitelisted(account);
    }

    /**
     * @notice 화이트리스트 제거
     * @param account 제거할 주소
     */
    function unwhitelist(address account) external {
        LibDiamond.enforceIsContractOwner();
        require(s.whitelist[account], "Admin: not whitelisted");
        s.whitelist[account] = false;
        emit Unwhitelisted(account);
    }

    /**
     * @notice 일시 중지 상태 조회
     * @return paused 일시 중지 여부
     */
    function isPaused() external view returns (bool) {
        return s.paused;
    }

    /**
     * @notice 블랙리스트 여부 조회
     * @param account 조회할 주소
     * @return blacklisted 블랙리스트 여부
     */
    function isBlacklisted(address account) external view returns (bool) {
        return s.blacklist[account];
    }

    /**
     * @notice 화이트리스트 여부 조회
     * @param account 조회할 주소
     * @return whitelisted 화이트리스트 여부
     */
    function isWhitelisted(address account) external view returns (bool) {
        return s.whitelist[account];
    }
}
