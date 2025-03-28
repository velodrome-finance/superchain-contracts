// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPaymaster {
    error InvalidAddress();
    error NotPaymasterVault();

    event PaymasterVaultSet(address indexed _newPaymaster);
    event WhitelistSet(address indexed _account, bool indexed _state);

    /// @notice Returns the address of the paymaster vault, used to sponsor x-chain transactions
    function paymasterVault() external view returns (address);

    /// @notice Returns the list of addresses whitelisted for transaction sponsorship
    /// @return Array of whitelisted addresses
    function whitelist() external view returns (address[] memory);

    /// @notice Check if an account is whitelisted for transaction sponsorship
    /// @return Whether the account is whitelisted or not
    function isWhitelisted(address _account) external view returns (bool);

    /// @notice Get the number of addresses whitelisted for sponsorship
    /// @return Length of whitelisted addresses
    function whitelistLength() external view returns (uint256);

    /// @notice Whitelists/unwhitelists an address for x-chain transaction sponsorship
    /// @dev Only callable by the whitelist manager
    /// @param _account The address of the account to be whitelisted
    /// @param _state Whether the `_account` should be whitelisted or not
    function whitelistForSponsorship(address _account, bool _state) external;

    /// @notice Sets the address of the paymaster vault that will be used to sponsor x-chain transactions
    /// @dev Only callable by the whitelist manager
    /// @param _paymasterVault The address of the new paymaster vault
    function setPaymasterVault(address _paymasterVault) external;
}
