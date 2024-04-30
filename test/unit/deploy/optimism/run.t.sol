// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";
import {DeployOptimism} from "script/deployParameters/DeployOptimism.s.sol";

contract RunTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployOptimism public deploy;
    DeployOptimism.DeploymentParameters public params;

    function setUp() public override {
        deploy = new DeployOptimism();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();

        createUsers();
        stdstore.target(address(deploy)).sig("deployerAddress()").checked_write(users.owner);
    }

    function testRun() public {
        deploy.run();

        poolImplementation = Pool(deploy.poolImplementation());
        poolFactory = PoolFactory(deploy.poolFactory());
        router = Router(payable(deploy.router()));
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
