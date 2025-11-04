// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EIP4626Example
 * @dev EIP-4626 Tokenized Vault Standard 구현 예제
 *
 * EIP-4626은 수익 창출 볼트(Yield-bearing Vaults)에 대한 표준 API를 정의합니다.
 * 사용자는 자산을 예치하고 공유 토큰(shares)을 받으며, 이를 통해 수익을 얻습니다.
 *
 * EIP-4626 defines a standard API for yield-bearing vaults.
 * Users deposit assets and receive shares representing their portion of the vault.
 */

/**
 * @dev ERC-20 인터페이스
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev ERC-4626 표준 인터페이스
 * ERC-4626 Standard Interface
 */
interface IERC4626 is IERC20 {
    // 이벤트 / Events
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // 메타데이터 / Metadata
    function asset() external view returns (address assetTokenAddress);

    // 예치/인출 / Deposit/Withdrawal Logic
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    // 회계 / Accounting Logic
    function totalAssets() external view returns (uint256 totalManagedAssets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    // 한도 / Deposit/Withdrawal Limit Logic
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);
    function maxMint(address receiver) external view returns (uint256 maxShares);
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);
    function maxRedeem(address owner) external view returns (uint256 maxShares);
}

/**
 * @title SimpleERC20
 * @dev 테스트용 간단한 ERC-20 토큰
 */
contract SimpleERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn from zero address");
        require(_balances[account] >= amount, "Burn amount exceeds balance");

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    // 테스트용 민트 함수
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title BasicERC4626Vault
 * @dev 기본적인 ERC-4626 볼트 구현
 * Basic ERC-4626 vault implementation
 */
contract BasicERC4626Vault is IERC4626 {
    // ERC-20 상태 변수
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    // 볼트 설정
    IERC20 private immutable _asset;
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;

    constructor(IERC20 asset_, string memory name_, string memory symbol_) {
        _asset = asset_;
        _name = name_;
        _symbol = symbol_;
    }

    // ============ ERC-20 메타데이터 ============

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    // ============ ERC-20 함수 ============

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // ============ ERC-4626 메타데이터 ============

    function asset() public view override returns (address) {
        return address(_asset);
    }

    // ============ ERC-4626 예치/인출 ============

    /**
     * @dev 자산을 예치하고 공유 토큰을 받음
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets <= maxDeposit(receiver), "Deposit exceeds max");

        shares = previewDeposit(assets);
        _deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @dev 공유 토큰을 받기 위해 필요한 자산을 예치
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        require(shares <= maxMint(receiver), "Mint exceeds max");

        assets = previewMint(shares);
        _deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @dev 자산을 인출하고 공유 토큰을 소각
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        returns (uint256 shares)
    {
        require(assets <= maxWithdraw(owner), "Withdraw exceeds max");

        shares = previewWithdraw(assets);
        _withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @dev 공유 토큰을 소각하고 자산을 인출
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        returns (uint256 assets)
    {
        require(shares <= maxRedeem(owner), "Redeem exceeds max");

        assets = previewRedeem(shares);
        _withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // ============ ERC-4626 회계 로직 ============

    /**
     * @dev 볼트가 관리하는 총 자산
     */
    function totalAssets() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /**
     * @dev 자산을 공유 토큰으로 변환
     */
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    /**
     * @dev 공유 토큰을 자산으로 변환
     */
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    /**
     * @dev 예치 시 받을 공유 토큰 미리보기
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return convertToShares(assets);
    }

    /**
     * @dev 민트에 필요한 자산 미리보기
     */
    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : ((shares * totalAssets()) + supply - 1) / supply;
    }

    /**
     * @dev 인출 시 소각될 공유 토큰 미리보기
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : ((assets * supply) + totalAssets() - 1) / totalAssets();
    }

    /**
     * @dev 상환 시 받을 자산 미리보기
     */
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    // ============ ERC-4626 한도 로직 ============

    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        return convertToAssets(_balances[owner]);
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    // ============ 내부 함수 ============

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
    {
        // 자산 전송
        require(_asset.transferFrom(caller, address(this), assets), "Transfer failed");

        // 공유 토큰 발행
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // 공유 토큰 소각
        _burn(owner, shares);

        // 자산 전송
        require(_asset.transfer(receiver, assets), "Transfer failed");

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        require(_balances[from] >= amount, "Insufficient balance");

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to zero");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn from zero");
        require(_balances[account] >= amount, "Burn exceeds balance");

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from zero");
        require(spender != address(0), "Approve to zero");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}

/**
 * @title YieldGeneratingVault
 * @dev 수익을 창출하는 볼트 (시뮬레이션)
 * Yield-generating vault (simulated)
 */
