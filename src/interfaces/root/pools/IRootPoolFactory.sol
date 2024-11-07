// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootPoolFactory {
    error SameAddress();
    error PoolAlreadyExists();
    error ZeroAddress();

    event RootPoolCreated(
        address indexed token0, address indexed token1, bool indexed stable, address pool, uint256 length
    );

    /// @notice Pool implementation used by this factory
    function implementation() external view returns (address);

    /// @notice Address of the bridge contract
    /// @dev Used as a registry of chains
    function bridge() external view returns (address);

    /// @notice Return a single pool created by this factory
    /// @return Address of pool
    function allPools(uint256 index) external view returns (address);

    /// @notice Returns all pools created by this factory
    /// @return Array of pool addresses
    function allPools() external view returns (address[] memory);

    /// @notice Returns the number of pools created from this factory
    function allPoolsLength() external view returns (uint256);

    /// @notice Return address of pool created by this factory
    /// @param chainid Chain ID associated with pool
    /// @param tokenA Token A
    /// @param tokenB Token B
    /// @param stable Boolean indicating if pool is stable, true if stable, false if volatile
    /// @return Address of pool
    function getPool(uint256 chainid, address tokenA, address tokenB, bool stable) external view returns (address);

    /// @notice Always returns false as these pools are not real pools
    /// @dev Guarantees gauges attached to pools must be created by the governor
    function isPool(address pool) external pure returns (bool);

    /// @notice Always returns false as these pools are not real pools
    /// @dev Guarantees gauges attached to pools must be created by the governor
    function isPair(address pool) external pure returns (bool);

    /// @notice Create a pool given two tokens
    /// @dev Token order does not matter
    /// @param chainid Chain ID associated with pool
    /// @param tokenA Token A
    /// @param tokenB Token B
    /// @param stable Boolean indicating if pool is stable, true if stable, false if volatile
    /// @return Address of pool
    function createPool(uint256 chainid, address tokenA, address tokenB, bool stable) external returns (address);
}
