// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootPoolFactory {
    error SameAddress();
    error ZeroAddress();
    error PoolAlreadyExists();

    event PoolCreated(
        address indexed token0, address indexed token1, bool indexed stable, address pool, uint256 length
    );

    /// @notice Chain Id this pool factory links to
    function chainId() external view returns (uint256);

    /// @notice Pool implementation used by this factory
    function implementation() external view returns (address);

    /// @notice Return a single pool created by this factory
    /// @return Address of pool
    function allPools(uint256 index) external view returns (address);

    /// @notice Returns all pools created by this factory
    /// @return Array of pool addresses
    function allPools() external view returns (address[] memory);

    /// @notice returns the number of pools created from this factory
    function allPoolsLength() external view returns (uint256);

    /// @notice Return address of pool created by this factory
    /// @param tokenA Token A
    /// @param tokenB Token B
    /// @param stable Boolean indicating if pool is stable, true if stable, false if volatile
    /// @return Address of pool
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);

    /// @notice Is a valid pool created by this factory
    /// @dev Used by voter for gauge creation
    /// @param pool Address of pool
    /// @return Boolean indicating if pool is created by this factory
    function isPool(address pool) external view returns (bool);

    /// @notice Is a valid pool created by this factory
    /// @dev Used by voter for gauge creation
    /// @param pool Address of pool
    /// @return Boolean indicating if pool is created by this factory
    function isPair(address pool) external view returns (bool);

    /// @notice Create a pool given two tokens
    /// @dev Token order does not matter
    /// @param tokenA Token A
    /// @param tokenB Token B
    /// @param stable Boolean indicating if pool is stable, true if stable, false if volatile
    /// @return Address of pool
    function createPool(address tokenA, address tokenB, bool stable) external returns (address);
}
