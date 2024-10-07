// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootVotingRewardsFactory} from "../../interfaces/mainnet/rewards/IRootVotingRewardsFactory.sol";
import {IRootFeesVotingReward} from "../../interfaces/mainnet/rewards/IRootFeesVotingReward.sol";
import {IRootMessageBridge} from "../../interfaces/mainnet/bridge/IRootMessageBridge.sol";
import {IRootGauge} from "../../interfaces/mainnet/gauges/IRootGauge.sol";
import {IVotingEscrow} from "../../interfaces/external/IVotingEscrow.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";

import {Commands} from "../../libraries/Commands.sol";

contract RootFeesVotingReward is IRootFeesVotingReward {
    /// @inheritdoc IRootFeesVotingReward
    address public immutable factory;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable bridge;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable voter;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable ve;
    /// @inheritdoc IRootFeesVotingReward
    address public immutable bribeVotingReward;
    /// @inheritdoc IRootFeesVotingReward
    address public gauge;
    /// @inheritdoc IRootFeesVotingReward
    uint256 public chainid;
    /// @inheritdoc IRootFeesVotingReward
    uint256 public constant MAX_REWARDS = 5;

    constructor(address _bridge, address _voter, address _bribeVotingReward, address[] memory _rewards) {
        factory = msg.sender;
        voter = _voter;
        bridge = _bridge;
        ve = IVoter(_voter).ve();
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

        _checkRecipient({_recipient: IVotingEscrow(ve).ownerOf(_tokenId)});

        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), gauge, _amount, _tokenId);
        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootFeesVotingReward
    function _withdraw(uint256 _amount, uint256 _tokenId) external {
        if (msg.sender != voter) revert NotAuthorized();

        bytes memory message = abi.encodePacked(uint8(Commands.WITHDRAW), gauge, _amount, _tokenId);
        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    /// @inheritdoc IRootFeesVotingReward
    function getReward(uint256 _tokenId, address[] memory _tokens) external override {
        if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId) && msg.sender != voter) revert NotAuthorized();
        if (_tokens.length > MAX_REWARDS) revert MaxTokensExceeded();

        address recipient = _checkRecipient({_recipient: IVotingEscrow(ve).ownerOf(_tokenId)});

        bytes memory message =
            abi.encodePacked(uint8(Commands.GET_FEES), gauge, recipient, _tokenId, uint8(_tokens.length), _tokens);

        IRootMessageBridge(bridge).sendMessage({_chainid: chainid, _message: message});
    }

    function _checkRecipient(address _recipient) internal view returns (address recipient) {
        address cachedRecipient = IRootVotingRewardsFactory(factory).recipient(_recipient, chainid);
        if (cachedRecipient == address(0)) {
            if (_recipient.code.length > 0) {
                revert RecipientNotSet();
            }
            recipient = _recipient;
        } else {
            recipient = cachedRecipient;
        }
    }
}
