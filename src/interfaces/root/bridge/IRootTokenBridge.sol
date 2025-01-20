// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {IXERC20Lockbox} from "../../xerc20/IXERC20Lockbox.sol";

interface IRootTokenBridge {
    /// @notice The lockbox contract used to wrap and unwrap erc20
    function lockbox() external view returns (IXERC20Lockbox);

    /// @notice The underlying ERC20 token of the lockbox
    function erc20() external view returns (IERC20);

    /// @notice Pulls ERC20 tokens from the sender, wraps to xERC20, burns xERC20 and triggers a x-chain transfer
    /// @param _recipient The address of the recipient on the destination chain
    /// @param _amount The amount of ERC20 tokens to send
    /// @param _chainid The chain id of the destination chain
    function sendToken(address _recipient, uint256 _amount, uint256 _chainid) external payable;

    /// @notice Callback function used by the mailbox contract to handle incoming messages
    /// @dev Mints xERC20, unwraps to ERC20 and transfers to the recipient
    /// @param _origin The domain from which the message originates
    /// @param _sender The address of the sender of the message
    /// @param _message The message payload
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable;
}
