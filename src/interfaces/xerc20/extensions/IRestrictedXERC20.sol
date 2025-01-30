// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {IXERC20} from "../IXERC20.sol";

interface IRestrictedXERC20 is IXERC20 {
    error NotWhitelisted();

    /// @notice Returns an array of all whitelisted addresses
    /// @return Array of whitelisted addresses
    function whitelist() external view returns (address[] memory);

    /// @notice Returns the number of whitelisted addresses
    /// @return Length of the whitelist
    function whitelistLength() external view returns (uint256);

    /// @notice Chain Id of the chain containing the original token
    function UNRESTRICTED_CHAIN_ID() external view returns (uint256);

    /// @notice Entropy for the token bridge
    function TOKEN_BRIDGE_ENTROPY() external view returns (bytes11);

    /// @notice Address of token bridge associated with the token
    function tokenBridge() external view returns (address);
}
