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

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deploy)).sig("isTest()").checked_write(true);

        fs = new FeeSharing();
        vm.etch(0x8680CEaBcb9b56913c519c069Add6Bc3494B7020, address(fs).code);

        deployCreateX();
    }

    function testRun() public {
        deploy.run();

        ModePool poolImplementation = ModePool(address(deploy.poolImplementation()));
        ModePoolFactory poolFactory = ModePoolFactory(address(deploy.poolFactory()));
        ModeRouter router = ModeRouter(payable(address(deploy.router())));
        leafGaugeFactory = deploy.gaugeFactory();
        leafVotingRewardsFactory = deploy.votingRewardsFactory();
        leafVoter = deploy.voter();

        leafXFactory = deploy.xerc20Factory();
        leafXVelo = deploy.xVelo();

        leafTokenBridge = deploy.tokenBridge();
        leafMessageBridge = deploy.messageBridge();
        leafMessageModule = deploy.messageModule();

        leafIsm = deploy.ism();

        params = deploy.params();
        modeParams = deploy.modeParams();

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
        assertNotEq(address(router), address(0));

        assertEq(poolFactory.implementation(), address(poolImplementation));
        assertEq(poolFactory.poolAdmin(), params.poolAdmin);
        assertEq(poolFactory.pauser(), params.pauser);
        assertEq(poolFactory.feeManager(), params.feeManager);
        assertEq(poolFactory.isPaused(), false);
        assertEq(poolFactory.stableFee(), 5);
        assertEq(poolFactory.volatileFee(), 30);
        assertEq(poolFactory.sfs(), modeParams.sfs);
        assertEq(poolFactory.tokenId(), 0);

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
        assertEq(leafMessageModule.mailbox(), params.mailbox);
        assertEq(leafMessageModule.xerc20(), address(leafXVelo));
        assertEq(leafMessageModule.voter(), address(leafVoter));
        assertEq(address(leafMessageModule.securityModule()), address(leafIsm));

        assertEq(router.factory(), address(poolFactory));
        assertEq(router.poolImplementation(), address(poolImplementation));
        assertEq(address(router.weth()), params.weth);
        assertNotEq(router.tokenId(), 0);
    }
}
