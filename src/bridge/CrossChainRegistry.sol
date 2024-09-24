// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {ICrossChainRegistry} from "../interfaces/bridge/ICrossChainRegistry.sol";

/// @title Cross Chain Registry
/// @notice Contains logic for managing registered chains from which messages can be sent to or received from
abstract contract CrossChainRegistry is ICrossChainRegistry, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Stores list of trusted chains
    EnumerableSet.UintSet internal _chainids;
    /// @dev Stores list of modules
    /// @dev Modules on other chains are not trusted by default and must be checked
    EnumerableSet.AddressSet internal _modules;

    /// @inheritdoc ICrossChainRegistry
    mapping(uint256 => address) public chains;

    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc ICrossChainRegistry
    function registerChain(uint256 _chainid, address _module) external onlyOwner {
        if (_chainid == 10) revert InvalidChainId();
        if (!_modules.contains(_module)) revert ModuleNotAdded();
        if (_chainids.contains(_chainid)) revert ChainAlreadyAdded();
        chains[_chainid] = _module;
        _chainids.add(_chainid);
        emit ChainRegistered({_chainid: _chainid, _module: _module});
    }

    /// @inheritdoc ICrossChainRegistry
    function deregisterChain(uint256 _chainid) external onlyOwner {
        if (chains[_chainid] == address(0)) revert ChainNotRegistered();
        delete chains[_chainid];
        _chainids.remove(_chainid);
        emit ChainDeregistered({_chainid: _chainid});
    }

    /// @inheritdoc ICrossChainRegistry
    function setModule(uint256 _chainid, address _module) external onlyOwner {
        if (!_modules.contains(_module)) revert ModuleNotAdded();
        if (!_chainids.contains(_chainid)) revert ChainNotRegistered();
        chains[_chainid] = _module;
        emit ModuleSet({_chainid: _chainid, _module: _module});
    }

    /// @inheritdoc ICrossChainRegistry
    function addModule(address _module) external onlyOwner {
        if (_modules.contains(_module)) revert ModuleAlreadyAdded();
        _modules.add(_module);
        emit ModuleAdded({_module: _module});
    }

    /// @inheritdoc ICrossChainRegistry
    function chainids() external view returns (uint256[] memory) {
        return _chainids.values();
    }

    /// @inheritdoc ICrossChainRegistry
    function containsChain(uint256 _chainid) external view returns (bool) {
        return _chainids.contains(_chainid);
    }

    /// @inheritdoc ICrossChainRegistry
    function modules() external view returns (address[] memory) {
        return _modules.values();
    }

    /// @inheritdoc ICrossChainRegistry
    function containsModule(address _module) external view returns (bool) {
        return _modules.contains(_module);
    }
}