contract YieldGeneratingVault is BasicERC4626Vault {
    // 수익률 (basis points, 10000 = 100%)
    uint256 public annualYieldRate = 500; // 5%

    // 마지막 수익 계산 시간
    uint256 public lastYieldTime;

    // 누적 수익
    uint256 public totalYieldGenerated;

    event YieldAccrued(uint256 amount, uint256 timestamp);
    event YieldRateUpdated(uint256 newRate);

    constructor(IERC20 asset_)
        BasicERC4626Vault(asset_, "Yield Vault Shares", "yvToken")
    {
        lastYieldTime = block.timestamp;
    }

    /**
     * @dev 수익 계산 및 적용 (시뮬레이션)
     * 실제로는 DeFi 프로토콜과의 상호작용이 필요
     */
    function accrueYield() public {
        uint256 timePassed = block.timestamp - lastYieldTime;
        if (timePassed == 0) return;

        uint256 currentAssets = super.totalAssets();
        if (currentAssets == 0) return;

        // 연간 수익률을 초 단위로 계산
        uint256 yield = (currentAssets * annualYieldRate * timePassed) / (365 days * 10000);

        if (yield > 0) {
            // 실제로는 외부 프로토콜에서 수익을 얻어옴
            // 여기서는 시뮬레이션을 위해 자산 토큰을 민트
            totalYieldGenerated += yield;
            lastYieldTime = block.timestamp;

            emit YieldAccrued(yield, block.timestamp);
        }
    }

    /**
     * @dev 총 자산 (수익 포함)
     */
    function totalAssets() public view override returns (uint256) {
        uint256 baseAssets = super.totalAssets();

        // 아직 적용되지 않은 수익 계산
        uint256 timePassed = block.timestamp - lastYieldTime;
        if (timePassed == 0 || baseAssets == 0) {
            return baseAssets;
        }

        uint256 pendingYield = (baseAssets * annualYieldRate * timePassed) / (365 days * 10000);
        return baseAssets + pendingYield;
    }

    /**
     * @dev 예치 시 수익 계산
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        accrueYield();
        return super.deposit(assets, receiver);
    }

    /**
     * @dev 인출 시 수익 계산
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        returns (uint256)
    {
        accrueYield();
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @dev 수익률 변경 (관리자 전용, 실제로는 권한 제어 필요)
     */
    function setYieldRate(uint256 newRate) external {
        require(newRate <= 10000, "Rate too high");
        accrueYield();
        annualYieldRate = newRate;
        emit YieldRateUpdated(newRate);
    }
}

/**
 * @title FeeCollectingVault
 * @dev 수수료를 징수하는 볼트
 * Vault with fee collection
 */
