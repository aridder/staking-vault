// SPDX-License-Identifier: UNLICENSED
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity ^0.8.9;

interface IVault {
    function deposit(uint256 amount) external;

    function withdraw() external;

    function claimRewards() external;

    function rewardOf(address user) external view;

    function totalDeposited() external view;

    function startStaking() external;

    event Deposit(address indexed owner, uint amount);

    event StartStaking(uint startPeriod, uint lockupPeriod, uint endingPeriod);

    event Withdraw(address indexed owner, uint amount);

    event Claim(address indexed stakeHolder, uint amount);
}

contract Vault is IVault, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    uint8 public immutable fixedAPY;

    uint public immutable stakingDuration;
    uint public immutable lockupDuration;
    uint public immutable stakingMax;

    uint public startPeriod;
    uint public lockupPeriod;
    uint public endPeriod;

    uint private _totalStaked;
    uint internal _precision = 1E6;

    mapping(address => uint) public staked;
    mapping(address => uint) private _rewardsToClaim;
    mapping(address => uint) private _userStartTime;

    constructor(
        address _token,
        uint8 _fixedAPY,
        uint _durationInDays,
        uint _lockDurationInDays,
        uint _maxAmountStaked
    ) {
        stakingDuration = _durationInDays * 1 days;
        lockupDuration = _lockDurationInDays * 1 days;
        token = IERC20(_token);
        fixedAPY = _fixedAPY;
        stakingMax = _maxAmountStaked;
    }

    function deposit(uint256 amount) external override {}

    function withdraw() external override {}

    function claimRewards() external override {}

    function rewardOf(address user) external view override {}

    function totalDeposited() external view override {}

    function startStaking() external override {}
}
