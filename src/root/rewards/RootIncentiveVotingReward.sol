// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootVotingRewardsFactory} from "../../interfaces/root/rewards/IRootVotingRewardsFactory.sol";
import {IRootIncentiveVotingReward} from "../../interfaces/root/rewards/IRootIncentiveVotingReward.sol";
import {IRootMessageBridge} from "../../interfaces/root/bridge/IRootMessageBridge.sol";
import {IRootGauge} from "../../interfaces/root/gauges/IRootGauge.sol";
import {IVotingEscrow} from "../../interfaces/external/IVotingEscrow.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";

import {Commands} from "../../libraries/Commands.sol";

contract RootIncentiveVotingReward is IRootIncentiveVotingReward {
    /// @inheritdoc IRootIncentiveVotingReward
    address public immutable factory;
    /// @inheritdoc IRootIncentiveVotingReward
    address public immutable bridge;
    /// @inheritdoc IRootIncentiveVotingReward
    address public immutable voter;
    /// @inheritdoc IRootIncentiveVotingReward
    address public immutable ve;
    /// @inheritdoc IRootIncentiveVotingReward
    address public gauge;
    /// @inheritdoc IRootIncentiveVotingReward
    uint256 public chainid;
    /// @inheritdoc IRootIncentiveVotingReward
    uint256 public constant MAX_REWARDS = 5;

    constructor(address _bridge, address _voter, address[] memory _rewards) {
        factory = msg.sender;
        voter = _voter;
        bridge = _bridge;
        ve = IVoter(_voter).ve();
    }

    /// @inheritdoc IRootIncentiveVotingReward
    function initialize(address _gauge) external {
        if (gauge != address(0)) revert AlreadyInitialized();
        gauge = _gauge;
        chainid = IRootGauge(_gauge).chainid();
    }

    /// @inheritdoc IRootIncentiveVotingReward
    function getReward(uint256 _tokenId, address[] memory _tokens) external override {
        if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId) && msg.sender != voter) revert NotAuthorized();
        if (_tokens.length > MAX_REWARDS) revert MaxTokensExceeded();

        address recipient = IVotingEscrow(ve).ownerOf(_tokenId);
        address cachedRecipient = IRootVotingRewardsFactory(factory).recipient({_owner: recipient, _chainid: chainid});

        if (cachedRecipient == address(0)) {
            if (recipient.code.length > 0) {
                revert RecipientNotSet();
            }
        } else {
            recipient = cachedRecipient;
        }

        bytes memory message =
            abi.encodePacked(uint8(Commands.GET_INCENTIVES), gauge, recipient, _tokenId, uint8(_tokens.length), _tokens);

        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootIncentiveVotingReward
    function _deposit(uint256, uint256) external {}

    /// @inheritdoc IRootIncentiveVotingReward
    function _withdraw(uint256, uint256) external {}
}
