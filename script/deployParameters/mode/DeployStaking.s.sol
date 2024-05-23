// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployStakingFixture} from "../../02_DeployStakingFixture.s.sol";
import {TokenRegistry} from "src/gauges/tokenregistry/TokenRegistry.sol";
import {ModeStakingRewards} from "src/gauges/stakingrewards/extensions/ModeStakingRewards.sol";
import {ModeStakingRewardsFactory} from "src/gauges/stakingrewards/extensions/ModeStakingRewardsFactory.sol";

contract DeployStaking is DeployStakingFixture {
    struct ModeDeploymentParameters {
        address sfs;
        address recipient;
    }

    ModeDeploymentParameters internal _modeParams;

    function setUp() public override {
        _params = DeployStakingFixture.DeploymentParameters({
            router: 0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45,
            keeperAdmin: 0xb32Db5b848B837DC39EF20B4110dFAc7493e93ed,
            notifyAdmin: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            admin: 0x5d496974832B8BC3c02F89E7Ac0b7579b4d1cC09,
            rewardToken: 0xDfc7C877a950e49D2610114102175A06C2e3167a,
            tokenRegistry: 0x8d9c67488c154286B9D4ccaC6c4CBF30589107a7,
            outputFilename: "mode.json"
        });
        _modeParams = ModeDeploymentParameters({
            sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020,
            recipient: 0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3
        });
    }

    function deploy() internal override {
        stakingRewardsImplementation = new ModeStakingRewards();
        stakingRewardsFactory = new ModeStakingRewardsFactory({
            _admin: _params.admin,
            _notifyAdmin: _params.notifyAdmin,
            _keeperAdmin: _params.keeperAdmin,
            _tokenRegistry: _params.tokenRegistry,
            _rewardToken: _params.rewardToken,
            _router: _params.router,
            _stakingRewardsImplementation: address(stakingRewardsImplementation),
            _sfs: _modeParams.sfs,
            _recipient: _modeParams.recipient,
            _keepers: new address[](0)
        });
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
