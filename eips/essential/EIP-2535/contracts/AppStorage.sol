// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AppStorage
 * @notice 모든 Facet이 공유하는 애플리케이션 데이터 구조
 * @dev Diamond Pattern에서 스토리지 충돌을 방지하기 위한 패턴
 *
 * AppStorage Pattern의 핵심:
 * - 모든 Facet이 동일한 struct를 첫 번째 storage 변수로 선언
 * - Solidity의 storage layout 규칙에 따라 모든 Facet이 같은 위치 참조
 * - 새로운 필드는 반드시 struct 끝에만 추가
 *
 * 사용 방법:
 * ```
 * contract SomeFacet {
 *     AppStorage internal s;  // slot 0에 배치
 *
 *     function someFunction() external {
 *         s.balances[msg.sender] += 100;  // 공유 스토리지 접근
 *     }
 * }
 * ```
 *
 * ⚠️ 중요 규칙:
 * 1. 기존 필드의 순서를 절대 변경하지 말 것
 * 2. 기존 필드를 삭제하지 말 것
 * 3. 새 필드는 반드시 끝에만 추가
 * 4. 필드 타입을 변경하지 말 것
 */

/**
 * @notice 제안(Proposal) 정보를 담는 구조체
 * @dev 거버넌스 기능에서 사용
 */
struct Proposal {
    address proposer;           // 제안자 주소
    string description;         // 제안 설명
    uint256 forVotes;          // 찬성 투표 수
    uint256 againstVotes;      // 반대 투표 수
    uint256 deadline;          // 투표 마감 시간
    bool executed;             // 실행 여부
    mapping(address => bool) hasVoted;  // 투표 여부 추적
}

/**
 * @notice 스테이킹 정보를 담는 구조체
 * @dev 스테이킹 기능에서 사용
 */
struct StakeInfo {
    uint256 amount;            // 스테이킹한 토큰 양
    uint256 timestamp;         // 스테이킹 시작 시간
    uint256 rewards;           // 누적 보상
}

/**
 * @notice 메인 애플리케이션 스토리지 구조체
 * @dev 모든 Facet이 공유하는 데이터
 *
 * Storage Layout:
 * - slot 0부터 시작
 * - mapping은 keccak256(key . slot)에 저장
 * - 동적 배열은 keccak256(slot)에 길이, keccak256(slot) + index에 요소 저장
 */
struct AppStorage {
    // ============================================
    // ERC20 기본 데이터
    // ============================================

    /// @notice 계정별 토큰 잔액
    /// @dev mapping(address => uint256)는 slot을 차지하지만 실제 데이터는 keccak256(address . slot)에 저장
    mapping(address => uint256) balances;

    /// @notice 계정별 승인된 지출 한도
    /// @dev owner → spender → amount
    mapping(address => mapping(address => uint256)) allowances;

    /// @notice 총 발행량
    uint256 totalSupply;

    /// @notice 토큰 이름
    string name;

    /// @notice 토큰 심볼
    string symbol;

    /// @notice 토큰 소수점 자리수
    uint8 decimals;

    // ============================================
    // 소유권 및 권한 관리
    // ============================================

    /// @notice 컨트랙트 소유자
    address owner;

    /// @notice 관리자 주소들
    mapping(address => bool) admins;

    /// @notice 일시 중지 상태
    bool paused;

    // ============================================
    // 거버넌스 데이터
    // ============================================

    /// @notice 제안 ID → 제안 정보
    mapping(uint256 => Proposal) proposals;

    /// @notice 총 제안 수
    uint256 proposalCount;

    /// @notice 최소 제안 임계값 (토큰 양)
    uint256 proposalThreshold;

    /// @notice 투표 기간 (초)
    uint256 votingPeriod;

    // ============================================
    // 스테이킹 데이터
    // ============================================

    /// @notice 주소별 스테이킹 정보
    mapping(address => StakeInfo) stakes;

    /// @notice 전체 스테이킹된 토큰 양
    uint256 totalStaked;

    /// @notice 블록당 보상률 (wei 단위)
    uint256 rewardRate;

    /// @notice 최소 스테이킹 기간 (초)
    uint256 minStakingPeriod;

    // ============================================
    // 추가 기능 데이터
    // ============================================

    /// @notice 계정별 nonce (replay 공격 방지)
    mapping(address => uint256) nonces;

    /// @notice 블랙리스트
    mapping(address => bool) blacklist;

    /// @notice 화이트리스트
    mapping(address => bool) whitelist;

    /// @notice 최대 거래 금액
    uint256 maxTransactionAmount;

    /// @notice 거래 수수료 (basis points, 10000 = 100%)
    uint256 transactionFee;

    /// @notice 수수료 수령자
    address feeRecipient;

    // ============================================
    // 향후 확장을 위한 공간
    // ============================================

    /// @notice 예약된 슬롯 1 (나중에 사용)
    uint256 reserved1;

    /// @notice 예약된 슬롯 2 (나중에 사용)
    uint256 reserved2;

    /// @notice 예약된 슬롯 3 (나중에 사용)
    uint256 reserved3;
}

