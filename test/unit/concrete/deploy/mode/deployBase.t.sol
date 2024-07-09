// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {DeployBase} from "script/deployParameters/mode/DeployBase.s.sol";
import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";

import "test/BaseFixture.sol";
import {FeeSharing} from "test/mocks/mode/FeeSharing.sol";

contract ModeDeployBaseTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployBase public deploy;
    DeployBase.DeploymentParameters public params;
    DeployBase.ModeDeploymentParameters public modeParams;

    FeeSharing public fs;

    function setUp() public override {
        deploy = new DeployBase();
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
        ModeRouter router = ModeRouter(payable(address(deploy.router())));
        xFactory = deploy.xerc20Factory();
        params = deploy.params();
        modeParams = deploy.modeParams();

        assertNotEq(address(poolImplementation), address(0));
        assertNotEq(address(poolFactory), address(0));
        assertNotEq(address(router), address(0));
        assertNotEq(address(xFactory), address(0));

        assertEq(poolFactory.implementation(), address(poolImplementation));
        assertEq(poolFactory.poolAdmin(), params.poolAdmin);
        assertEq(poolFactory.pauser(), params.pauser);
        assertEq(poolFactory.feeManager(), params.feeManager);
        assertEq(poolFactory.sfs(), modeParams.sfs);
        assertEq(poolFactory.tokenId(), 0);

        assertEq(router.factory(), address(poolFactory));
        assertEq(address(router.weth()), params.weth);
        assertEq(router.tokenId(), 1);

        assertEq(address(xFactory.createx()), address(cx));
        assertEq(xFactory.name(), "Superchain Velodrome");
        assertEq(xFactory.symbol(), "XVELO");
        assertEq(xFactory.XERC20_ENTROPY(), XERC20_ENTROPY);
        assertEq(xFactory.LOCKBOX_ENTROPY(), LOCKBOX_ENTROPY);
    }
}
