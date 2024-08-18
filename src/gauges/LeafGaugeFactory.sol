// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {CreateXLibrary} from "../libraries/CreateXLibrary.sol";
import {ILeafGaugeFactory} from "../interfaces/gauges/ILeafGaugeFactory.sol";
import {IPoolFactory} from "../interfaces/pools/IPoolFactory.sol";
import {LeafGauge} from "./LeafGauge.sol";

/// @notice Factory that creates leaf gauges on the superchain
contract LeafGaugeFactory is ILeafGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc ILeafGaugeFactory
    address public immutable voter;
    /// @inheritdoc ILeafGaugeFactory
    address public immutable factory;
    /// @inheritdoc ILeafGaugeFactory
    address public immutable xerc20;
    /// @inheritdoc ILeafGaugeFactory
    address public immutable bridge;

    constructor(address _voter, address _factory, address _xerc20, address _bridge) {
        voter = _voter;
        factory = _factory;
        xerc20 = _xerc20;
        bridge = _bridge;
    }

    /// @inheritdoc ILeafGaugeFactory
    function createGauge(address _token0, address _token1, bool _stable, address _feesVotingReward, bool isPool)
        external
        returns (address gauge)
    {
        bytes32 salt = keccak256(abi.encodePacked(block.chainid, _token0, _token1, _stable));
        bytes11 entropy = bytes11(salt);
        address pool = IPoolFactory(factory).getPool({tokenA: _token0, tokenB: _token1, stable: _stable});

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(LeafGauge).creationCode,
                abi.encode(
                    pool, // lp token to stake in gauge
                    _feesVotingReward, // fee contract
                    xerc20, // xerc20 corresponding to reward token
                    voter, // superchain voter contract
                    bridge, // bridge to communicate x-chain
                    isPool
                )
            )
        });
    }
}
