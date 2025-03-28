// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import "test/BaseFixture.sol";
import {DeployBase} from "script/deployParameters/mode/DeployBase.s.sol";
import {DeployRootBase} from "script/deployParameters/optimism/DeployRootBase.s.sol";

import {RootVotingRewardsFactory} from "src/root/rewards/RootVotingRewardsFactory.sol";
import {RootGaugeFactory} from "src/root/gauges/RootGaugeFactory.sol";
import {RootPoolFactory} from "src/root/pools/RootPoolFactory.sol";
import {RootPool} from "src/root/pools/RootPool.sol";

import {EmergencyCouncil} from "src/root/emergencyCouncil/EmergencyCouncil.sol";
import {RootHLMessageModule} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";
import {RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
import {RootTokenBridge} from "src/root/bridge/RootTokenBridge.sol";

import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";

contract CreateXDeployTest is BaseFixture {
    using stdStorage for StdStorage;

    struct RootDeployment {
        RootPool poolImplementation;
        RootPoolFactory poolFactory;
        RootGaugeFactory gaugeFactory;
        RootVotingRewardsFactory votingRewardsFactory;
        XERC20Factory xerc20Factory;
        XERC20 xVelo;
        XERC20Lockbox lockbox;
        RootTokenBridge tokenBridge;
        RootMessageBridge messageBridge;
        RootHLMessageModule messageModule;
        EmergencyCouncil emergencyCouncil;
        IInterchainSecurityModule ism;
    }

    struct LeafDeployment {
        ModePool poolImplementation;
        ModePoolFactory poolFactory;
        LeafGaugeFactory gaugeFactory;
        VotingRewardsFactory votingRewardsFactory;
        XERC20Factory xerc20Factory;
        XERC20 xVelo;
        LeafVoter voter;
        LeafTokenBridge tokenBridge;
        LeafMessageBridge messageBridge;
        LeafHLMessageModule messageModule;
        ModeRouter router;
        IInterchainSecurityModule ism;
    }

    DeployRootBase.RootDeploymentParameters public rootParams;
    DeployRootBase public rootDeploy;
    RootDeployment public root;
    uint256 public rootFork;

    DeployBase public leafDeploy;
    LeafDeployment public leaf;
    uint256 public leafFork;

    function setUp() public override {
        rootFork = vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 123316800});
        rootDeploy = new DeployRootBase();
        // this runs automatically when you run the script, but must be called manually in the test
        rootDeploy.setUp();

        createUsers();
        stdstore.target(address(rootDeploy)).sig("deployer()").checked_write(users.deployer);
        stdstore.target(address(rootDeploy)).sig("isTest()").checked_write(true);

        leafFork = vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        leafDeploy = new DeployBase();
        // this runs automatically when you run the script, but must be called manually in the test
        leafDeploy.setUp();

        stdstore.target(address(leafDeploy)).sig("deployer()").checked_write(users.deployer);
        stdstore.target(address(leafDeploy)).sig("isTest()").checked_write(true);

        vm.selectFork({forkId: rootFork});
    }

    function test_CreateXDeployments() public {
        /// Deploy Root contracts
        rootDeploy.run();
        root = RootDeployment({
            poolImplementation: rootDeploy.rootPoolImplementation(),
            poolFactory: rootDeploy.rootPoolFactory(),
            gaugeFactory: rootDeploy.rootGaugeFactory(),
            votingRewardsFactory: rootDeploy.rootVotingRewardsFactory(),
            xerc20Factory: rootDeploy.rootXFactory(),
            xVelo: rootDeploy.rootXVelo(),
            lockbox: rootDeploy.rootLockbox(),
            tokenBridge: rootDeploy.rootTokenBridge(),
            messageBridge: rootDeploy.rootMessageBridge(),
            messageModule: rootDeploy.rootMessageModule(),
            emergencyCouncil: rootDeploy.emergencyCouncil(),
            ism: rootDeploy.ism()
        });

        assertNotEq(address(root.poolImplementation), address(0));
        assertNotEq(address(root.poolFactory), address(0));
        assertNotEq(address(root.gaugeFactory), address(0));
        assertNotEq(address(root.votingRewardsFactory), address(0));
        assertNotEq(address(root.xerc20Factory), address(0));
        assertNotEq(address(root.xVelo), address(0));
        assertNotEq(address(root.lockbox), address(0));
        assertNotEq(address(root.tokenBridge), address(0));
        assertNotEq(address(root.messageBridge), address(0));
        assertNotEq(address(root.messageModule), address(0));
        // assertNotEq(address(root.ism), address(0));
        assertNotEq(address(root.emergencyCouncil), address(0));

        vm.selectFork({forkId: leafFork});

        /// Deploy Leaf contracts
        leafDeploy.run();
        leaf = LeafDeployment({
            poolImplementation: ModePool(address(leafDeploy.leafPoolImplementation())),
            poolFactory: ModePoolFactory(address(leafDeploy.leafPoolFactory())),
            gaugeFactory: leafDeploy.leafGaugeFactory(),
            votingRewardsFactory: leafDeploy.leafVotingRewardsFactory(),
            xerc20Factory: leafDeploy.leafXFactory(),
            xVelo: leafDeploy.leafXVelo(),
            voter: leafDeploy.leafVoter(),
            tokenBridge: leafDeploy.leafTokenBridge(),
            messageBridge: leafDeploy.leafMessageBridge(),
            messageModule: leafDeploy.leafMessageModule(),
            router: ModeRouter(payable(leafDeploy.leafRouter())),
            ism: leafDeploy.ism()
        });

        assertNotEq(address(leaf.poolImplementation), address(0));
        assertNotEq(address(leaf.poolFactory), address(0));
        assertNotEq(address(leaf.gaugeFactory), address(0));
        assertNotEq(address(leaf.votingRewardsFactory), address(0));
        assertNotEq(address(leaf.voter), address(0));
        assertNotEq(address(leaf.xerc20Factory), address(0));
        assertNotEq(address(leaf.xVelo), address(0));
        assertNotEq(address(leaf.tokenBridge), address(0));
        assertNotEq(address(leaf.messageBridge), address(0));
        assertNotEq(address(leaf.messageModule), address(0));
        // assertNotEq(address(leaf.ism), address(0));
        assertNotEq(address(leaf.router), address(0));

        /// Verify CreateX dependencies
        assertEq(address(root.poolImplementation), address(leaf.poolImplementation));
        assertEq(address(root.poolFactory), address(leaf.poolFactory));
        assertEq(address(root.gaugeFactory), address(leaf.gaugeFactory));
        assertEq(address(root.votingRewardsFactory), address(leaf.votingRewardsFactory));

        assertEq(address(root.xerc20Factory), address(leaf.xerc20Factory));
        assertEq(address(root.xVelo), address(leaf.xVelo));

        assertEq(address(root.ism), address(leaf.ism));
        assertEq(address(root.tokenBridge), address(leaf.tokenBridge));
        assertEq(address(root.messageBridge), address(leaf.messageBridge));
        assertEq(address(root.messageModule), address(leaf.messageModule));

        assertNotEq(address(root.lockbox), leaf.xVelo.lockbox());
        assertNotEq(rootParams.voter, address(leaf.voter));
    }
}
