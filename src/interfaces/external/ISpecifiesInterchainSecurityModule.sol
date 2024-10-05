// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

interface ISpecifiesInterchainSecurityModule {
    event InterchainSecurityModuleChanged(address indexed _new);

    // @notice The currently set InterchainSecurityModule.
    function interchainSecurityModule() external view returns (IInterchainSecurityModule);

    // @notice Sets the new InterchainSecurityModule.
    /// @dev Throws if not called by owner.
    /// @param _ism .
    function setInterchainSecurityModule(address _ism) external;
}
