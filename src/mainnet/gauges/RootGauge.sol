// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRootGaugeFactory} from "../../interfaces/mainnet/gauges/IRootGaugeFactory.sol";
import {IRootGauge} from "../../interfaces/mainnet/gauges/IRootGauge.sol";
import {IXERC20Lockbox} from "../../interfaces/xerc20/IXERC20Lockbox.sol";
import {IRootMessageBridge} from "../../interfaces/mainnet/bridge/IRootMessageBridge.sol";
import {Commands} from "../../libraries/Commands.sol";

import {VelodromeTimeLibrary} from "../../libraries/VelodromeTimeLibrary.sol";
import {Commands} from "../../libraries/Commands.sol";

/// @notice RootGauge that forward emissions to the corresponding LeafGauge on the leaf chain
contract RootGauge is IRootGauge {
    using SafeERC20 for IERC20;

    /// @inheritdoc IRootGauge
    address public immutable gaugeFactory;
    /// @inheritdoc IRootGauge
    address public immutable rewardToken;
    /// @inheritdoc IRootGauge
    address public immutable xerc20;
    /// @inheritdoc IRootGauge
    address public immutable voter;
    /// @inheritdoc IRootGauge
    address public immutable lockbox;
    /// @inheritdoc IRootGauge
    address public immutable bridge;
    /// @inheritdoc IRootGauge
    uint256 public immutable chainid;

    constructor(
        address _gaugeFactory,
        address _rewardToken,
        address _xerc20,
        address _lockbox,
        address _bridge,
        uint256 _chainid
    ) {
        gaugeFactory = _gaugeFactory;
        rewardToken = _rewardToken;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        bridge = _bridge;
        chainid = _chainid;
        voter = IRootMessageBridge(_bridge).voter();
    }

    /// @inheritdoc IRootGauge
    function left() external pure returns (uint256) {
        /// Can safely be set to 0 as only checked by distribute()
        /// Distribute only callable once per epoch for a gauge
        /// & gauge distributes full reward to end of epoch (i.e. no overlap b/w epochs)
        /// if claimable != 0, left() will always be zero
        return 0;
    }

    /// @inheritdoc IRootGauge
    function notifyRewardAmount(uint256 _amount) external {
        if (msg.sender != voter) revert NotVoter();
        _notify({_command: Commands.NOTIFY, _amount: _amount});
    }

    /// @inheritdoc IRootGauge
    function notifyRewardWithoutClaim(uint256 _amount) external {
        if (msg.sender != IRootGaugeFactory(gaugeFactory).notifyAdmin()) revert NotAuthorized();
        _notify({_command: Commands.NOTIFY_WITHOUT_CLAIM, _amount: _amount});
    }

    function _notify(uint256 _command, uint256 _amount) internal {
        if (_amount < VelodromeTimeLibrary.WEEK) revert ZeroRewardRate();

        IERC20(rewardToken).transferFrom(msg.sender, address(this), _amount);

        IERC20(rewardToken).safeIncreaseAllowance({spender: lockbox, value: _amount});
        IXERC20Lockbox(lockbox).deposit({_amount: _amount});

        IERC20(xerc20).safeIncreaseAllowance({spender: bridge, value: _amount});

        bytes memory payload = abi.encode(address(this), _amount);
        bytes memory message = abi.encode(_command, payload);
        IRootMessageBridge(bridge).sendMessage({_chainid: uint32(chainid), _message: message});

        emit NotifyReward({_sender: msg.sender, _amount: _amount});
    }
}
