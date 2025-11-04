// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title RealWorldExamples
 * @notice EIP-1559를 활용한 실전 예제 모음
 * @dev NFT 민팅, DEX 거래, 배치 전송 등 실무 시나리오
 */

// ============================================================
// 1. GAS-AWARE NFT MINTING (가스비 인식 NFT 민팅)
// ============================================================

/**
 * @title GasAwareNFT
 * @notice 가스비가 적정할 때만 민팅을 허용하는 NFT 컨트랙트
 */
contract GasAwareNFT {
    // Storage
    uint256 public constant MAX_BASE_FEE = 50 gwei;
    uint256 public tokenIdCounter;
    uint256 public totalMinted;

    mapping(uint256 => address) public owners;
    mapping(uint256 => string) public tokenURIs;
    mapping(address => uint256) public balanceOf;

    // Events
    event Minted(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 baseFee,
        uint256 timestamp
    );
    event MintingPaused(uint256 baseFee, uint256 maxAllowed);

    // Errors
    error BaseFeeT ooHigh(uint256 current, uint256 max);
    error NoTokensAvailable();

    /**
     * @notice 가스비가 적정할 때만 민팅
     * @param tokenURI 토큰 메타데이터 URI
     */
    function mint(string calldata tokenURI) external returns (uint256) {
        uint256 currentBaseFee = block.basefee;

        if (currentBaseFee > MAX_BASE_FEE) {
            revert BaseFeeT ooHigh(currentBaseFee, MAX_BASE_FEE);
        }

        uint256 tokenId = tokenIdCounter++;
        owners[tokenId] = msg.sender;
        tokenURIs[tokenId] = tokenURI;
        balanceOf[msg.sender]++;
        totalMinted++;

        emit Minted(tokenId, msg.sender, currentBaseFee, block.timestamp);

        return tokenId;
    }

    /**
     * @notice 현재 민팅 가능 여부 확인
     * @return allowed 민팅 가능 여부
     * @return currentBaseFee 현재 Base Fee
     * @return waitTime 예상 대기 시간 (블록 수)
     */
    function canMint() external view returns (
        bool allowed,
        uint256 currentBaseFee,
        uint256 waitTime
    ) {
        currentBaseFee = block.basefee;
        allowed = currentBaseFee <= MAX_BASE_FEE;

        if (!allowed) {
            waitTime = estimateWaitTime();
        }

        return (allowed, currentBaseFee, waitTime);
    }

    /**
     * @notice Base Fee가 MAX_BASE_FEE 이하로 떨어질 때까지 예상 블록 수
     * @dev 12.5% 감소 가정 (블록 이용률 0% 가정)
     */
    function estimateWaitTime() public view returns (uint256 blocks) {
        uint256 currentBaseFee = block.basefee;

        if (currentBaseFee <= MAX_BASE_FEE) {
            return 0;
        }

        blocks = 0;
        uint256 simulatedFee = currentBaseFee;

        // 최대 100블록까지만 계산
        while (simulatedFee > MAX_BASE_FEE && blocks < 100) {
            simulatedFee = simulatedFee * 875 / 1000;  // -12.5%
            blocks++;
        }

        return blocks;
    }

    /**
     * @notice 블록 수를 분 단위로 변환
     */
    function blocksToMinutes(uint256 blocks) public pure returns (uint256) {
        return (blocks * 12) / 60;  // 12초/블록, 60초/분
    }
}

// ============================================================
// 2. GAS-AWARE DEX (가스비 인식 탈중앙화 거래소)
// ============================================================

/**
 * @title GasAwareDEX
 * @notice Base Fee에 따라 슬리피지를 동적 조정하는 DEX
 */
