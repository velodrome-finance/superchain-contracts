// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployRootMessage} from "script/deployParameters/optimism/DeployRootMessage.s.sol";
import {RootPool} from "src/mainnet/pools/RootPool.sol";
import {RootPoolFactory} from "src/mainnet/pools/RootPoolFactory.sol";
import {IRootGaugeFactory, RootGaugeFactory} from "src/mainnet/gauges/RootGaugeFactory.sol";
import {IRootMessageBridge, RootMessageBridge} from "src/mainnet/bridge/RootMessageBridge.sol";
import {IMessageSender, RootHLMessageModule} from "src/mainnet/bridge/hyperlane/RootHLMessageModule.sol";
import {EmergencyCouncil} from "src/mainnet/emergencyCouncil/EmergencyCouncil.sol";
import {IRootVotingRewardsFactory, RootVotingRewardsFactory} from "src/mainnet/rewards/RootVotingRewardsFactory.sol";

contract OptimismDeployRootMessageTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployRootMessage public deploy;
    DeployRootMessage.RootDeploymentParameters public params;

    XERC20Factory public rootXFactory;
    XERC20 public rootXVelo;
    XERC20Lockbox public rootLockbox;

    RootPool public rootPoolImplementation;
    RootPoolFactory public rootPoolFactory;
    RootMessageBridge public rootMessageBridge;
    RootHLMessageModule public rootMessageModule;

    EmergencyCouncil public emergencyCouncil;

    RootGaugeFactory public rootGaugeFactory;
    RootVotingRewardsFactory public rootVotingRewardsFactory;

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

        rootPoolImplementation = deploy.poolImplementation();
        rootPoolFactory = deploy.poolFactory();
        rootGaugeFactory = deploy.gaugeFactory();
        rootVotingRewardsFactory = deploy.votingRewardsFactory();

        rootXFactory = deploy.xerc20Factory();
        rootXVelo = deploy.xVelo();
        rootLockbox = deploy.lockbox();

        rootMessageBridge = deploy.messageBridge();
        rootMessageModule = deploy.messageModule();

        emergencyCouncil = deploy.emergencyCouncil();

        params = deploy.params();

        assertNotEq(address(rootGaugeFactory), address(0));

        assertNotEq(address(rootXFactory), address(0));
        assertNotEq(address(rootXVelo), address(0));
        assertNotEq(address(rootLockbox), address(0));

        assertNotEq(address(rootMessageBridge), address(0));
        assertNotEq(address(rootMessageModule), address(0));

        assertNotEq(address(emergencyCouncil), address(0));

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
        assertEq(rootMessageBridge.factoryRegistry(), params.factoryRegistry);
        assertEq(rootMessageBridge.module(), address(rootMessageModule));

        assertEq(rootMessageModule.bridge(), address(rootMessageBridge));
        assertEq(rootMessageModule.mailbox(), params.mailbox);

        assertEq(emergencyCouncil.voter(), params.voter);
        assertEq(emergencyCouncil.votingEscrow(), params.votingEscrow);
        assertEq(emergencyCouncil.bridge(), address(rootMessageBridge));

        assertEq(rootVotingRewardsFactory.bridge(), address(rootMessageBridge));

        assertEq(rootPoolFactory.implementation(), address(rootPoolImplementation));
        assertEq(rootPoolFactory.bridge(), address(rootMessageBridge));

        assertEq(rootGaugeFactory.voter(), params.voter);
        assertEq(rootGaugeFactory.xerc20(), address(rootXVelo));
        assertEq(rootGaugeFactory.lockbox(), address(rootLockbox));
        assertEq(rootGaugeFactory.messageBridge(), address(rootMessageBridge));
        assertEq(rootGaugeFactory.poolFactory(), address(rootPoolFactory));
        assertEq(rootGaugeFactory.votingRewardsFactory(), address(rootVotingRewardsFactory));
    }
}
