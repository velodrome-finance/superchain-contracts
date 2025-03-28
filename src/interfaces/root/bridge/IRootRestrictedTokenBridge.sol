// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRootTokenBridge} from "../../root/bridge/IRootTokenBridge.sol";

interface IRootRestrictedTokenBridge is IRootTokenBridge {
    error GaugeNotAlive();
    error InvalidGauge();
    error InvalidChainId();

    /// @notice Chain id for Base network
    /// @return The Base chain id (8453)
    function BASE_CHAIN_ID() external view returns (uint256);

    /// @notice Address of the voter contract
    /// @return The address of the voter contract
    function voter() external view returns (address);
}
