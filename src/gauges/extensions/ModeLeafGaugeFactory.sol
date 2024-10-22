// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ModeLeafGauge} from "./ModeLeafGauge.sol";
import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {IModeFeeSharing} from "../../interfaces/extensions/IModeFeeSharing.sol";
import {ILeafGaugeFactory, LeafGaugeFactory, CreateXLibrary} from "../LeafGaugeFactory.sol";

/// @notice Gauge factory wrapper with fee sharing support
contract ModeLeafGaugeFactory is LeafGaugeFactory {
    using CreateXLibrary for bytes11;

    constructor(address _voter, address _xerc20, address _bridge) LeafGaugeFactory(_voter, _xerc20, _bridge) {
        address sfs = IModeFeeSharing(_voter).sfs();
        uint256 tokenId = IModeFeeSharing(_voter).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }

    /// @inheritdoc ILeafGaugeFactory
    function createGauge(address _pool, address _feesVotingReward, bool isPool)
        external
        override
        returns (address gauge)
    {
        if (msg.sender != voter) revert NotVoter();
        bytes32 salt = calculateSalt({_pool: _pool});
        bytes11 entropy = bytes11(salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(ModeLeafGauge).creationCode,
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
}
