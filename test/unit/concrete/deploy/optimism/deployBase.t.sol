// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployBase} from "script/deployParameters/optimism/DeployBase.s.sol";

contract OptimismDeployBaseTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployBase public deploy;
    DeployBase.DeploymentParameters public params;

    function setUp() public override {
        deploy = new DeployBase();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();
        deployCreateX();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
    }

    function testRun() public {
        deploy.run();

        poolImplementation = deploy.poolImplementation();
        poolFactory = deploy.poolFactory();
        router = deploy.router();
        params = deploy.params();

        assertNotEq(address(poolImplementation), address(0));
        assertNotEq(address(poolFactory), address(0));
        assertNotEq(address(router), address(0));

        assertEq(poolFactory.implementation(), address(poolImplementation));
        assertEq(poolFactory.poolAdmin(), params.poolAdmin);
        assertEq(poolFactory.pauser(), params.pauser);
        assertEq(poolFactory.feeManager(), params.feeManager);

        assertEq(router.factory(), address(poolFactory));
        assertEq(address(router.weth()), params.weth);
    }
}
