// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRootGauge} from "../../interfaces/mainnet/gauges/IRootGauge.sol";
import {IXERC20Lockbox} from "../../interfaces/xerc20/IXERC20Lockbox.sol";
import {IBridge} from "../../interfaces/bridge/IBridge.sol";

/// @notice RootGauge that forward emissions to the corresponding LeafGauge on the leaf chain
contract RootGauge is IRootGauge {
    using SafeERC20 for IERC20;

    /// @inheritdoc IRootGauge
    address public immutable rewardToken;
    /// @inheritdoc IRootGauge
    address public immutable xerc20;
    /// @inheritdoc IRootGauge
    address public immutable lockbox;
    /// @inheritdoc IRootGauge
    address public immutable bridge;
    /// @inheritdoc IRootGauge
    uint256 public immutable chainid;

    constructor(address _rewardToken, address _xerc20, address _lockbox, address _bridge, uint256 _chainid) {
        rewardToken = _rewardToken;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        bridge = _bridge;
        chainid = _chainid;
    }

    /// @inheritdoc IRootGauge
    function left() external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IRootGauge
    function notifyRewardAmount(uint256 _amount) external {
        IERC20(rewardToken).transferFrom(msg.sender, address(this), _amount);

        IERC20(rewardToken).safeIncreaseAllowance({spender: lockbox, value: _amount});
        IXERC20Lockbox(lockbox).deposit({_amount: _amount});

        IERC20(xerc20).safeIncreaseAllowance({spender: bridge, value: _amount});
        IBridge(bridge).sendToken({_amount: _amount, _chainid: uint32(chainid)});

        emit NotifyReward({_sender: msg.sender, _amount: _amount});
    }
}
