// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUserTokenBridge {
    error NotModule();
    error ZeroAmount();
    error ZeroAddress();
    error InvalidChain();

    event SetModule(address indexed _sender, address indexed _module);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the module contract that is allowed to mint xERC20 tokens
    function module() external view returns (address);

    /// @notice Sets the address of the module contract that is allowed to mint xERC20 tokens
    /// @dev Module handles x-chain transfers
    /// @param _module The address of the new module contract
    function setModule(address _module) external;

    /// @notice Mints xERC20 tokens to a user
    /// @param _user The address of the user to mint tokens to
    /// @param _amount The amount of xERC20 tokens to mint
    function mint(address _user, uint256 _amount) external;

    /// @notice Burns xERC20 tokens from the sender and triggers a x-chain transfer via the module contract
    /// @param _amount The amount of xERC20 tokens to send
    /// @param _chainid The chain id of the destination chain
    function sendToken(uint256 _amount, uint256 _chainid) external payable;
}
