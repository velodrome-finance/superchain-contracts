// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Math} from "@openzeppelin5/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin5/contracts/utils/ReentrancyGuard.sol";

import {IReward} from "../interfaces/rewards/IReward.sol";
import {ILeafMessageBridge} from "../interfaces/bridge/ILeafMessageBridge.sol";

import {VelodromeTimeLibrary} from "../libraries/VelodromeTimeLibrary.sol";

/// @title Base Superchain Rewards Contract
/// @notice Base reward contract for distribution of rewards
abstract contract Reward is IReward, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc IReward
    uint256 public constant DURATION = 7 days;

    /// @inheritdoc IReward
    address public immutable voter;
    /// @inheritdoc IReward
    address public immutable authorized;

    /// @inheritdoc IReward
    uint256 public totalSupply;
    /// @inheritdoc IReward
    mapping(uint256 => uint256) public balanceOf;
    /// @inheritdoc IReward
    mapping(address => mapping(uint256 => uint256)) public tokenRewardsPerEpoch;
    /// @inheritdoc IReward
    mapping(address => mapping(uint256 => uint256)) public lastEarn;

    /// @inheritdoc IReward
    address[] public rewards;
    /// @inheritdoc IReward
    mapping(address => bool) public isReward;

    /// @notice A record of balance checkpoints for each account, by index
    mapping(uint256 => mapping(uint256 => Checkpoint)) public checkpoints;
    /// @inheritdoc IReward
    mapping(uint256 => uint256) public numCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping(uint256 => SupplyCheckpoint) public supplyCheckpoints;
    /// @inheritdoc IReward
    uint256 public supplyNumCheckpoints;

    /// @inheritdoc IReward
    function getPriorBalanceIndex(uint256 tokenId, uint256 timestamp) public view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[tokenId];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[tokenId][nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (checkpoints[tokenId][0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[tokenId][center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    /// @inheritdoc IReward
    function getPriorSupplyIndex(uint256 timestamp) public view returns (uint256) {
        uint256 nCheckpoints = supplyNumCheckpoints;
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (supplyCheckpoints[nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (supplyCheckpoints[0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            SupplyCheckpoint memory cp = supplyCheckpoints[center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    function _writeCheckpoint(uint256 tokenId, uint256 balance) internal {
        uint256 _nCheckPoints = numCheckpoints[tokenId];
        uint256 _timestamp = block.timestamp;

        if (
            _nCheckPoints > 0
                && VelodromeTimeLibrary.epochStart(checkpoints[tokenId][_nCheckPoints - 1].timestamp)
                    == VelodromeTimeLibrary.epochStart(_timestamp)
        ) {
            checkpoints[tokenId][_nCheckPoints - 1] = Checkpoint(_timestamp, balance);
        } else {
            checkpoints[tokenId][_nCheckPoints] = Checkpoint(_timestamp, balance);
            numCheckpoints[tokenId] = _nCheckPoints + 1;
        }
    }

    function _writeSupplyCheckpoint() internal {
        uint256 _nCheckPoints = supplyNumCheckpoints;
        uint256 _timestamp = block.timestamp;

        if (
            _nCheckPoints > 0
                && VelodromeTimeLibrary.epochStart(supplyCheckpoints[_nCheckPoints - 1].timestamp)
                    == VelodromeTimeLibrary.epochStart(_timestamp)
        ) {
            supplyCheckpoints[_nCheckPoints - 1] = SupplyCheckpoint(_timestamp, totalSupply);
        } else {
            supplyCheckpoints[_nCheckPoints] = SupplyCheckpoint(_timestamp, totalSupply);
            supplyNumCheckpoints = _nCheckPoints + 1;
        }
    }

    /// @inheritdoc IReward
    function rewardsListLength() external view returns (uint256) {
        return rewards.length;
    }

    /// @inheritdoc IReward
    function earned(address token, uint256 tokenId) public view returns (uint256) {
        if (numCheckpoints[tokenId] == 0) {
            return 0;
        }

        uint256 reward = 0;
        uint256 _supply = 1;
        uint256 _currTs = VelodromeTimeLibrary.epochStart(lastEarn[token][tokenId]); // take epoch last claimed in as starting point
        uint256 _index = getPriorBalanceIndex(tokenId, _currTs);
        Checkpoint memory cp0 = checkpoints[tokenId][_index];

        // accounts for case where lastEarn is before first checkpoint
        _currTs = Math.max(_currTs, VelodromeTimeLibrary.epochStart(cp0.timestamp));

        // get epochs between current epoch and first checkpoint in same epoch as last claim
        uint256 numEpochs = (VelodromeTimeLibrary.epochStart(block.timestamp) - _currTs) / DURATION;

        if (numEpochs > 0) {
            for (uint256 i = 0; i < numEpochs; i++) {
                // get index of last checkpoint in this epoch
                _index = getPriorBalanceIndex(tokenId, _currTs + DURATION - 1);
                // get checkpoint in this epoch
                cp0 = checkpoints[tokenId][_index];
                // get supply of last checkpoint in this epoch
                _supply = Math.max(supplyCheckpoints[getPriorSupplyIndex(_currTs + DURATION - 1)].supply, 1);
                reward += (cp0.balanceOf * tokenRewardsPerEpoch[token][_currTs]) / _supply;
                _currTs += DURATION;
            }
        }

        return reward;
    }

    /// @inheritdoc IReward
    function _deposit(bytes calldata _payload) external nonReentrant {
        if (msg.sender != ILeafMessageBridge(authorized).module()) revert NotAuthorized();
        (uint256 amount, uint256 tokenId) = abi.decode(_payload, (uint256, uint256));

        totalSupply += amount;
        balanceOf[tokenId] += amount;

        _writeCheckpoint(tokenId, balanceOf[tokenId]);
        _writeSupplyCheckpoint();

        emit Deposit(tokenId, amount);
    }

    /// @inheritdoc IReward
    function _withdraw(bytes calldata _payload) external nonReentrant {
        if (msg.sender != ILeafMessageBridge(authorized).module()) revert NotAuthorized();
        (uint256 amount, uint256 tokenId) = abi.decode(_payload, (uint256, uint256));

        totalSupply -= amount;
        balanceOf[tokenId] -= amount;

        _writeCheckpoint(tokenId, balanceOf[tokenId]);
        _writeSupplyCheckpoint();

        emit Withdraw(tokenId, amount);
    }

    /// @inheritdoc IReward
    function getReward(address _recipient, uint256 _tokenId, address[] memory _tokens) external virtual nonReentrant {}

    /// @dev used with all getReward implementations
    function _getReward(address _recipient, uint256 _tokenId, address[] memory _tokens) internal {
        uint256 _length = _tokens.length;
        for (uint256 i = 0; i < _length; i++) {
            uint256 _reward = earned(_tokens[i], _tokenId);
            lastEarn[_tokens[i]][_tokenId] = block.timestamp;
            if (_reward > 0) IERC20(_tokens[i]).safeTransfer(_recipient, _reward);

            emit ClaimRewards(_recipient, _tokens[i], _reward);
        }
    }

    /// @inheritdoc IReward
    function notifyRewardAmount(address token, uint256 amount) external virtual nonReentrant {}

    /// @dev used within all notifyRewardAmount implementations
    function _notifyRewardAmount(address sender, address token, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransferFrom(sender, address(this), amount);

        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        tokenRewardsPerEpoch[token][epochStart] += amount;

        emit NotifyReward(sender, token, epochStart, amount);
    }
}