/**
 * 사용 예시:
 *
 * // === Facet에서 AppStorage 사용 ===
 *
 * contract ERC20Facet {
 *     AppStorage internal s;
 *
 *     function transfer(address to, uint256 amount) external returns (bool) {
 *         require(!s.paused, "Transfer paused");
 *         require(!s.blacklist[msg.sender], "Sender blacklisted");
 *         require(!s.blacklist[to], "Recipient blacklisted");
 *         require(s.balances[msg.sender] >= amount, "Insufficient balance");
 *
 *         // 수수료 계산
 *         uint256 fee = (amount * s.transactionFee) / 10000;
 *         uint256 amountAfterFee = amount - fee;
 *
 *         // 잔액 업데이트
 *         s.balances[msg.sender] -= amount;
 *         s.balances[to] += amountAfterFee;
 *         s.balances[s.feeRecipient] += fee;
 *
 *         emit Transfer(msg.sender, to, amountAfterFee);
 *         return true;
 *     }
 *
 *     function balanceOf(address account) external view returns (uint256) {
 *         return s.balances[account];
 *     }
 * }
 *
 * contract GovernanceFacet {
 *     AppStorage internal s;
 *
 *     function propose(string calldata description) external returns (uint256) {
 *         require(
 *             s.balances[msg.sender] >= s.proposalThreshold,
 *             "Insufficient tokens to propose"
 *         );
 *
 *         uint256 proposalId = s.proposalCount++;
 *         Proposal storage proposal = s.proposals[proposalId];
 *         proposal.proposer = msg.sender;
 *         proposal.description = description;
 *         proposal.deadline = block.timestamp + s.votingPeriod;
 *
 *         return proposalId;
 *     }
 *
 *     function vote(uint256 proposalId, bool support) external {
 *         Proposal storage proposal = s.proposals[proposalId];
 *         require(block.timestamp < proposal.deadline, "Voting ended");
 *         require(!proposal.hasVoted[msg.sender], "Already voted");
 *
 *         uint256 votes = s.balances[msg.sender];
 *         proposal.hasVoted[msg.sender] = true;
 *
 *         if (support) {
 *             proposal.forVotes += votes;
 *         } else {
 *             proposal.againstVotes += votes;
 *         }
 *     }
 * }
 *
 * contract StakingFacet {
 *     AppStorage internal s;
 *
 *     function stake(uint256 amount) external {
 *         require(amount > 0, "Amount must be positive");
 *         require(s.balances[msg.sender] >= amount, "Insufficient balance");
 *
 *         // 기존 보상 정산
 *         _updateRewards(msg.sender);
 *
 *         // 잔액 이동
 *         s.balances[msg.sender] -= amount;
 *
 *         // 스테이킹 정보 업데이트
 *         s.stakes[msg.sender].amount += amount;
 *         s.stakes[msg.sender].timestamp = block.timestamp;
 *         s.totalStaked += amount;
 *     }
 *
 *     function _updateRewards(address account) internal {
 *         StakeInfo storage stakeInfo = s.stakes[account];
 *         if (stakeInfo.amount > 0) {
 *             uint256 elapsed = block.timestamp - stakeInfo.timestamp;
 *             uint256 reward = (stakeInfo.amount * s.rewardRate * elapsed) / 1e18;
 *             stakeInfo.rewards += reward;
 *         }
 *     }
 * }
 */

/**
 * ⚠️ 주의사항 및 모범 사례:
 *
 * === 올바른 확장 방법 ===
 *
 * ✅ 좋음: 끝에 추가
 * ```
 * struct AppStorage {
 *     uint256 value1;     // slot 0
 *     address owner;      // slot 1
 *     // ... 기존 필드들 ...
 *     uint256 newValue;   // 새 필드는 끝에 추가
 *     address newOwner;   // 새 필드는 끝에 추가
 * }
 * ```
 *
 * === 잘못된 확장 방법 ===
 *
 * ❌ 나쁨: 순서 변경
 * ```
 * struct AppStorage {
 *     address owner;      // slot 0 (이전에는 slot 1)
 *     uint256 value1;     // slot 1 (이전에는 slot 0)
 *     // 데이터가 뒤섞임!
 * }
 * ```
 *
 * ❌ 나쁨: 중간에 삽입
 * ```
 * struct AppStorage {
 *     uint256 value1;     // slot 0
 *     uint256 newValue;   // 새 필드 (중간에 삽입)
 *     address owner;      // slot 2 (이전에는 slot 1)
 *     // 데이터가 뒤섞임!
 * }
 * ```
 *
 * ❌ 나쁨: 타입 변경
 * ```
 * struct AppStorage {
 *     address value1;     // 이전에는 uint256
 *     // 타입이 달라져서 데이터 손상!
 * }
 * ```
 *
 * === Storage Slot 계산 ===
 *
 * 기본 타입:
 * - uint256, address, bool 등: 하나의 slot 차지
 * - uint128 두 개: 하나의 slot에 패킹 가능
 *
 * 동적 타입:
 * - mapping: slot을 차지하지만 실제 데이터는 다른 곳에 저장
 * - 동적 배열: slot에 길이 저장, 요소는 다른 곳에 저장
 * - string: 짧으면 slot에, 길면 다른 곳에 저장
 *
 * === 버전 관리 ===
 *
 * 버전 정보를 포함하는 것이 좋습니다:
 * ```
 * struct AppStorage {
 *     uint256 storageVersion;  // 현재: 1
 *     // ... 다른 필드들 ...
 * }
 * ```
 *
 * === 네임스페이스 구분 ===
 *
 * 큰 프로젝트에서는 기능별로 struct를 분리할 수 있습니다:
 * ```
 * struct ERC20Storage {
 *     mapping(address => uint256) balances;
 *     mapping(address => mapping(address => uint256)) allowances;
 *     uint256 totalSupply;
 * }
 *
 * struct GovernanceStorage {
 *     mapping(uint256 => Proposal) proposals;
 *     uint256 proposalCount;
 * }
 *
 * struct AppStorage {
 *     ERC20Storage erc20;
 *     GovernanceStorage governance;
 * }
 * ```
 */
