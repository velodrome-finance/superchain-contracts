// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILeafMessageBridge {
    error NotModule();
    error ZeroAddress();

    event SetModule(address indexed _sender, address indexed _module);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the module contract that is allowed to send messages x-chain
    function module() external view returns (address);

    /// @notice Returns the address of the voter contract
    /// @dev Used to verify the sender of a message
    function voter() external view returns (address);

    /// @notice Returns the address of the Pool Factory associated with Bridge
    /// @dev Pool Factory maintains the same address across all Leaf Chains but differs on the Root Chain
    function poolFactory() external view returns (address);

    /// @notice Sets the address of the module contract that is allowed to send messages x-chain
    /// @dev Module handles x-chain messages
    /// @param _module The address of the new module contract
    function setModule(address _module) external;

    /// @notice Mints xERC20 tokens to a user
    /// @param _recipient The address of the recipient to mint tokens to
    /// @param _amount The amount of xERC20 tokens to mint
    function mint(address _recipient, uint256 _amount) external;
}
