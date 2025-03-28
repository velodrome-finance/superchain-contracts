// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHookGasEstimator {
    /// @notice Returns the estimated gas limit for token bridging
    function estimateSendTokenGas() external view returns (uint256);

    /// @notice Returns the estimated gas limit for token bridging with locking
    function estimateSendTokenAndLockGas() external view returns (uint256);

    /// @notice Returns the estimated gas limit for a given command
    /// @param _command The identifier of the command to estimate gas for
    function estimateGas(uint256 _command) external view returns (uint256);
}
