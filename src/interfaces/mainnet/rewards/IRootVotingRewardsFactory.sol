// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootVotingRewardsFactory {
    event RecipientSet(address indexed _caller, uint256 indexed _chainid, address indexed _recipient);

    /// @notice Address of bridge contract used to forward rewards messages
    /// @return Address of the bridge contract
    function bridge() external view returns (address);

    /// @notice Returns the recipient of the rewards for a given user and chain
    /// @param _owner Address of the owner
    /// @param _chainid Chain id
    /// @return Address of the recipient
    function recipient(address _owner, uint256 _chainid) external view returns (address);

    /// @notice Sets the recipient of the rewards for a given user and chain
    /// @param _chainid Chain id
    /// @param _recipient Address of the recipient
    function setRecipient(uint256 _chainid, address _recipient) external;

    /// @notice creates a BribeVotingReward and a FeesVotingReward contract for a gauge
    /// @param _forwarder Address of the forwarder -- unused
    /// @param _rewards Addresses of pool tokens to be used as valid rewards tokens
    /// @return feesVotingReward Address of FeesVotingReward contract created
    /// @return bribeVotingReward Address of BribeVotingReward contract created
    function createRewards(address _forwarder, address[] memory _rewards)
        external
        returns (address feesVotingReward, address bribeVotingReward);
}
