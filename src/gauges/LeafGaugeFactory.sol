// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {CreateXLibrary} from "../libraries/CreateXLibrary.sol";
import {ILeafGaugeFactory} from "../interfaces/gauges/ILeafGaugeFactory.sol";
import {IPool} from "../interfaces/pools/IPool.sol";
import {LeafGauge} from "./LeafGauge.sol";

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

██╗     ███████╗ █████╗ ███████╗ ██████╗  █████╗ ██╗   ██╗ ██████╗ ███████╗
██║     ██╔════╝██╔══██╗██╔════╝██╔════╝ ██╔══██╗██║   ██║██╔════╝ ██╔════╝
██║     █████╗  ███████║█████╗  ██║  ███╗███████║██║   ██║██║  ███╗█████╗
██║     ██╔══╝  ██╔══██║██╔══╝  ██║   ██║██╔══██║██║   ██║██║   ██║██╔══╝
███████╗███████╗██║  ██║██║     ╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝███████╗
╚══════╝╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝

███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
█████╗  ███████║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝
██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝
██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝

*/

/// @title Velodrome Superchain Leaf Gauge Factory
/// @notice Used to deploy Leaf Gauge contracts for distribution of emissions
contract LeafGaugeFactory is ILeafGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc ILeafGaugeFactory
    address public immutable voter;
    /// @inheritdoc ILeafGaugeFactory
    address public immutable xerc20;
    /// @inheritdoc ILeafGaugeFactory
    address public immutable bridge;

    constructor(address _voter, address _xerc20, address _bridge) {
        voter = _voter;
        xerc20 = _xerc20;
        bridge = _bridge;
    }

    /// @inheritdoc ILeafGaugeFactory
    function createGauge(address _pool, address _feesVotingReward, bool isPool)
        external
        virtual
        returns (address gauge)
    {
        if (msg.sender != voter) revert NotVoter();
        bytes32 salt = calculateSalt({_pool: _pool});
        bytes11 entropy = bytes11(salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(LeafGauge).creationCode,
                abi.encode(
                    _pool, // lp token to stake in gauge
                    _feesVotingReward, // fee contract
                    xerc20, // xerc20 corresponding to reward token
                    voter, // superchain voter contract
                    bridge, // bridge to communicate x-chain
                    isPool // whether the gauge is linked to a pool
                )
            )
        });
    }

    /// @dev Calculate salt for gauge creation
    function calculateSalt(address _pool) internal view returns (bytes32) {
        address _token0 = IPool(_pool).token0();
        address _token1 = IPool(_pool).token1();
        bool _stable = IPool(_pool).stable();
        return keccak256(abi.encodePacked(block.chainid, _token0, _token1, _stable));
    }
}
