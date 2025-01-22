// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITokenBridge} from "../../bridge/ITokenBridge.sol";
import {IXERC20Lockbox} from "../../xerc20/IXERC20Lockbox.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";

interface IRootTokenBridge is ITokenBridge {
    event ModuleSet(address indexed _sender, address indexed _module);

    /// @notice The lockbox contract used to wrap and unwrap erc20
    function lockbox() external view returns (IXERC20Lockbox);

    /// @notice The underlying ERC20 token of the lockbox
    function erc20() external view returns (IERC20);

    /// @notice Returns the address of the message module contract used to fetch domain information
    function module() external view returns (address);

    /// @notice Sets the address of the module contract that is used to fetch domain information
    /// @param _module The address of the new module contract
    function setModule(address _module) external;
}
