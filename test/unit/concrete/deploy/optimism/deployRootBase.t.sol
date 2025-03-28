// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import "test/BaseFixture.sol";
import {DeployRootBase} from "script/deployParameters/optimism/DeployRootBase.s.sol";

import {RootPool} from "src/root/pools/RootPool.sol";
import {IVoter} from "src/interfaces/external/IVoter.sol";
import {IMinter} from "src/interfaces/external/IMinter.sol";
import {RootPoolFactory} from "src/root/pools/RootPoolFactory.sol";
import {RootGaugeFactory} from "src/root/gauges/RootGaugeFactory.sol";
import {RootVotingRewardsFactory} from "src/root/rewards/RootVotingRewardsFactory.sol";

import {RootTokenBridge} from "src/root/bridge/RootTokenBridge.sol";
import {RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
import {PaymasterVault} from "src/root/bridge/hyperlane/PaymasterVault.sol";
import {EmergencyCouncil} from "src/root/emergencyCouncil/EmergencyCouncil.sol";
import {RootHLMessageModule} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";

contract OptimismDeployRootBaseTest is BaseFixture {
    using stdStorage for StdStorage;
    using GasLimits for uint256;

    DeployRootBase public deploy;
    IInterchainSecurityModule public rootIsm;
    DeployRootBase.RootDeploymentParameters public params;

    RootPool public rootPoolImplementation;
    RootPoolFactory public rootPoolFactory;
    RootGaugeFactory public rootGaugeFactory;
    RootVotingRewardsFactory public rootVotingRewardsFactory;

    XERC20Factory public rootXFactory;
    XERC20 public rootXVelo;
    XERC20Lockbox public rootLockbox;

    RootTokenBridge public rootTokenBridge;
    PaymasterVault public rootTokenBridgeVault;
    RootMessageBridge public rootMessageBridge;
    RootHLMessageModule public rootMessageModule;
    PaymasterVault public rootModuleVault;

    EmergencyCouncil public emergencyCouncil;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 123316800});

        deploy = new DeployRootBase();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deploy)).sig("isTest()").checked_write(true);
    }

    function testRun() public {
        deploy.run();

        rootPoolImplementation = deploy.rootPoolImplementation();
        rootPoolFactory = deploy.rootPoolFactory();
        rootGaugeFactory = deploy.rootGaugeFactory();
        rootVotingRewardsFactory = deploy.rootVotingRewardsFactory();

        rootXFactory = deploy.rootXFactory();
        rootXVelo = deploy.rootXVelo();
        rootLockbox = deploy.rootLockbox();

        rootTokenBridge = deploy.rootTokenBridge();
        rootTokenBridgeVault = deploy.rootTokenBridgeVault();
        rootMessageBridge = deploy.rootMessageBridge();
        rootMessageModule = deploy.rootMessageModule();
        rootModuleVault = deploy.rootModuleVault();

        emergencyCouncil = deploy.emergencyCouncil();

        rootIsm = deploy.ism();
        params = deploy.params();

        assertNotEq(address(rootPoolImplementation), address(0));
        assertNotEq(address(rootPoolFactory), address(0));
        assertNotEq(address(rootGaugeFactory), address(0));
        assertNotEq(address(rootVotingRewardsFactory), address(0));

        assertNotEq(address(rootXFactory), address(0));
        assertNotEq(address(rootXVelo), address(0));
        assertNotEq(address(rootLockbox), address(0));

        assertNotEq(address(rootTokenBridge), address(0));
        assertNotEq(address(rootTokenBridgeVault), address(0));
        assertNotEq(address(rootMessageBridge), address(0));
        assertNotEq(address(rootMessageModule), address(0));
        assertNotEq(address(rootModuleVault), address(0));

        // assertNotEq(address(ism), address(0));
        assertNotEq(address(emergencyCouncil), address(0));

        assertEq(rootPoolFactory.implementation(), address(rootPoolImplementation));
        assertEq(rootPoolFactory.bridge(), address(rootMessageBridge));

        assertEq(rootXFactory.owner(), params.tokenAdmin);
        assertEq(rootXFactory.name(), "Superchain Velodrome");
        assertEq(rootXFactory.symbol(), "XVELO");
        assertEq(rootXFactory.erc20(), params.velo);
        assertEq(rootXFactory.XERC20_ENTROPY(), XERC20_ENTROPY);
        assertEq(rootXFactory.LOCKBOX_ENTROPY(), LOCKBOX_ENTROPY);

        assertEq(rootXVelo.name(), "Superchain Velodrome");
        assertEq(rootXVelo.symbol(), "XVELO");
        assertEq(rootXVelo.owner(), params.tokenAdmin);
        assertEq(rootXVelo.lockbox(), address(rootLockbox));

        assertEq(address(rootLockbox.XERC20()), address(rootXVelo));
        assertEq(address(rootLockbox.ERC20()), params.velo);

        assertEq(rootMessageBridge.owner(), params.bridgeOwner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), params.voter);
        assertEq(rootMessageBridge.factoryRegistry(), IVoter(params.voter).factoryRegistry());
        assertEq(rootMessageBridge.weth(), params.weth);

        assertEq(rootMessageModule.bridge(), address(rootMessageBridge));
        assertEq(rootMessageModule.xerc20(), address(rootXVelo));
        assertEq(rootMessageModule.mailbox(), params.mailbox);
        assertEq(rootMessageModule.owner(), params.bridgeOwner);
        assertEq(rootMessageModule.gasLimit(Commands.DEPOSIT), Commands.DEPOSIT.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.WITHDRAW), Commands.WITHDRAW.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.GET_INCENTIVES), Commands.GET_INCENTIVES.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.GET_FEES), Commands.GET_FEES.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.CREATE_GAUGE), Commands.CREATE_GAUGE.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.NOTIFY), Commands.NOTIFY.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.NOTIFY_WITHOUT_CLAIM), Commands.NOTIFY_WITHOUT_CLAIM.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.KILL_GAUGE), Commands.KILL_GAUGE.gasLimit());
        assertEq(rootMessageModule.gasLimit(Commands.REVIVE_GAUGE), Commands.REVIVE_GAUGE.gasLimit());

        assertEq(rootModuleVault.owner(), params.bridgeOwner);

        assertEq(rootTokenBridge.owner(), params.bridgeOwner);
        assertEq(rootTokenBridge.xerc20(), address(rootXVelo));
        assertEq(rootTokenBridge.mailbox(), address(params.mailbox));
        assertEq(address(rootTokenBridge.securityModule()), address(rootIsm));

        assertEq(rootTokenBridgeVault.owner(), params.bridgeOwner);

        assertEq(rootVotingRewardsFactory.bridge(), address(rootMessageBridge));

        address minter = IVoter(params.voter).minter();
        assertEq(rootGaugeFactory.voter(), params.voter);
        assertEq(rootGaugeFactory.xerc20(), address(rootXVelo));
        assertEq(rootGaugeFactory.lockbox(), address(rootLockbox));
        assertEq(rootGaugeFactory.messageBridge(), address(rootMessageBridge));
        assertEq(rootGaugeFactory.poolFactory(), address(rootPoolFactory));
        assertEq(rootGaugeFactory.votingRewardsFactory(), address(rootVotingRewardsFactory));
        assertEq(rootGaugeFactory.notifyAdmin(), params.notifyAdmin);
        assertEq(rootGaugeFactory.emissionAdmin(), params.emissionAdmin);
        assertEq(rootGaugeFactory.defaultCap(), params.defaultCap);
        assertEq(rootGaugeFactory.minter(), minter);
        assertEq(rootGaugeFactory.rewardToken(), IMinter(minter).velo());

        assertEq(emergencyCouncil.owner(), params.emergencyCouncilOwner);
        assertEq(emergencyCouncil.voter(), params.voter);
        assertEq(emergencyCouncil.votingEscrow(), IVoter(params.voter).ve());
    }
}
