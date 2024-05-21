// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {IStakingRewards} from "../../interfaces/gauges/stakingrewards/IStakingRewards.sol";
import {IConverter} from "../../interfaces/gauges/stakingrewards/IConverter.sol";
import {VelodromeTimeLibrary} from "../../libraries/VelodromeTimeLibrary.sol";
import {IPool} from "../../interfaces/pools/IPool.sol";
import {Converter} from "./Converter.sol";

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
                                                                              
███████╗████████╗ █████╗ ██╗  ██╗██╗███╗   ██╗ ██████╗                        
██╔════╝╚══██╔══╝██╔══██╗██║ ██╔╝██║████╗  ██║██╔════╝                        
███████╗   ██║   ███████║█████╔╝ ██║██╔██╗ ██║██║  ███╗                       
╚════██║   ██║   ██╔══██║██╔═██╗ ██║██║╚██╗██║██║   ██║                       
███████║   ██║   ██║  ██║██║  ██╗██║██║ ╚████║╚██████╔╝                       
╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝                        

*/

/// @title Velodrome xChain Staking Rewards Contract
/// @author velodrome.finance
/// @notice Gauge contract for distribution of emissions by address
contract StakingRewards is IStakingRewards, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc IStakingRewards
    address public stakingToken;
    /// @inheritdoc IStakingRewards
    address public rewardToken;
    /// @inheritdoc IStakingRewards
    address public feeConverter;
    /// @inheritdoc IStakingRewards
    address public factory;

    uint256 internal constant WEEK = VelodromeTimeLibrary.WEEK;
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

    function initialize(address _stakingToken, address _rewardToken) public virtual {
        if (factory != address(0)) revert FactoryAlreadySet();
        factory = msg.sender;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        feeConverter = _deployFeeConverter({_stakingToken: _stakingToken, _targetToken: _rewardToken});
    }

    /// @dev Internal helper function to deploy Converter contracts
    function _deployFeeConverter(address _stakingToken, address _targetToken) internal virtual returns (address) {
        return address(
            new Converter({
                _stakingRewardsFactory: msg.sender,
                _poolFactory: IPool(_stakingToken).factory(),
                _targetToken: _targetToken
            })
        );
    }

    /// @inheritdoc IStakingRewards
    function claimFees() external nonReentrant returns (uint256, uint256) {
        if (msg.sender != feeConverter) revert NotAuthorized();
        return _claimFees();
    }

    function _claimFees() internal returns (uint256 claimed0, uint256 claimed1) {
        (claimed0, claimed1) = IPool(stakingToken).claimFees();

        (address _token0, address _token1) = IPool(stakingToken).tokens();
        if (claimed0 > 0) {
            IERC20(_token0).safeTransfer(feeConverter, claimed0);
        }
        if (claimed1 > 0) {
            IERC20(_token1).safeTransfer(feeConverter, claimed1);
        }
        emit ClaimFees(claimed0, claimed1);
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
        if (msg.sender != _account) revert NotAuthorized();

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
        if (!IStakingRewardsFactory(factory).isAlive(address(this))) revert NotAlive();

        _updateRewards(_recipient);

        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        totalSupply += _amount;
        balanceOf[_recipient] += _amount;

        emit Deposit(msg.sender, _recipient, _amount);
    }

    /// @inheritdoc IStakingRewards
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

    /// @inheritdoc IStakingRewards
    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    /// @inheritdoc IStakingRewards
    function notifyRewardMatch(uint256 _amount) external nonReentrant {
        if (msg.sender != IStakingRewardsFactory(factory).notifyAdmin()) revert NotNotifyAdmin();
        if (_amount == 0) revert ZeroAmount();
        if (block.timestamp >= periodFinish) revert PeriodFinish();
        rewardPerTokenStored = rewardPerToken();

        uint256 _remaining = periodFinish - block.timestamp;
        uint256 _leftover = _remaining * rewardRate;
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
        rewardRate = (_amount + _leftover) / _remaining;

        rewardRateByEpoch[VelodromeTimeLibrary.epochStart(block.timestamp)] = rewardRate;
        if (rewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > balance / _remaining) revert RewardRateTooHigh();

        lastUpdateTime = block.timestamp;
        emit NotifyReward(msg.sender, _amount);
    }

    /// @inheritdoc IStakingRewards
    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        _notifyRewardAmount(_amount);
    }

    function _notifyRewardAmount(uint256 _amount) internal {
        rewardPerTokenStored = rewardPerToken();

        if (block.timestamp >= periodFinish) {
            IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
            /// @dev Include any converted Fees from the Converter
            _amount += IConverter(feeConverter).compound();
            rewardRate = _amount / WEEK;
        } else {
            uint256 _remaining = periodFinish - block.timestamp;
            uint256 _leftover = _remaining * rewardRate;
            if (_amount < _leftover) revert InsufficientAmount();
            IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
            /// @dev Include any converted Fees from the Converter
            _amount += IConverter(feeConverter).compound();
            rewardRate = (_amount + _leftover) / WEEK;
        }
        rewardRateByEpoch[VelodromeTimeLibrary.epochStart(block.timestamp)] = rewardRate;
        if (rewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > balance / WEEK) revert RewardRateTooHigh();

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + WEEK;
        emit NotifyReward(msg.sender, _amount);
    }
}
