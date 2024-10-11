// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootPool {
    error AlreadyInitialized();

    /// @notice Chain Id this pool links to
    function chainid() external view returns (uint256);

    /// @notice Token 0 of the pool
    function token0() external view returns (address);

    /// @notice Token 1 of the pool
    function token1() external view returns (address);

    /// @notice Factory that created this pool
    function factory() external view returns (address);

    /// @notice Whether the pool is stable or volatile: true for stable, false for volatile
    function stable() external view returns (bool);

    /// @notice Initialize function for this pool (used by clones)
    /// @param _chainid Chain Id this pool links to
    /// @param _token0 token0 of the pool
    /// @param _token1 token1 of the pool
    /// @param _stable Whether the pool is stable or volatile: true for stable, false for volatile
    function initialize(uint256 _chainid, address _token0, address _token1, bool _stable) external;
}
