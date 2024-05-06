// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenRegistry {
    error NotAdmin();
    error ZeroAddress();

    event SetAdmin(address indexed admin);
    event WhitelistToken(address indexed whitelister, address indexed token, bool indexed state);

    /// @notice Address of the Admin allowed to manage Token Whitelistings
    function admin() external view returns (address);

    /// @notice View if an address is a Whitelisted token approved by this Registry
    /// @param _token Address of Token queried
    /// @return True if Whitelisted, else false
    function isWhitelistedToken(address _token) external view returns (bool);

    /// @notice Whitelist (or unwhitelist) token for use in Gauge creation.
    /// @dev    Throws if not called by Admin
    /// @param _token Address of token
    /// @param _state Whether the token should be Whitelisted or not
    function whitelistToken(address _token, bool _state) external;

    /// @notice Set new Admin.
    /// @dev    Throws if not called by Admin.
    /// @param _admin Address of new admin to be set
    function setAdmin(address _admin) external;
}
