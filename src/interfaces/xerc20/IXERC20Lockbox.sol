// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";

import {IXERC20} from "./IXERC20.sol";

interface IXERC20Lockbox {
    /// @notice Emitted when tokens are deposited into the lockbox
    /// @param _sender The address of the user who deposited
    /// @param _amount The amount of tokens deposited
    event Deposit(address _sender, uint256 _amount);

    /// @notice Emitted when tokens are withdrawn from the lockbox
    /// @param _sender The address of the user who withdrew
    /// @param _amount The amount of tokens withdrawn
    event Withdraw(address _sender, uint256 _amount);

    /// @notice The XERC20 token of this contract
    function XERC20() external view returns (IXERC20);

    /// @notice The ERC20 token of this contract
    function ERC20() external view returns (IERC20);

    /// @notice Deposit ERC20 tokens into the lockbox
    /// @param _amount The amount of tokens to deposit
    function deposit(uint256 _amount) external;

    /// @notice Withdraw ERC20 tokens from the lockbox
    /// @param _amount The amount of tokens to withdraw
    function withdraw(uint256 _amount) external;
}