contract GasAwareDEX {
    // Storage
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => uint256) public reserves;

    // Events
    event Swapped(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 baseFee
    );
    event SlippageAdjusted(uint256 baseFee, uint256 slippagePercent);

    /**
     * @notice 토큰 스왑 (Base Fee에 따라 슬리피지 자동 조정)
     * @param tokenIn 입력 토큰
     * @param tokenOut 출력 토큰
     * @param amountIn 입력 수량
     * @param minAmountOut 최소 출력 수량
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        // Base Fee에 따라 슬리피지 조정
        uint256 adjustedMinAmount = adjustSlippageForBaseFee(minAmountOut);

        // 스왑 실행 (간단한 예제)
        amountOut = calculateSwapOutput(tokenIn, tokenOut, amountIn);

        require(
            amountOut >= adjustedMinAmount,
            "Insufficient output amount"
        );

        // 실제 토큰 전송은 생략 (예제)
        emit Swapped(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            block.basefee
        );

        return amountOut;
    }

    /**
     * @notice Base Fee에 따라 슬리피지 조정
     * @dev 가스비 높음 = 네트워크 혼잡 = 가격 변동성 높음 = 슬리피지 완화
     */
    function adjustSlippageForBaseFee(uint256 minAmount)
        public
        view
        returns (uint256 adjustedAmount)
    {
        uint256 baseFeeGwei = block.basefee / 1 gwei;
        uint256 slippagePercent;

        if (baseFeeGwei < 20) {
            slippagePercent = 0;  // 슬리피지 유지
        } else if (baseFeeGwei < 50) {
            slippagePercent = 2;  // 2% 완화
        } else if (baseFeeGwei < 100) {
            slippagePercent = 5;  // 5% 완화
        } else {
            slippagePercent = 10;  // 10% 완화
        }

        adjustedAmount = minAmount * (100 - slippagePercent) / 100;

        emit SlippageAdjusted(block.basefee, slippagePercent);

        return adjustedAmount;
    }

    /**
     * @notice 스왑 출력량 계산 (간단한 예제)
     */
    function calculateSwapOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {
        // 실제로는 AMM 공식 사용 (x * y = k)
        // 여기서는 간단히 1:1 비율로 가정
        tokenIn; tokenOut;  // 사용 표시
        return amountIn * 99 / 100;  // 1% 수수료
    }
}

// ============================================================
// 3. BATCH PAYMENT SYSTEM (배치 전송 시스템)
// ============================================================

/**
 * @title BatchPaymentSystem
 * @notice Base Fee에 따라 배치 크기를 동적 조정하는 전송 시스템
 */
contract BatchPaymentSystem {
    // Storage
    mapping(address => uint256) public balances;

    // Events
    event BatchProcessed(
        uint256 totalAmount,
        uint256 recipientCount,
        uint256 baseFee,
        uint256 timestamp
    );
    event PaymentSent(address indexed to, uint256 amount);

    // Errors
    error InsufficientBalance(uint256 required, uint256 available);
    error InvalidArrayLength();

    /**
     * @notice 배치 전송 예치
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /**
     * @notice Base Fee에 따라 배치 크기 동적 조정
     * @param recipients 수신자 배열
     * @param amounts 금액 배열
     */
    function batchTransferDynamic(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        if (recipients.length != amounts.length) {
            revert InvalidArrayLength();
        }

        // Base Fee에 따라 처리할 개수 결정
        uint256 batchSize = calculateOptimalBatchSize(recipients.length);

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < batchSize; i++) {
            totalAmount += amounts[i];
        }

        if (balances[msg.sender] < totalAmount) {
            revert InsufficientBalance(totalAmount, balances[msg.sender]);
        }

        // 전송 실행
        balances[msg.sender] -= totalAmount;
        for (uint256 i = 0; i < batchSize; i++) {
            balances[recipients[i]] += amounts[i];
            emit PaymentSent(recipients[i], amounts[i]);
        }

        emit BatchProcessed(
            totalAmount,
            batchSize,
            block.basefee,
            block.timestamp
        );
    }

    /**
     * @notice Base Fee 기반 최적 배치 크기 계산
     */
    function calculateOptimalBatchSize(uint256 totalCount)
        public
        view
        returns (uint256 batchSize)
    {
        uint256 baseFeeGwei = block.basefee / 1 gwei;

        if (baseFeeGwei < 20) {
            batchSize = totalCount;  // 100% 처리
        } else if (baseFeeGwei < 50) {
            batchSize = totalCount * 75 / 100;  // 75% 처리
        } else if (baseFeeGwei < 100) {
            batchSize = totalCount / 2;  // 50% 처리
        } else {
            batchSize = totalCount / 10;  // 10% 처리
            if (batchSize == 0) batchSize = 1;  // 최소 1개
        }

        return batchSize;
    }

    /**
     * @notice 출금
     */
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
}

