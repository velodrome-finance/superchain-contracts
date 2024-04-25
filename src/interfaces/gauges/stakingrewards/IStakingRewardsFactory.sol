// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingRewardsFactory {
    error NotNotifyAdmin();
    error ZeroAddress();

    event SetNotifyAdmin(address indexed _notifyAdmin);

    /// @notice Notify admin address
    function notifyAdmin() external view returns (address);

    /// @notice Set new notify admin
    /// @param _notifyAdmin New notify admin address
    function setNotifyAdmin(address _notifyAdmin) external;

    /// @notice Create new staking rewards contract
    /// @param _pool Pool address
    /// @param _feesVotingReward Fees voting reward address
    /// @param _rewardToken Reward token address
    /// @param isPool Is pool
    /// @return stakingRewards New staking rewards contract address
    function createStakingRewards(address _pool, address _feesVotingReward, address _rewardToken, bool isPool)
        external
        returns (address);
}
