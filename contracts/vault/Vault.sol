// SPDX-License-Identifier: UNLICENSED
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity ^0.8.9;

interface IAngleVault {
    function deposit(
        address _staker,
        uint256 _amount,
        bool _earn
    ) external;

    function withdraw(uint256 _shares) external;

    function withdrawAll() external;
}

interface IVault {
    // Functions for interacting with underlying vault

    function depositToVault() external;

    function withdrawAllFundsfromVault() external;

    // Function for vault

    function deposit(uint256 amount) external;

    function withdraw(uint amount) external;

    function withdrawAll() external;

    function claimRewards() external;

    function rewardOf(address user) external view returns (uint);

    function totalDeposited() external view returns (uint);

    function amountStaked(address stakeHolder) external view returns (uint);

    function startStaking() external;

    function rescueERC20(
        address _token,
        uint256 _amount,
        address _recipient
    ) external;

    event Deposit(address indexed owner, uint amount);

    event StartStaking(uint startPeriod, uint lockupPeriod);

    event Withdraw(address indexed owner, uint amount);

    event Claim(address indexed stakeHolder, uint amount);

    event ERC20Rescued(address token, uint _amount);
}

contract Vault is IVault, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    IAngleVault vault;
    uint private _totalVaultDeposit;
    bool private vaultOpenForDeposits = true;

    uint8 public immutable fixedAPY;

    uint public immutable stakingDuration;
    uint public immutable lockupDuration;

    uint public startPeriod;
    uint public lockupPeriod;

    uint private _totalStaked;

    mapping(address => uint) public staked;
    mapping(address => uint) private _rewardsToClaim;
    mapping(address => uint) private _userStartTime;

    constructor(
        address _token,
        uint8 _fixedAPY,
        uint _durationInDays,
        uint _lockDurationInDays,
        address _vault
    ) {
        stakingDuration = _durationInDays * 1 days;
        lockupDuration = _lockDurationInDays * 1 days;
        token = IERC20(_token);
        fixedAPY = _fixedAPY;
        vault = IAngleVault(_vault);
    }

    modifier openForDeposits() {
        require(vaultOpenForDeposits, "Vault is closed for deposits");
        _;
    }

    function depositToVault() public onlyOwner {
        require(_totalStaked > 0, "vault is empty");
        vault.deposit(address(this), _totalStaked, true);
    }

    function withdrawAllFundsfromVault() public onlyOwner {
        vault.withdrawAll();
    }

    /// @notice A function that rescue any ERC20 token
    /// @param _token token address
    /// @param _amount amount to rescue
    /// @param _recipient address to send token rescued
    function rescueERC20(
        address _token,
        uint256 _amount,
        address _recipient
    ) external onlyOwner {
        require(_amount > 0, "set an amount > 0");
        require(_recipient != address(0), "can't be zero address");
        IERC20(_token).safeTransfer(_recipient, _amount);
        emit ERC20Rescued(_token, _amount);
    }

    function deposit(uint256 amount) external override openForDeposits {
        require(amount > 0, "Amount must be greater than 0");

        if (_userStartTime[_msgSender()] == 0) {
            _userStartTime[_msgSender()] = block.timestamp;
        }

        _updateRewards();

        staked[_msgSender()] += amount;
        _totalStaked += amount;
        token.safeTransferFrom(_msgSender(), address(this), amount);
        emit Deposit(_msgSender(), amount);
    }

    function _updateRewards() private {
        _rewardsToClaim[_msgSender()] = _calculateRewards(_msgSender());
        _userStartTime[_msgSender()] = block.timestamp;
    }

    function withdraw(uint amount) external override {
        require(
            block.timestamp >= lockupPeriod,
            "No withdraw until lockup ends"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(
            amount <= staked[_msgSender()],
            "Amount higher than stakedAmount"
        );

        _claimRewards();
        _totalStaked -= amount;
        staked[_msgSender()] -= amount;
        token.safeTransfer(_msgSender(), amount);

        emit Withdraw(_msgSender(), amount);
    }

    function withdrawAll() external override {
        require(
            block.timestamp >= lockupPeriod,
            "No withdraw until lockup ends"
        );

        _claimRewards();
        _userStartTime[_msgSender()] = 0;
        _totalStaked -= staked[_msgSender()];
        uint stakedBalance = staked[_msgSender()];
        staked[_msgSender()] = 0;
        token.safeTransfer(_msgSender(), stakedBalance);

        emit Withdraw(_msgSender(), stakedBalance);
    }

    function claimRewards() external override {
        _claimRewards();
    }

    function rewardOf(address user) external view override returns (uint) {
        return _calculateRewards(user);
    }

    function amountStaked(address stakeHolder)
        external
        view
        override
        returns (uint)
    {
        return staked[stakeHolder];
    }

    function totalDeposited() external view override returns (uint) {
        return _totalStaked;
    }

    function startStaking() external override onlyOwner {
        require(startPeriod == 0, "Staking has already started");
        vaultOpenForDeposits = false;
        depositToVault();
        startPeriod = block.timestamp;
        lockupPeriod = block.timestamp + lockupDuration;
        emit StartStaking(startPeriod, lockupDuration);
    }

    function _calculateRewards(address stakeHolder)
        internal
        view
        returns (uint)
    {
        if (startPeriod == 0 || staked[stakeHolder] == 0) {
            return 0;
        }

        bool early = startPeriod > _userStartTime[stakeHolder];

        uint stakingTime = early
            ? block.timestamp - startPeriod
            : block.timestamp - _userStartTime[stakeHolder];

        return
            (((100 * stakingTime) / 365 days) *
                staked[stakeHolder] *
                fixedAPY) / 100000;
    }

    function _claimRewards() private {
        _updateRewards();

        uint rewardsToClaim = _rewardsToClaim[_msgSender()];
        require(rewardsToClaim > 0, "Nothing to claim");

        _rewardsToClaim[_msgSender()] = 0;
        token.safeTransfer(_msgSender(), rewardsToClaim);
        emit Claim(_msgSender(), rewardsToClaim);
    }
}
