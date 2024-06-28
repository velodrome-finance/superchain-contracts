// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployStaking} from "script/deployParameters/mode/DeployStaking.s.sol";
import {ModeStakingRewards} from "src/gauges/stakingrewards/extensions/ModeStakingRewards.sol";
import {ModeStakingRewardsFactory} from "src/gauges/stakingrewards/extensions/ModeStakingRewardsFactory.sol";

contract ModeDeployStakingTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployStaking deploy;
    DeployStaking.DeploymentParameters public params;
    DeployStaking.ModeDeploymentParameters public modeParams;

    function setUp() public override {
        deploy = new DeployStaking();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();
        deployCreateX();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);

        fs = new FeeSharing();
        vm.etch(0x8680CEaBcb9b56913c519c069Add6Bc3494B7020, address(fs).code);
    }

    function testRun() public {
        deploy.run();

        ModeStakingRewards stakingRewards = ModeStakingRewards(address(deploy.stakingRewardsImplementation()));
        ModeStakingRewardsFactory stakingRewardsFactory =
            ModeStakingRewardsFactory(address(deploy.stakingRewardsFactory()));
        params = deploy.params();
        modeParams = deploy.modeParams();

        assertNotEq(address(stakingRewards), address(0));
        assertNotEq(address(stakingRewardsFactory), address(0));

        assertEq(stakingRewardsFactory.admin(), params.admin);
        assertEq(stakingRewardsFactory.owner(), params.keeperAdmin);
        assertEq(stakingRewardsFactory.notifyAdmin(), params.notifyAdmin);
        assertEq(stakingRewardsFactory.rewardToken(), params.rewardToken);
        assertEq(stakingRewardsFactory.tokenRegistry(), params.tokenRegistry);
        assertEq(stakingRewardsFactory.router(), params.router);
        assertEq(stakingRewardsFactory.stakingRewardsImplementation(), address(stakingRewards));
        assertEq(stakingRewardsFactory.sfs(), modeParams.sfs);
        assertEq(stakingRewardsFactory.tokenId(), 0);
    }
}
