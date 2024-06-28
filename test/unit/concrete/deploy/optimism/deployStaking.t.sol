// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployStaking} from "script/deployParameters/optimism/DeployStaking.s.sol";

contract OptimismDeployStakingTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployStaking public deploy;
    DeployStaking.DeploymentParameters public params;

    function setUp() public override {
        deploy = new DeployStaking();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();
        deployCreateX();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
    }

    function testRun() public {
        deploy.run();

        stakingRewardsFactory = deploy.stakingRewardsFactory();
        params = deploy.params();

        assertNotEq(address(stakingRewardsFactory), address(0));

        assertEq(stakingRewardsFactory.admin(), params.admin);
        assertEq(stakingRewardsFactory.owner(), params.keeperAdmin);
        assertEq(stakingRewardsFactory.notifyAdmin(), params.notifyAdmin);
        assertEq(stakingRewardsFactory.rewardToken(), params.rewardToken);
        assertEq(stakingRewardsFactory.tokenRegistry(), params.tokenRegistry);
        assertEq(stakingRewardsFactory.router(), params.router);
    }
}
