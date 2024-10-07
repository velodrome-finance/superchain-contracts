// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICreateX} from "createX/ICreateX.sol";

interface IXERC20Factory {
    event DeployXERC20(address _xerc20);
    event DeployXERC20WithLockbox(address _xerc20, address _lockbox);

    error InvalidChainId();
    error ZeroAddress();

    /// @notice CreateX factory instance
    function createx() external view returns (ICreateX);

    /// @notice Initial owner of XERC20
    function owner() external view returns (address);

    /// @notice Name of XERC20 token
    function name() external view returns (string memory);

    /// @notice Symbol of XERC20 token
    function symbol() external view returns (string memory);

    /// @notice Entropy for XERC20 deployment
    function XERC20_ENTROPY() external view returns (bytes11);

    /// @notice Entropy for XERC20 lockbox deployment
    function LOCKBOX_ENTROPY() external view returns (bytes11);

    /// @notice Deploys a new XERC20 token with a deterministic address
    /// @dev Reverts if chain id is 10 (Optimism)
    function deployXERC20() external returns (address _XERC20);

    /// @notice Deploys a new XERC20 token with a deterministic address with a corresponding lockbox
    /// @dev Reverts if chain is not 10 (i.e. not Optimism)
    function deployXERC20WithLockbox(address _erc20) external returns (address _XERC20, address _lockbox);
}