// ============================================================
// 4. SUBSCRIPTION SERVICE (구독 서비스)
// ============================================================

/**
 * @title GasAwareSubscription
 * @notice 가스비에 따라 자동 갱신 시기를 조정하는 구독 서비스
 */
contract GasAwareSubscription {
    // Storage
    struct Subscription {
        address user;
        uint256 startTime;
        uint256 endTime;
        uint256 monthlyFee;
        bool active;
    }

    mapping(address => Subscription) public subscriptions;
    uint256 public constant SUBSCRIPTION_PERIOD = 30 days;

    // Events
    event SubscriptionCreated(address indexed user, uint256 endTime);
    event SubscriptionRenewed(
        address indexed user,
        uint256 newEndTime,
        uint256 baseFee
    );
    event RenewalSkipped(address indexed user, uint256 baseFee);

    /**
     * @notice 구독 시작
     */
    function subscribe() external payable {
        require(msg.value > 0, "Must pay subscription fee");
        require(!subscriptions[msg.sender].active, "Already subscribed");

        subscriptions[msg.sender] = Subscription({
            user: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + SUBSCRIPTION_PERIOD,
            monthlyFee: msg.value,
            active: true
        });

        emit SubscriptionCreated(msg.sender, block.timestamp + SUBSCRIPTION_PERIOD);
    }

    /**
     * @notice 구독 자동 갱신 (Base Fee가 낮을 때만)
     * @param user 갱신할 사용자
     * @param maxBaseFeeGwei 최대 허용 Base Fee
     */
    function renewSubscription(address user, uint256 maxBaseFeeGwei)
        external
    {
        Subscription storage sub = subscriptions[user];
        require(sub.active, "No active subscription");
        require(block.timestamp >= sub.endTime, "Not expired yet");

        uint256 currentBaseFee = block.basefee;
        uint256 maxBaseFee = maxBaseFeeGwei * 1 gwei;

        if (currentBaseFee > maxBaseFee) {
            // Base Fee가 높으면 갱신 연기
            emit RenewalSkipped(user, currentBaseFee);
            return;
        }

        // 갱신 실행 (실제로는 사용자 잔액에서 차감)
        sub.endTime += SUBSCRIPTION_PERIOD;

        emit SubscriptionRenewed(user, sub.endTime, currentBaseFee);
    }

    /**
     * @notice 구독 상태 확인
     */
    function isSubscriptionActive(address user) external view returns (bool) {
        Subscription memory sub = subscriptions[user];
        return sub.active && block.timestamp < sub.endTime;
    }
}

// ============================================================
// 5. AIRDROP SYSTEM (에어드랍 시스템)
// ============================================================

/**
 * @title GasEfficientAirdrop
 * @notice 가스 효율적인 에어드랍 시스템
 */
contract GasEfficientAirdrop {
    // Storage
    address public owner;
    mapping(address => uint256) public claimableAmount;
    uint256 public totalClaimed;

    // Events
    event AirdropDistributed(uint256 recipientCount, uint256 totalAmount);
    event Claimed(address indexed user, uint256 amount, uint256 baseFee);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice 에어드랍 설정 (배치로 효율적 처리)
     * @dev calldata 사용으로 가스 절약
     */
    function setAirdrop(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(msg.sender == owner, "Not owner");
        require(recipients.length == amounts.length, "Length mismatch");

        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            claimableAmount[recipients[i]] = amounts[i];
            total += amounts[i];
        }

        emit AirdropDistributed(recipients.length, total);
    }

    /**
     * @notice 에어드랍 청구 (사용자가 직접)
     * @dev Pull 방식으로 가스 비용을 사용자가 부담
     */
    function claim() external {
        uint256 amount = claimableAmount[msg.sender];
        require(amount > 0, "Nothing to claim");

        claimableAmount[msg.sender] = 0;
        totalClaimed += amount;

        // 실제로는 토큰 전송
        // IERC20(token).transfer(msg.sender, amount);

        emit Claimed(msg.sender, amount, block.basefee);
    }

    /**
     * @notice Base Fee가 낮을 때 여러 사용자 대신 청구
     * @dev 가스비가 저렴할 때 배치로 처리
     */
    function batchClaimFor(address[] calldata users) external {
        require(msg.sender == owner, "Not owner");
        require(block.basefee <= 30 gwei, "Base fee too high");

        for (uint256 i = 0; i < users.length; i++) {
            uint256 amount = claimableAmount[users[i]];
            if (amount > 0) {
                claimableAmount[users[i]] = 0;
                totalClaimed += amount;

                emit Claimed(users[i], amount, block.basefee);
            }
        }
    }
}

