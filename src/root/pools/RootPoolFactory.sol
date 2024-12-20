// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Clones} from "@openzeppelin5/contracts/proxy/Clones.sol";

import {IRootPoolFactory} from "../../interfaces/root/pools/IRootPoolFactory.sol";
import {IRootPool} from "../../interfaces/root/pools/IRootPool.sol";
import {ICrossChainRegistry} from "../../interfaces/bridge/ICrossChainRegistry.sol";

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

██████╗  ██████╗  ██████╗ ████████╗██████╗  ██████╗  ██████╗ ██╗
██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔═══██╗██╔═══██╗██║
██████╔╝██║   ██║██║   ██║   ██║   ██████╔╝██║   ██║██║   ██║██║
██╔══██╗██║   ██║██║   ██║   ██║   ██╔═══╝ ██║   ██║██║   ██║██║
██║  ██║╚██████╔╝╚██████╔╝   ██║   ██║     ╚██████╔╝╚██████╔╝███████╗
╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝      ╚═════╝  ╚═════╝ ╚══════╝

███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
█████╗  ███████║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝
██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝
██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝

*/

/// @title Velodrome Superchain Root Pool Factory
/// @notice Factory used to create RootPools
contract RootPoolFactory is IRootPoolFactory {
    /// @inheritdoc IRootPoolFactory
    address public immutable implementation;
    /// @inheritdoc IRootPoolFactory
    address public immutable bridge;

    /// @dev Fetch pool given token addresses and chain id
    mapping(uint256 => mapping(address => mapping(address => mapping(bool => address)))) private _getPool;
    /// @dev List of all pools
    address[] internal _allPools;

    constructor(address _implementation, address _bridge) {
        implementation = _implementation;
        bridge = _bridge;
    }

    /// @inheritdoc IRootPoolFactory
    function allPools(uint256 index) external view returns (address) {
        return _allPools[index];
    }

    /// @inheritdoc IRootPoolFactory
    function allPools() external view returns (address[] memory) {
        return _allPools;
    }

    /// @inheritdoc IRootPoolFactory
    function allPoolsLength() external view returns (uint256) {
        return _allPools.length;
    }

    /// @inheritdoc IRootPoolFactory
    function getPool(uint256 chainid, address tokenA, address tokenB, bool stable) external view returns (address) {
        return _getPool[chainid][tokenA][tokenB][stable];
    }

    /// @inheritdoc IRootPoolFactory
    function isPool(address) external pure returns (bool) {
        return false;
    }

    /// @inheritdoc IRootPoolFactory
    function isPair(address) external pure returns (bool) {
        return false;
    }

    /// @inheritdoc IRootPoolFactory
    function createPool(uint256 chainid, address tokenA, address tokenB, bool stable) external returns (address pool) {
        if (!ICrossChainRegistry(bridge).containsChain({_chainid: chainid})) {
            revert ICrossChainRegistry.ChainNotRegistered();
        }
        if (tokenA == tokenB) revert SameAddress();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
        if (_getPool[chainid][token0][token1][stable] != address(0)) revert PoolAlreadyExists();
        bytes32 salt = keccak256(abi.encodePacked(chainid, token0, token1, stable));
        pool = Clones.cloneDeterministic({implementation: implementation, salt: salt});
        IRootPool(pool).initialize({_chainid: chainid, _token0: token0, _token1: token1, _stable: stable});
        _getPool[chainid][token0][token1][stable] = pool;
        _getPool[chainid][token1][token0][stable] = pool; // populate mapping in the reverse direction
        _allPools.push(pool);
        emit RootPoolCreated({token0: token0, token1: token1, stable: stable, pool: pool, length: _allPools.length});
    }
}
