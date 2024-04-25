// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IReward} from "../../interfaces/IReward.sol";
import {IStakingRewards} from "../../interfaces/gauges/stakingrewards/IStakingRewards.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VelodromeTimeLibrary} from "../../libraries/VelodromeTimeLibrary.sol";

/// @title Velodrome xChain Staking Rewards Contract
/// @author velodrome.finance
/// @notice Gauge contract for distribution of emissions by address
contract StakingRewards is IStakingRewards, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc IStakingRewards
    address public immutable stakingToken;
    /// @inheritdoc IStakingRewards
    address public immutable rewardToken;
    /// @inheritdoc IStakingRewards
    address public immutable feesVotingReward;

    /// @inheritdoc IStakingRewards
    bool public immutable isPool;

    uint256 internal constant DURATION = 7 days; // rewards are released over 7 days
    uint256 internal constant PRECISION = 10 ** 18;

    /// @inheritdoc IStakingRewards
    uint256 public periodFinish;
    /// @inheritdoc IStakingRewards
    uint256 public rewardRate;
    /// @inheritdoc IStakingRewards
    uint256 public lastUpdateTime;
    /// @inheritdoc IStakingRewards
    uint256 public rewardPerTokenStored;
    /// @inheritdoc IStakingRewards
    uint256 public totalSupply;
    /// @inheritdoc IStakingRewards
    mapping(address => uint256) public balanceOf;
    /// @inheritdoc IStakingRewards
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @inheritdoc IStakingRewards
    mapping(address => uint256) public rewards;
    /// @inheritdoc IStakingRewards
    mapping(uint256 => uint256) public rewardRateByEpoch;

    /// @inheritdoc IStakingRewards
    uint256 public fees0;
    /// @inheritdoc IStakingRewards
    uint256 public fees1;

    constructor(address _stakingToken, address _feesVotingReward, address _rewardToken, bool _isPool) {
        stakingToken = _stakingToken;
        feesVotingReward = _feesVotingReward;
        rewardToken = _rewardToken;
        isPool = _isPool;
    }

    function _claimFees() internal returns (uint256 claimed0, uint256 claimed1) {
        if (!isPool) {
            return (0, 0);
        }
        (claimed0, claimed1) = IPool(stakingToken).claimFees();
        if (claimed0 > 0 || claimed1 > 0) {
            uint256 _fees0 = fees0 + claimed0;
            uint256 _fees1 = fees1 + claimed1;
            (address _token0, address _token1) = IPool(stakingToken).tokens();
            if (_fees0 > DURATION) {
                fees0 = 0;
                IERC20(_token0).safeIncreaseAllowance(feesVotingReward, _fees0);
                IReward(feesVotingReward).notifyRewardAmount(_token0, _fees0);
            } else {
                fees0 = _fees0;
            }
            if (_fees1 > DURATION) {
                fees1 = 0;
                IERC20(_token1).safeIncreaseAllowance(feesVotingReward, _fees1);
                IReward(feesVotingReward).notifyRewardAmount(_token1, _fees1);
            } else {
                fees1 = _fees1;
            }

            emit ClaimFees(msg.sender, claimed0, claimed1);
        }
    }

    /// @inheritdoc IStakingRewards
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) / totalSupply;
    }

    /// @inheritdoc IStakingRewards
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /// @inheritdoc IStakingRewards
    function getReward(address _account) external nonReentrant {
        address sender = msg.sender;
        if (sender != _account) revert NotAuthorized();

        _updateRewards(_account);

        uint256 reward = rewards[_account];
        if (reward > 0) {
            rewards[_account] = 0;
            IERC20(rewardToken).safeTransfer(_account, reward);
            emit ClaimRewards(_account, reward);
        }
    }

    /// @inheritdoc IStakingRewards
    function earned(address _account) public view returns (uint256) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / PRECISION
            + rewards[_account];
    }

    /// @inheritdoc IStakingRewards
    function deposit(uint256 _amount) external {
        _depositFor(_amount, msg.sender);
    }

    /// @inheritdoc IStakingRewards
    function deposit(uint256 _amount, address _recipient) external {
        _depositFor(_amount, _recipient);
    }

    function _depositFor(uint256 _amount, address _recipient) internal nonReentrant {
        if (_amount == 0) revert ZeroAmount();

        address sender = msg.sender;
        _updateRewards(_recipient);

        IERC20(stakingToken).safeTransferFrom(sender, address(this), _amount);
        totalSupply += _amount;
        balanceOf[_recipient] += _amount;

        emit Deposit(sender, _recipient, _amount);
    }

    /// @inheritdoc IStakingRewards
    function withdraw(uint256 _amount) external nonReentrant {
        address sender = msg.sender;

        _updateRewards(sender);

        totalSupply -= _amount;
        balanceOf[sender] -= _amount;
        IERC20(stakingToken).safeTransfer(sender, _amount);

        emit Withdraw(sender, _amount);
    }

    function _updateRewards(address _account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    /// @inheritdoc IStakingRewards
    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    /// @inheritdoc IStakingRewards
    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        address sender = msg.sender;
        if (_amount == 0) revert ZeroAmount();
        _claimFees();
        _notifyRewardAmount(sender, _amount);
    }

    function _notifyRewardAmount(address sender, uint256 _amount) internal {
        rewardPerTokenStored = rewardPerToken();
        uint256 timestamp = block.timestamp;
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(timestamp) - timestamp;

        if (timestamp >= periodFinish) {
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = _amount / timeUntilNext;
        } else {
            uint256 _remaining = periodFinish - timestamp;
            uint256 _leftover = _remaining * rewardRate;
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = (_amount + _leftover) / timeUntilNext;
        }
        rewardRateByEpoch[VelodromeTimeLibrary.epochStart(timestamp)] = rewardRate;
        if (rewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > balance / timeUntilNext) revert RewardRateTooHigh();

        lastUpdateTime = timestamp;
        periodFinish = timestamp + timeUntilNext;
        emit NotifyReward(sender, _amount);
    }
}
