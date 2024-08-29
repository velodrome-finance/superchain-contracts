// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IMessageBridge} from "../../interfaces/bridge/IMessageBridge.sol";
import {IRootGauge} from "../../interfaces/mainnet/gauges/IRootGauge.sol";
import {IRootFeesVotingReward} from "../../interfaces/mainnet/rewards/IRootFeesVotingReward.sol";

import {Commands} from "../../libraries/Commands.sol";

contract RootFeesVotingReward is IRootFeesVotingReward {
    /// @inheritdoc IRootFeesVotingReward
    address public immutable bridge;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable voter;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable bribeVotingReward;
    /// @inheritdoc IRootFeesVotingReward
    address public gauge;
    /// @inheritdoc IRootFeesVotingReward
    uint256 public chainid;

    constructor(address _bridge, address _voter, address _bribeVotingReward, address[] memory _rewards) {
        voter = _voter;
        bridge = _bridge;
        bribeVotingReward = _bribeVotingReward;
    }

    /// @inheritdoc IRootFeesVotingReward
    function initialize(address _gauge) external {
        if (gauge != address(0)) revert AlreadyInitialized();
        gauge = _gauge;
        chainid = IRootGauge(_gauge).chainid();
    }

    /// @inheritdoc IRootFeesVotingReward
    function _deposit(uint256 _amount, uint256 _tokenId) external {
        if (msg.sender != voter) revert NotAuthorized();

        bytes memory payload = abi.encode(_amount, _tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(gauge, payload));

        IMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootFeesVotingReward
    function _withdraw(uint256 _amount, uint256 _tokenId) external {
        if (msg.sender != voter) revert NotAuthorized();

        bytes memory payload = abi.encode(_amount, _tokenId);
        bytes memory message = abi.encode(Commands.WITHDRAW, abi.encode(gauge, payload));

        IMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }
}
