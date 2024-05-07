// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBase} from "../01_DeployBase.s.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";
import {StakingRewardsFactory} from "src/gauges/stakingrewards/StakingRewardsFactory.sol";
import {StakingRewards} from "src/gauges/stakingrewards/StakingRewards.sol";

contract DeployMode is DeployBase {
    struct ModeDeploymentParameters {
        address sfs;
        address recipient;
        address notifyAdmin;
    }

    ModeDeploymentParameters internal _modeParams;

    StakingRewardsFactory public stakingRewardsFactory;
    StakingRewards public stakingRewards;

    function setUp() public override {
        _params = DeployBase.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x0000000000000000000000000000000000000001,
            pauser: 0x0000000000000000000000000000000000000001,
            feeManager: 0x0000000000000000000000000000000000000001,
            outputFilename: "Mode.json"
        });
        _modeParams = ModeDeploymentParameters({
            sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020,
            recipient: 0x0000000000000000000000000000000000000001,
            notifyAdmin: 0x0000000000000000000000000000000000000001
        });
    }

    function deploy() internal override {
        poolImplementation = ModePool(
            cx.deployCreate3({
                salt: calculateSalt(POOL_ENTROPY),
                initCode: abi.encodePacked(type(ModePool).creationCode)
            })
        );
        poolFactory = ModePoolFactory(
            cx.deployCreate3({
                salt: calculateSalt(POOL_FACTORY_ENTROPY),
                initCode: abi.encodePacked(
                    type(ModePoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // pool implementation
                        _params.poolAdmin, // pool admin
                        _params.pauser, // pauser
                        _params.feeManager, // fee manager
                        _modeParams.sfs, // sequencer fee sharing contract
                        _modeParams.recipient // sfs nft recipient
                    )
                )
            })
        );

        router = ModeRouter(
            payable(
                cx.deployCreate3({
                    salt: calculateSalt(ROUTER_ENTROPY),
                    initCode: abi.encodePacked(
                        type(ModeRouter).creationCode,
                        abi.encode(
                            address(poolFactory), // pool factory
                            _params.weth, // weth contract
                            _modeParams.sfs, // sequencer fee sharing contract
                            _modeParams.recipient // sfs nft recipient
                        )
                    )
                })
            )
        );

        // stakingRewardsFactory = new StakingRewardsFactory({
        //     _notifyAdmin: _modeParams.notifyAdmin,
        //     _sfs: _modeParams.sfs,
        //     _recipient: _modeParams.recipient,
        //     _keepers: new address[](0)
        // });
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