contract FeeCollectingVault is BasicERC4626Vault {
    // 입금 수수료 (basis points)
    uint256 public depositFee = 50; // 0.5%

    // 출금 수수료 (basis points)
    uint256 public withdrawalFee = 50; // 0.5%

    // 수수료 수령자
    address public feeReceiver;

    // 누적 수수료
    uint256 public totalFeesCollected;

    event FeeCollected(address indexed from, uint256 amount, string feeType);
    event FeeUpdated(uint256 depositFee, uint256 withdrawalFee);

    constructor(IERC20 asset_, address feeReceiver_)
        BasicERC4626Vault(asset_, "Fee Vault Shares", "fvToken")
    {
        require(feeReceiver_ != address(0), "Invalid fee receiver");
        feeReceiver = feeReceiver_;
    }

    /**
     * @dev 수수료가 포함된 예치
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        // 수수료 계산
        uint256 fee = (assets * depositFee) / 10000;
        uint256 netAssets = assets - fee;

        // 수수료 전송
        if (fee > 0) {
            IERC20(asset()).transferFrom(msg.sender, feeReceiver, fee);
            totalFeesCollected += fee;
            emit FeeCollected(msg.sender, fee, "deposit");
        }

        // 순 자산으로 예치
        shares = previewDeposit(netAssets);
        _deposit(msg.sender, receiver, netAssets, shares);
    }

    /**
     * @dev 수수료가 포함된 인출
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        returns (uint256 shares)
    {
        // 수수료를 고려한 총 필요 자산
        uint256 fee = (assets * withdrawalFee) / 10000;
        uint256 totalAssets = assets + fee;

        shares = previewWithdraw(totalAssets);
        _withdraw(msg.sender, receiver, owner, totalAssets, shares);

        // 수수료 전송
        if (fee > 0) {
            IERC20(asset()).transfer(feeReceiver, fee);
            totalFeesCollected += fee;
            emit FeeCollected(owner, fee, "withdrawal");
        }
    }

    /**
     * @dev 수수료 업데이트 (관리자 전용)
     */
    function updateFees(uint256 newDepositFee, uint256 newWithdrawalFee) external {
        require(newDepositFee <= 1000, "Deposit fee too high"); // Max 10%
        require(newWithdrawalFee <= 1000, "Withdrawal fee too high"); // Max 10%

        depositFee = newDepositFee;
        withdrawalFee = newWithdrawalFee;

        emit FeeUpdated(newDepositFee, newWithdrawalFee);
    }

    /**
     * @dev 예치 미리보기 (수수료 고려)
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 fee = (assets * depositFee) / 10000;
        uint256 netAssets = assets - fee;
        return super.previewDeposit(netAssets);
    }

    /**
     * @dev 인출 미리보기 (수수료 고려)
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 fee = (assets * withdrawalFee) / 10000;
        uint256 totalAssets = assets + fee;
        return super.previewWithdraw(totalAssets);
    }
}

/**
 * @title VaultRouter
 * @dev 여러 볼트를 관리하는 라우터
 * Router for managing multiple vaults
 */
contract VaultRouter {
    event VaultDeposit(address indexed vault, address indexed user, uint256 assets, uint256 shares);
    event VaultWithdraw(address indexed vault, address indexed user, uint256 assets, uint256 shares);

    /**
     * @dev 최적의 볼트에 예치 (가장 높은 수익률)
     */
    function depositToBestVault(
        IERC4626[] calldata vaults,
        uint256 assets,
        address receiver
    ) external returns (address bestVault, uint256 shares) {
        require(vaults.length > 0, "No vaults provided");

        // 가장 많은 공유 토큰을 제공하는 볼트 찾기
        uint256 maxShares = 0;
        uint256 bestIndex = 0;

        for (uint256 i = 0; i < vaults.length; i++) {
            uint256 previewShares = vaults[i].previewDeposit(assets);
            if (previewShares > maxShares) {
                maxShares = previewShares;
                bestIndex = i;
            }
        }

        bestVault = address(vaults[bestIndex]);

        // 자산 승인 및 예치
        IERC20 asset = IERC20(vaults[bestIndex].asset());
        asset.transferFrom(msg.sender, address(this), assets);
        asset.approve(bestVault, assets);

        shares = vaults[bestIndex].deposit(assets, receiver);

        emit VaultDeposit(bestVault, receiver, assets, shares);
    }

    /**
     * @dev 여러 볼트에 분산 예치
     */
    function depositToMultipleVaults(
        IERC4626[] calldata vaults,
        uint256[] calldata amounts,
        address receiver
    ) external returns (uint256[] memory shares) {
        require(vaults.length == amounts.length, "Length mismatch");

        shares = new uint256[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            if (amounts[i] > 0) {
                IERC20 asset = IERC20(vaults[i].asset());
                asset.transferFrom(msg.sender, address(this), amounts[i]);
                asset.approve(address(vaults[i]), amounts[i]);

                shares[i] = vaults[i].deposit(amounts[i], receiver);
                emit VaultDeposit(address(vaults[i]), receiver, amounts[i], shares[i]);
            }
        }
    }

    /**
     * @dev 여러 볼트에서 일괄 인출
     */
    function withdrawFromMultipleVaults(
        IERC4626[] calldata vaults,
        uint256[] calldata sharesToRedeem,
        address receiver
    ) external returns (uint256[] memory assets) {
        require(vaults.length == sharesToRedeem.length, "Length mismatch");

        assets = new uint256[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            if (sharesToRedeem[i] > 0) {
                // 공유 토큰을 라우터로 전송
                IERC20(address(vaults[i])).transferFrom(
                    msg.sender,
                    address(this),
                    sharesToRedeem[i]
                );

                // 볼트에서 자산 인출
                assets[i] = vaults[i].redeem(sharesToRedeem[i], receiver, address(this));
                emit VaultWithdraw(address(vaults[i]), msg.sender, assets[i], sharesToRedeem[i]);
            }
        }
    }

    /**
     * @dev 볼트 간 자산 이동 (리밸런싱)
     */
    function migrateVault(
        IERC4626 fromVault,
        IERC4626 toVault,
        uint256 shares,
        address receiver
    ) external returns (uint256 newShares) {
        require(fromVault.asset() == toVault.asset(), "Asset mismatch");

        // 기존 볼트에서 공유 토큰 전송받기
        IERC20(address(fromVault)).transferFrom(msg.sender, address(this), shares);

        // 기존 볼트에서 인출
        uint256 assets = fromVault.redeem(shares, address(this), address(this));
        emit VaultWithdraw(address(fromVault), msg.sender, assets, shares);

        // 새 볼트에 예치
        IERC20 asset = IERC20(fromVault.asset());
        asset.approve(address(toVault), assets);
        newShares = toVault.deposit(assets, receiver);

        emit VaultDeposit(address(toVault), receiver, assets, newShares);
    }
}
