// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootPool} from "../../interfaces/mainnet/pools/IRootPool.sol";

/// @notice RootPool used as basis for creating RootGauges
/// @dev Not a real pool
contract RootPool is IRootPool {
    /// @inheritdoc IRootPool
    uint256 public chainid;
    /// @inheritdoc IRootPool
    address public token0;
    /// @inheritdoc IRootPool
    address public token1;
    /// @inheritdoc IRootPool
    address public factory;
    /// @inheritdoc IRootPool
    bool public stable;

    constructor() {}

    /// @inheritdoc IRootPool
    function initialize(uint256 _chainid, address _token0, address _token1, bool _stable) external {
        if (factory != address(0)) revert AlreadyInitialized();
        factory = msg.sender;
        chainid = _chainid;
        token0 = _token0;
        token1 = _token1;
        stable = _stable;
    }
}
