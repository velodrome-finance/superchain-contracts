// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootMessageBridge {
    error InvalidCommand();
    error ZeroAddress();
    error NotAuthorized(uint256 command);
    error NotValidGauge();
    error NotWETH();

    event SetModule(address indexed _sender, address indexed _module);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the module contract that is allowed to send messages x-chain
    function module() external view returns (address);

    /// @notice Returns the address of the voter contract
    /// @dev Used to verify the sender of a message
    function voter() external view returns (address);

    /// @notice Returns the address of the factory registry contract
    function factoryRegistry() external view returns (address);

    /// @notice Returns the address of the WETH contract
    function weth() external view returns (address);

    /// @notice Sets the address of the module contract that is allowed to send messages x-chain
    /// @dev Module handles x-chain messages
    /// @param _module The address of the new module contract
    function setModule(address _module) external;

    /// @notice Sends a message to the msg.sender via the module contract
    /// @param _message The message
    /// @param _chainid The chain id of chain the recipient contract is on
    function sendMessage(uint256 _chainid, bytes calldata _message) external;
}
