// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

interface IGasRouter {
    error LengthMismatch();

    event GasLimitSet(uint256 _command, uint256 _gasLimit);

    /// @notice Returns the gas limit for a given command
    /// @dev Returns 0 if invalid _command
    /// @param _command Command to get gas limit for
    /// @return gasLimit Gas limit for the command
    function gasLimit(uint256 _command) external view returns (uint256);

    /// @notice Sets the gas limit for a given command
    /// @dev Only callable by the owner
    /// @param _command Command to set gas limit for
    /// @param _gasLimit Gas limit for the command
    function setGasLimit(uint256 _command, uint256 _gasLimit) external;

    /// @notice Sets the gas limits for the given commands
    /// @dev Only callable by the owner.
    /// Will revert if the length of `_commands` and `_gasLimits` do not match
    /// @param _commands Commands to set gas limit for
    /// @param _gasLimits Gas limits for the commands
    function setGasLimits(uint256[] memory _commands, uint256[] memory _gasLimits) external;
}
