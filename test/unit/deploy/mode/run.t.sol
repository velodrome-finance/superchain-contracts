// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";
import {DeployMode} from "script/deployParameters/DeployMode.s.sol";
import {ModeStakingRewardsFactory} from "src/gauges/stakingrewards/extensions/ModeStakingRewardsFactory.sol";
import {ModeStakingRewards} from "src/gauges/stakingrewards/extensions/ModeStakingRewards.sol";
import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";

contract ModeRunTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployMode public deploy;
    DeployMode.DeploymentParameters public params;
    DeployMode.ModeDeploymentParameters public modeParams;

    function setUp() public override {
        deploy = new DeployMode();
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

        ModePool poolImplementation = ModePool(address(deploy.poolImplementation()));
        ModePoolFactory poolFactory = ModePoolFactory(address(deploy.poolFactory()));
        ModeStakingRewardsFactory stakingRewardsFactory = deploy.stakingRewardsFactory();
        ModeRouter router = ModeRouter(payable(address(deploy.router())));
        tokenRegistry = deploy.tokenRegistry();
        params = deploy.params();
        modeParams = deploy.modeParams();

        assertNotEq(address(poolImplementation), address(0));
        assertNotEq(address(poolFactory), address(0));
        assertNotEq(address(router), address(0));
        assertNotEq(address(tokenRegistry), address(0));

        assertEq(poolFactory.implementation(), address(poolImplementation));
        assertEq(poolFactory.poolAdmin(), params.poolAdmin);
        assertEq(poolFactory.pauser(), params.pauser);
        assertEq(poolFactory.feeManager(), params.feeManager);
        assertEq(poolFactory.sfs(), modeParams.sfs);
        assertEq(poolFactory.tokenId(), 0);

        assertEq(stakingRewardsFactory.admin(), modeParams.notifyAdmin);
        assertEq(stakingRewardsFactory.sfs(), modeParams.sfs);
        assertEq(stakingRewardsFactory.tokenId(), 2);

        assertEq(router.factory(), address(poolFactory));
        assertEq(address(router.weth()), params.weth);
        assertEq(router.tokenId(), 1);

        assertEq(tokenRegistry.admin(), params.whitelistAdmin);
        assertTrue(tokenRegistry.isWhitelistedToken(params.whitelistedTokens[0]));
    }
}
