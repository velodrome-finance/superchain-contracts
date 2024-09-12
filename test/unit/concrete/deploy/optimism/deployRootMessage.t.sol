// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployRootMessage} from "script/deployParameters/optimism/DeployRootMessage.s.sol";
import {IRootGaugeFactory, RootGaugeFactory} from "src/mainnet/gauges/RootGaugeFactory.sol";
import {IRootMessageBridge, RootMessageBridge} from "src/mainnet/bridge/RootMessageBridge.sol";
import {IMessageSender, RootHLMessageModule} from "src/mainnet/bridge/hyperlane/RootHLMessageModule.sol";

contract OptimismDeployRootMessageTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployRootMessage public deploy;
    DeployRootMessage.RootDeploymentParameters public params;

    XERC20Factory public rootXFactory;
    XERC20 public rootXVelo;
    XERC20Lockbox public rootLockbox;

    RootMessageBridge public rootMessageBridge;
    RootHLMessageModule public rootMessageModule;

    RootGaugeFactory public rootGaugeFactory;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 123316800});

        deploy = new DeployRootMessage();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deploy)).sig("isTest()").checked_write(true);
    }

    function testRun() public {
        deploy.run();

        rootGaugeFactory = deploy.gaugeFactory();

        rootXFactory = deploy.xerc20Factory();
        rootXVelo = deploy.xVelo();
        rootLockbox = deploy.lockbox();

        rootMessageBridge = deploy.messageBridge();
        rootMessageModule = deploy.messageModule();

        params = deploy.params();

        assertNotEq(address(rootGaugeFactory), address(0));

        assertNotEq(address(rootXFactory), address(0));
        assertNotEq(address(rootXVelo), address(0));
        assertNotEq(address(rootLockbox), address(0));

        assertNotEq(address(rootMessageBridge), address(0));
        assertNotEq(address(rootMessageModule), address(0));

        assertEq(address(rootXFactory.createx()), address(cx));
        assertEq(rootXFactory.owner(), params.tokenAdmin);
        assertEq(rootXFactory.name(), "Superchain Velodrome");
        assertEq(rootXFactory.symbol(), "XVELO");
        assertEq(rootXFactory.XERC20_ENTROPY(), XERC20_ENTROPY);
        assertEq(rootXFactory.LOCKBOX_ENTROPY(), LOCKBOX_ENTROPY);
        assertEq(rootXFactory.owner(), params.tokenAdmin);

        assertEq(rootXVelo.name(), "Superchain Velodrome");
        assertEq(rootXVelo.symbol(), "XVELO");
        assertEq(rootXVelo.owner(), params.tokenAdmin);
        assertEq(rootXVelo.lockbox(), address(rootLockbox));

        assertEq(address(rootLockbox.XERC20()), address(rootXVelo));
        assertEq(address(rootLockbox.ERC20()), params.velo);

        assertEq(rootMessageBridge.owner(), params.bridgeOwner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), params.voter);
        assertEq(rootMessageBridge.gaugeFactory(), address(rootGaugeFactory));
        assertEq(rootMessageBridge.module(), address(rootMessageModule));

        assertEq(rootMessageModule.bridge(), address(rootMessageBridge));
        assertEq(rootMessageModule.mailbox(), params.mailbox);

        assertEq(rootGaugeFactory.voter(), params.voter);
        assertEq(rootGaugeFactory.xerc20(), address(rootXVelo));
        assertEq(rootGaugeFactory.lockbox(), address(rootLockbox));
        assertEq(rootGaugeFactory.messageBridge(), address(rootMessageBridge));
    }
}
