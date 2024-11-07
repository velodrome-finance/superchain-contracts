// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Math} from "@openzeppelin5/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin5/contracts/utils/ReentrancyGuard.sol";

import {IReward} from "../interfaces/rewards/IReward.sol";
import {ILeafGauge} from "../interfaces/gauges/ILeafGauge.sol";
import {IPool} from "../interfaces/pools/IPool.sol";
import {ILeafVoter} from "../interfaces/voter/ILeafVoter.sol";
import {VelodromeTimeLibrary} from "../libraries/VelodromeTimeLibrary.sol";

import {ILeafMessageBridge} from "../interfaces/bridge/ILeafMessageBridge.sol";

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

██╗     ███████╗ █████╗ ███████╗ ██████╗  █████╗ ██╗   ██╗ ██████╗ ███████╗
██║     ██╔════╝██╔══██╗██╔════╝██╔════╝ ██╔══██╗██║   ██║██╔════╝ ██╔════╝
██║     █████╗  ███████║█████╗  ██║  ███╗███████║██║   ██║██║  ███╗█████╗
██║     ██╔══╝  ██╔══██║██╔══╝  ██║   ██║██╔══██║██║   ██║██║   ██║██╔══╝
███████╗███████╗██║  ██║██║     ╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝███████╗
╚══════╝╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝

*/

/// @title Velodrome Superchain Leaf Gauge Contracts
/// @notice Leaf gauge contract for distribution of emissions by address
contract LeafGauge is ILeafGauge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc ILeafGauge
    address public immutable stakingToken;
    /// @inheritdoc ILeafGauge
    address public immutable rewardToken;
    /// @inheritdoc ILeafGauge
    address public immutable feesVotingReward;
    /// @inheritdoc ILeafGauge
    address public immutable voter;
    /// @inheritdoc ILeafGauge
    address public immutable bridge;

    /// @inheritdoc ILeafGauge
    bool public immutable isPool;

    uint256 internal constant WEEK = VelodromeTimeLibrary.WEEK; // rewards are released over 7 days
    uint256 internal constant PRECISION = 10 ** 18;

    /// @inheritdoc ILeafGauge
    uint256 public periodFinish;
    /// @inheritdoc ILeafGauge
    uint256 public rewardRate;
    /// @inheritdoc ILeafGauge
    uint256 public lastUpdateTime;
    /// @inheritdoc ILeafGauge
    uint256 public rewardPerTokenStored;
    /// @inheritdoc ILeafGauge
    uint256 public totalSupply;
    /// @inheritdoc ILeafGauge
    mapping(address => uint256) public balanceOf;
    /// @inheritdoc ILeafGauge
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @inheritdoc ILeafGauge
    mapping(address => uint256) public rewards;
    /// @inheritdoc ILeafGauge
    mapping(uint256 => uint256) public rewardRateByEpoch;

    /// @inheritdoc ILeafGauge
    uint256 public fees0;
    /// @inheritdoc ILeafGauge
    uint256 public fees1;

    constructor(
        address _stakingToken,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _bridge,
        bool _isPool
    ) {
        stakingToken = _stakingToken;
        feesVotingReward = _feesVotingReward;
        rewardToken = _rewardToken;
        voter = _voter;
        bridge = _bridge;
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
            if (_fees0 > WEEK) {
                fees0 = 0;
                IERC20(_token0).safeIncreaseAllowance(feesVotingReward, _fees0);
                IReward(feesVotingReward).notifyRewardAmount(_token0, _fees0);
            } else {
                fees0 = _fees0;
            }
            if (_fees1 > WEEK) {
                fees1 = 0;
                IERC20(_token1).safeIncreaseAllowance(feesVotingReward, _fees1);
                IReward(feesVotingReward).notifyRewardAmount(_token1, _fees1);
            } else {
                fees1 = _fees1;
            }

            emit ClaimFees(msg.sender, claimed0, claimed1);
        }
    }

    /// @inheritdoc ILeafGauge
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) / totalSupply;
    }

    /// @inheritdoc ILeafGauge
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /// @inheritdoc ILeafGauge
    function getReward(address _account) external nonReentrant {
        if (msg.sender != _account && msg.sender != voter) revert NotAuthorized();

        _updateRewards(_account);

        uint256 reward = rewards[_account];
        if (reward > 0) {
            rewards[_account] = 0;
            IERC20(rewardToken).safeTransfer(_account, reward);
            emit ClaimRewards(_account, reward);
        }
    }

    /// @inheritdoc ILeafGauge
    function earned(address _account) public view returns (uint256) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / PRECISION
            + rewards[_account];
    }

    /// @inheritdoc ILeafGauge
    function deposit(uint256 _amount) external {
        _depositFor(_amount, msg.sender);
    }

    /// @inheritdoc ILeafGauge
    function deposit(uint256 _amount, address _recipient) external {
        _depositFor(_amount, _recipient);
    }

    function _depositFor(uint256 _amount, address _recipient) internal nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (!ILeafVoter(voter).isAlive(address(this))) revert NotAlive();

        _updateRewards(_recipient);

        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        totalSupply += _amount;
        balanceOf[_recipient] += _amount;

        emit Deposit(msg.sender, _recipient, _amount);
    }

    /// @inheritdoc ILeafGauge
    function withdraw(uint256 _amount) external nonReentrant {
        _updateRewards(msg.sender);

        totalSupply -= _amount;
        balanceOf[msg.sender] -= _amount;
        IERC20(stakingToken).safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function _updateRewards(address _account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    /// @inheritdoc ILeafGauge
    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    /// @inheritdoc ILeafGauge
    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        if (msg.sender != ILeafMessageBridge(bridge).module()) revert NotModule();
        if (_amount == 0) revert ZeroAmount();
        _claimFees();
        _notifyRewardAmount(_amount);
    }

    /// @inheritdoc ILeafGauge
    function notifyRewardWithoutClaim(uint256 _amount) external nonReentrant {
        if (msg.sender != ILeafMessageBridge(bridge).module()) revert NotModule();
        if (_amount == 0) revert ZeroAmount();
        _notifyRewardAmount(_amount);
    }

    function _notifyRewardAmount(uint256 _amount) internal {
        rewardPerTokenStored = rewardPerToken();
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;

        if (block.timestamp >= periodFinish) {
            IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
            rewardRate = _amount / timeUntilNext;
        } else {
            uint256 _remaining = periodFinish - block.timestamp;
            uint256 _leftover = _remaining * rewardRate;
            IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
            rewardRate = (_amount + _leftover) / timeUntilNext;
        }
        rewardRateByEpoch[VelodromeTimeLibrary.epochStart(block.timestamp)] = rewardRate;
        if (rewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > balance / timeUntilNext) revert RewardRateTooHigh();

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + timeUntilNext;
        emit NotifyReward(msg.sender, _amount);
    }
}
