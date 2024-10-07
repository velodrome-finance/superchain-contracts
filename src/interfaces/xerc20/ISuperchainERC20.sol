// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICrosschainERC20} from "./ICrosschainERC20.sol";

interface ISuperchainERC20 is ICrosschainERC20 {
    error OnlySuperchainERC20Bridge();

    /// @return The address of the Superchain ERC20 Bridge
    function SUPERCHAIN_ERC20_BRIDGE() external view returns (address);
}
