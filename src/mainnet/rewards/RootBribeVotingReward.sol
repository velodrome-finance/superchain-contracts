// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootBribeVotingReward} from "../../interfaces/mainnet/rewards/IRootBribeVotingReward.sol";
import {IRootGauge} from "../../interfaces/mainnet/gauges/IRootGauge.sol";
import {IVotingEscrow} from "../../interfaces/external/IVotingEscrow.sol";
import {IMessageBridge} from "../../interfaces/bridge/IMessageBridge.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";

import {Commands} from "../../libraries/Commands.sol";

contract RootBribeVotingReward is IRootBribeVotingReward {
    /// @inheritdoc IRootBribeVotingReward
    address public immutable bridge;
    /// @inheritdoc IRootBribeVotingReward
    address public immutable voter;
    /// @inheritdoc IRootBribeVotingReward
    address public immutable ve;
    /// @inheritdoc IRootBribeVotingReward
    address public gauge;
    /// @inheritdoc IRootBribeVotingReward
    uint256 public chainid;

    constructor(address _bridge, address _voter, address[] memory _rewards) {
        voter = _voter;
        bridge = _bridge;
        ve = IVoter(_voter).ve();
    }

    /// @inheritdoc IRootBribeVotingReward
    function initialize(address _gauge) external {
        if (gauge != address(0)) revert AlreadyInitialized();
        gauge = _gauge;
        chainid = IRootGauge(_gauge).chainid();
    }

    /// @inheritdoc IRootBribeVotingReward
    function getReward(uint256 _tokenId, address[] memory _tokens) external override {
        if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId) && msg.sender != voter) revert NotAuthorized();

        address _owner = IVotingEscrow(ve).ownerOf(_tokenId);
        bytes memory payload = abi.encode(_owner, _tokenId, _tokens);
        bytes memory message = abi.encode(Commands.GET_REWARD, abi.encode(gauge, payload));

        IMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }
}
