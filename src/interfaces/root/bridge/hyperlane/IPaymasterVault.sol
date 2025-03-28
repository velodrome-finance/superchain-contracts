// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPaymasterVault {
    error ETHTransferFailed();
    error NotVaultManager();
    error ZeroAddress();

    event FundsWithdrawn(address indexed _recipient, uint256 _amount);

    /// @notice Returns the address of the vault manager
    function vaultManager() external view returns (address);

    /// @notice Withdraw ETH balance from the vault
    /// @dev Only callable by the owner
    /// @param _recipient The address of the recipient
    /// @param _amount The amount of tokens to withdraw
    function withdrawFunds(address _recipient, uint256 _amount) external;

    /// @notice Fund vault manager with ETH for transaction sponsoring
    /// @param _value The amount of funding required for the transaction
    function sponsorTransaction(uint256 _value) external;
}
