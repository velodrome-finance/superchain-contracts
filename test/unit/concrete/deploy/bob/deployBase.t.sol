// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployBase} from "script/deployParameters/bob/DeployBase.s.sol";

contract BobDeployBaseTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployBase public deploy;
    DeployBase.DeploymentParameters public params;

    function setUp() public override {
        deploy = new DeployBase();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deploy)).sig("isTest()").checked_write(true);

        deployCreateX();
    }

    function testRun() public {
        deploy.run();

        poolImplementation = deploy.poolImplementation();
        poolFactory = deploy.poolFactory();

        leafGaugeFactory = deploy.gaugeFactory();
        leafVotingRewardsFactory = deploy.votingRewardsFactory();
        leafVoter = deploy.voter();

        leafXFactory = deploy.xerc20Factory();
        leafXVelo = deploy.xVelo();

        leafTokenBridge = deploy.tokenBridge();
        leafMessageBridge = deploy.messageBridge();
        leafMessageModule = deploy.messageModule();

        leafIsm = deploy.ism();
        leafRouter = deploy.router();

        params = deploy.params();

        assertNotEq(address(poolImplementation), address(0));
        assertNotEq(address(poolFactory), address(0));

        assertNotEq(address(leafGaugeFactory), address(0));
        assertNotEq(address(leafVotingRewardsFactory), address(0));
        assertNotEq(address(leafVoter), address(0));

        assertNotEq(address(leafXFactory), address(0));
        assertNotEq(address(leafXVelo), address(0));

        assertNotEq(address(leafTokenBridge), address(0));
        assertNotEq(address(leafMessageBridge), address(0));
        assertNotEq(address(leafMessageModule), address(0));

        // assertNotEq(address(leafIsm), address(0));
        assertNotEq(address(leafRouter), address(0));

        assertEq(poolFactory.implementation(), address(poolImplementation));
        assertEq(poolFactory.poolAdmin(), params.poolAdmin);
        assertEq(poolFactory.pauser(), params.pauser);
        assertEq(poolFactory.feeManager(), params.feeManager);
        assertEq(poolFactory.isPaused(), false);
        assertEq(poolFactory.stableFee(), 5);
        assertEq(poolFactory.volatileFee(), 30);

        assertEq(leafGaugeFactory.voter(), address(leafVoter));
        assertEq(leafGaugeFactory.xerc20(), address(leafXVelo));
        assertEq(leafGaugeFactory.bridge(), address(leafMessageBridge));
        assertEq(leafGaugeFactory.notifyAdmin(), params.adminPlaceholder);

        assertEq(leafVotingRewardsFactory.voter(), address(leafVoter));
        assertEq(leafVotingRewardsFactory.bridge(), address(leafMessageBridge));

        assertEq(leafVoter.bridge(), address(leafMessageBridge));

        assertEq(address(leafXFactory.createx()), address(cx));
        assertEq(leafXFactory.owner(), params.tokenAdmin);
        assertEq(leafXFactory.name(), "Superchain Velodrome");
        assertEq(leafXFactory.symbol(), "XVELO");
        assertEq(leafXFactory.XERC20_ENTROPY(), XERC20_ENTROPY);
        assertEq(leafXFactory.LOCKBOX_ENTROPY(), LOCKBOX_ENTROPY);
        assertEq(leafXFactory.owner(), params.tokenAdmin);

        assertEq(leafXVelo.name(), "Superchain Velodrome");
        assertEq(leafXVelo.symbol(), "XVELO");
        assertEq(leafXVelo.owner(), params.tokenAdmin);
        assertEq(leafXVelo.lockbox(), address(0));

        assertEq(leafTokenBridge.owner(), params.tokenAdmin);
        assertEq(leafTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafTokenBridge.mailbox(), params.mailbox);
        assertEq(address(leafTokenBridge.securityModule()), address(leafIsm));

        assertEq(leafMessageBridge.owner(), params.adminPlaceholder);
        assertEq(leafMessageBridge.xerc20(), address(leafXVelo));
        assertEq(leafMessageBridge.voter(), address(leafVoter));
        assertEq(leafMessageBridge.module(), address(leafMessageModule));
        assertEq(leafMessageBridge.poolFactory(), address(poolFactory));

        assertEq(leafMessageModule.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.xerc20(), address(leafXVelo));
        assertEq(leafMessageModule.voter(), address(leafVoter));
        assertEq(leafMessageModule.mailbox(), params.mailbox);
        assertEq(address(leafMessageModule.securityModule()), address(leafIsm));

        assertEq(leafRouter.factory(), address(poolFactory));
        assertEq(leafRouter.poolImplementation(), address(poolImplementation));
        assertEq(address(leafRouter.weth()), params.weth);
    }
}
