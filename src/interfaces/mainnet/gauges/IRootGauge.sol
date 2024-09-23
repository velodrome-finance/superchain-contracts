// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootGauge {
    error NotVoter();
    error ZeroAmount();
    error ZeroRewardRate();
    error NotAuthorized();

    event NotifyReward(address indexed _sender, uint256 _amount);

    /// @notice Root gauge factory that created this gauge
    function gaugeFactory() external view returns (address);

    /// @notice Reward token supported by this gauge
    function rewardToken() external view returns (address);

    /// @notice XERC20 token corresponding to reward token
    function xerc20() external view returns (address);

    /// @notice Address of voter contract that sets voting power
    function voter() external view returns (address);

    /// @notice Lockbox to wrap and unwrap reward token to and from XERC20
    function lockbox() external view returns (address);

    /// @notice Bridge contract used to communicate x-chain
    function bridge() external view returns (address);

    /// @notice Minter contract used to mint emissions
    function minter() external view returns (address);

    /// @notice Chain id associated with this pool / gauge
    function chainid() external view returns (uint256);

    /// @notice Helper used by Voter
    function left() external view returns (uint256);

    /// @notice Used by voter to deposit rewards to the gauge
    function notifyRewardAmount(uint256 _amount) external;

    /// @notice Used by notify admin to deposit rewards to the gauge without distributing fees
    function notifyRewardWithoutClaim(uint256 _amount) external;
}
