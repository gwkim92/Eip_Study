// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function nonces(address owner) external view returns (uint256);
}

/**
 * @title DAppWithPermit
 * @notice EIP-2612 permit을 활용하는 DApp 예제
 * @dev 다양한 permit 활용 패턴 시연
 */
contract DAppWithPermit {
    IERC20Permit public immutable token;

    // 사용자 예치 정보
    mapping(address => uint256) public deposits;

    // 이벤트
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _token) {
        token = IERC20Permit(_token);
    }

    /**
     * @notice Permit을 사용한 예치 (기본 패턴)
     * @param amount 예치할 금액
     * @param deadline 서명 만료 시간
     * @param v 서명 v
     * @param r 서명 r
     * @param s 서명 s
     */
    function depositWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 1. Permit으로 승인
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        // 2. 토큰 전송
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // 3. 예치 기록
        deposits[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Permit을 사용한 예치 (안전한 버전)
     * @dev 이미 approve된 경우도 처리
     */
    function depositWithPermitSafe(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // try/catch로 permit 실패 처리
        try token.permit(msg.sender, address(this), amount, deadline, v, r, s) {
            // permit 성공
        } catch {
            // permit 실패 - allowance 확인
            require(
                token.allowance(msg.sender, address(this)) >= amount,
                "Insufficient allowance"
            );
        }

        // 토큰 전송
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        deposits[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice 출금
     */
    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient deposit");

        deposits[msg.sender] -= amount;

        // 토큰 전송 (실제로는 transfer 구현 필요)
        // token.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
}

/**
 * @title SwapRouter
 * @notice Permit을 활용한 DEX 라우터 예제
 * @dev 한 번의 트랜잭션으로 approve + swap 실행
 */
contract SwapRouter {
    IERC20Permit public immutable tokenA;
    IERC20Permit public immutable tokenB;

    // 간단한 가격 (실제로는 AMM 로직 필요)
    uint256 public constant PRICE = 2; // 1 TokenA = 2 TokenB

    event Swapped(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20Permit(_tokenA);
        tokenB = IERC20Permit(_tokenB);
    }

    /**
     * @notice Permit을 사용한 스왑
     * @param amountIn 입력 토큰 수량
     * @param deadline 서명 만료 시간
     * @param v 서명 v
     * @param r 서명 r
     * @param s 서명 s
     */
    function swapAforBWithPermit(
        uint256 amountIn,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 1. Permit으로 TokenA 승인
        tokenA.permit(msg.sender, address(this), amountIn, deadline, v, r, s);

        // 2. TokenA 받기
        require(
            tokenA.transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );

        // 3. TokenB 전송 (간단한 예제)
        uint256 amountOut = amountIn * PRICE;
        // tokenB.transfer(msg.sender, amountOut);

        emit Swapped(
            msg.sender,
            address(tokenA),
            address(tokenB),
            amountIn,
            amountOut
        );
    }
}

/**
 * @title GaslessRelayer
 * @notice 가스비 대납 서비스 (Meta-Transaction)
 * @dev 사용자는 서명만 하고, relayer가 가스비 지불
 */
contract GaslessRelayer {
    IERC20Permit public immutable token;

    // Relayer 수수료
    uint256 public constant FEE_PERCENTAGE = 1; // 1%

    event ExecutedWithPermit(
        address indexed user,
        address indexed beneficiary,
        uint256 amount,
        uint256 fee
    );

    constructor(address _token) {
        token = IERC20Permit(_token);
    }

    /**
     * @notice 사용자 대신 permit 실행 및 전송
     * @dev Relayer가 가스비를 지불하고, 수수료를 받음
     * @param owner 토큰 소유자
     * @param beneficiary 최종 수령자
     * @param amount 전송 금액
     * @param deadline 서명 만료 시간
     * @param v 서명 v
     * @param r 서명 r
     * @param s 서명 s
     */
    function executeWithPermit(
        address owner,
        address beneficiary,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 1. 사용자 대신 permit 실행
        token.permit(owner, address(this), amount, deadline, v, r, s);

        // 2. 토큰 받기
        require(
            token.transferFrom(owner, address(this), amount),
            "Transfer failed"
        );

        // 3. 수수료 계산
        uint256 fee = (amount * FEE_PERCENTAGE) / 100;
        uint256 netAmount = amount - fee;

        // 4. 수령자에게 전송 (간단한 예제)
        // token.transfer(beneficiary, netAmount);
        // token.transfer(msg.sender, fee); // relayer 수수료

        emit ExecutedWithPermit(owner, beneficiary, netAmount, fee);
    }
}

/**
 * @title MultiPermit
 * @notice 여러 토큰에 대한 permit을 한 번에 처리
 * @dev 복잡한 DeFi 작업에 유용
 */
contract MultiPermit {
    struct PermitData {
        address token;
        address owner;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event BatchPermitExecuted(address indexed executor, uint256 count);

    /**
     * @notice 여러 permit을 일괄 실행
     * @param permits Permit 데이터 배열
     */
    function batchPermit(PermitData[] calldata permits) external {
        for (uint256 i = 0; i < permits.length; i++) {
            PermitData calldata p = permits[i];

            try IERC20Permit(p.token).permit(
                p.owner,
                address(this),
                p.value,
                p.deadline,
                p.v,
                p.r,
                p.s
            ) {
                // permit 성공
            } catch {
                // permit 실패는 무시 (이미 approve되었을 수 있음)
            }
        }

        emit BatchPermitExecuted(msg.sender, permits.length);
    }
}
