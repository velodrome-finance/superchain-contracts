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
        poolImplementation = address(new ModePool());
        poolFactory = new ModePoolFactory({
            _implementation: poolImplementation,
            _poolAdmin: _params.poolAdmin,
            _pauser: _params.pauser,
            _feeManager: _params.feeManager,
            _sfs: _modeParams.sfs,
            _recipient: _modeParams.recipient
        });

        // stakingRewardsFactory = new StakingRewardsFactory({
        //     _notifyAdmin: _modeParams.notifyAdmin,
        //     _sfs: _modeParams.sfs,
        //     _recipient: _modeParams.recipient,
        //     _keepers: new address[](0)
        // });

        router = address(
            new ModeRouter({
                _factory: address(poolFactory),
                _weth: _params.weth,
                _sfs: _modeParams.sfs,
                _recipient: _modeParams.recipient
            })
        );
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