// ============================================================
// 6. GOVERNANCE VOTING (거버넌스 투표)
// ============================================================

/**
 * @title GasAwareGovernance
 * @notice Base Fee가 낮을 때 투표 장려
 */
contract GasAwareGovernance {
    // Storage
    struct Proposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;

    // Events
    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 baseFee
    );
    event BonusGranted(address indexed voter, uint256 bonus);

    /**
     * @notice 제안 생성
     */
    function createProposal(string calldata description) external {
        proposals[proposalCount] = Proposal({
            description: description,
            forVotes: 0,
            againstVotes: 0,
            deadline: block.timestamp + 7 days,
            executed: false
        });

        emit ProposalCreated(proposalCount, description);
        proposalCount++;
    }

    /**
     * @notice 투표 (Base Fee 낮을 때 보너스)
     * @param proposalId 제안 ID
     * @param support 찬성 여부
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.forVotes++;
        } else {
            proposal.againstVotes++;
        }

        // Base Fee가 낮을 때 투표하면 보너스
        uint256 baseFeeGwei = block.basefee / 1 gwei;
        if (baseFeeGwei < 20) {
            uint256 bonus = 100;  // 보너스 포인트
            emit BonusGranted(msg.sender, bonus);
        }

        emit Voted(proposalId, msg.sender, support, block.basefee);
    }

    /**
     * @notice 현재 투표하기 좋은 시간인지 확인
     */
    function isGoodTimeToVote() external view returns (bool, uint256) {
        uint256 baseFeeGwei = block.basefee / 1 gwei;
        bool isGood = baseFeeGwei < 30;

        return (isGood, baseFeeGwei);
    }
}

// ============================================================
// 7. USAGE EXAMPLE (통합 사용 예제)
// ============================================================

/**
 * @title EIP1559UsageExample
 * @notice 다양한 시나리오에서 EIP-1559 활용 예제
 */
contract EIP1559UsageExample {
    GasAwareNFT public nft;
    GasAwareDEX public dex;
    BatchPaymentSystem public payments;

    constructor() {
        nft = new GasAwareNFT();
        dex = new GasAwareDEX();
        payments = new BatchPaymentSystem();
    }

    /**
     * @notice 현재 Base Fee 상황 보고
     */
    function getCurrentGasReport() external view returns (
        uint256 baseFeeGwei,
        string memory level,
        bool goodForMinting,
        bool goodForSwapping,
        bool goodForBatch
    ) {
        baseFeeGwei = block.basefee / 1 gwei;

        if (baseFeeGwei < 20) {
            level = "Very Low - Perfect for all operations";
        } else if (baseFeeGwei < 50) {
            level = "Low - Good for most operations";
        } else if (baseFeeGwei < 100) {
            level = "Medium - Consider waiting";
        } else if (baseFeeGwei < 200) {
            level = "High - Only urgent transactions";
        } else {
            level = "Very High - Wait if possible";
        }

        goodForMinting = baseFeeGwei < 50;
        goodForSwapping = baseFeeGwei < 100;
        goodForBatch = baseFeeGwei < 30;

        return (baseFeeGwei, level, goodForMinting, goodForSwapping, goodForBatch);
    }
}
