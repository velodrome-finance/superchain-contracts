// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {IChainRegistry} from "../interfaces/bridge/IChainRegistry.sol";

/// @title Chain Registry
/// @notice Contains logic for managing registered chains from which messages can be sent to or received from
abstract contract ChainRegistry is IChainRegistry, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev Stores list of trusted chains
    EnumerableSet.UintSet internal _chainids;

    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc IChainRegistry
    function registerChain(uint256 _chainid) external onlyOwner {
        if (_chainid == block.chainid) revert InvalidChain();
        if (_chainids.contains(_chainid)) revert AlreadyRegistered();
        _chainids.add({value: _chainid});
        emit ChainRegistered({_chainid: _chainid});
    }

    /// @inheritdoc IChainRegistry
    function deregisterChain(uint256 _chainid) external onlyOwner {
        if (!_chainids.contains(_chainid)) revert NotRegistered();
        _chainids.remove({value: _chainid});
        emit ChainDeregistered({_chainid: _chainid});
    }

    /// @inheritdoc IChainRegistry
    function chainids() external view returns (uint256[] memory) {
        return _chainids.values();
    }
}
