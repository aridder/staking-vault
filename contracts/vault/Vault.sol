// SPDX-License-Identifier: UNLICENSED
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity ^0.8.9;

interface IVault {
    function deposit(uint256 amount) external;

    function withdraw(uint amount) external;

    function withdrawAll() external;

    function claimRewards() external;

    function rewardOf(address user) external view returns (uint);

    function totalDeposited() external view returns (uint);

    function amountStaked(address stakeHolder) external view returns (uint);

    function startStaking() external;

    event Deposit(address indexed owner, uint amount);

    event StartStaking(uint startPeriod, uint lockupPeriod);

    event Withdraw(address indexed owner, uint amount);

    event Claim(address indexed stakeHolder, uint amount);
}

contract Vault is IVault, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

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
        uint _lockDurationInDays
    ) {
        stakingDuration = _durationInDays * 1 days;
        lockupDuration = _lockDurationInDays * 1 days;
        token = IERC20(_token);
        fixedAPY = _fixedAPY;
    }

    function deposit(uint256 amount) external override {
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

        _updateRewards();
        if (_rewardsToClaim[_msgSender()] > 0) {
            _claimRewards();
        }
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

        _updateRewards();
        if (_rewardsToClaim[_msgSender()] > 0) {
            _claimRewards();
        }

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
