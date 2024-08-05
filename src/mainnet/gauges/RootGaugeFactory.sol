// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {CreateXLibrary} from "../../libraries/CreateXLibrary.sol";
import {IRootGaugeFactory} from "../../interfaces/mainnet/gauges/IRootGaugeFactory.sol";
import {IRootPool} from "../../interfaces/mainnet/pools/IRootPool.sol";
import {RootGauge} from "./RootGauge.sol";

/// @notice Factory that creates root gauges on mainnet
contract RootGaugeFactory is IRootGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc IRootGaugeFactory
    address public immutable voter;
    /// @inheritdoc IRootGaugeFactory
    address public immutable xerc20;
    /// @inheritdoc IRootGaugeFactory
    address public immutable lockbox;
    /// @inheritdoc IRootGaugeFactory
    address public immutable bridge;

    constructor(address _voter, address _xerc20, address _lockbox, address _bridge) {
        voter = _voter;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        bridge = _bridge;
    }

    /// @inheritdoc IRootGaugeFactory
    function createGauge(address, address _pool, address, address _rewardToken, bool)
        external
        returns (address gauge)
    {
        if (msg.sender != voter) revert NotVoter();
        address _token0 = IRootPool(_pool).token0();
        address _token1 = IRootPool(_pool).token1();
        bool _stable = IRootPool(_pool).stable();
        uint256 _chainId = IRootPool(_pool).chainId();
        bytes32 salt = keccak256(abi.encodePacked(_chainId, _token0, _token1, _stable));
        bytes11 entropy = bytes11(salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(RootGauge).creationCode,
                abi.encode(
                    _rewardToken, // reward token
                    xerc20, // xerc20 corresponding to reward token
                    lockbox, // lockbox to convert reward token to xerc20
                    bridge, // bridge to communicate x-chain
                    _chainId // chain id associated with gauge
                )
            )
        });
    }
}
