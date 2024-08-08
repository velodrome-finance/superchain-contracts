// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenBridge {
    /// @notice Transfers an amount of the bridged token to the destination domain
    /// @dev Requires approval for amount in order to bridge
    /// @dev Tokens are sent to the same address as msg.sender
    /// @param _sender The address of the sender that initiated a request to send tokens
    /// @param _amount The amount of the xERC20 token to transfer
    /// @param _chainid The id of the chain to which the tokens should be sent
    function transfer(address _sender, uint256 _amount, uint256 _chainid) external payable;
}
