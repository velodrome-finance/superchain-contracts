// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootVotingRewardsFactory} from "../../interfaces/mainnet/rewards/IRootVotingRewardsFactory.sol";
import {IRootBribeVotingReward} from "../../interfaces/mainnet/rewards/IRootBribeVotingReward.sol";
import {IRootMessageBridge} from "../../interfaces/mainnet/bridge/IRootMessageBridge.sol";
import {IRootGauge} from "../../interfaces/mainnet/gauges/IRootGauge.sol";
import {IVotingEscrow} from "../../interfaces/external/IVotingEscrow.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";

import {Commands} from "../../libraries/Commands.sol";

contract RootBribeVotingReward is IRootBribeVotingReward {
    /// @inheritdoc IRootBribeVotingReward
    address public immutable factory;
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
    /// @inheritdoc IRootBribeVotingReward
    uint256 public constant MAX_REWARDS = 5;

    constructor(address _bridge, address _voter, address[] memory _rewards) {
        factory = msg.sender;
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

    /// @inheritdoc IRootBribeVotingReward
    function _deposit(uint256, uint256) external {}

    /// @inheritdoc IRootBribeVotingReward
    function _withdraw(uint256, uint256) external {}
}
