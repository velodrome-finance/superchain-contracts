// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployBase} from "script/deployParameters/mode/DeployBase.s.sol";

import {ModeFeeSharing} from "src/extensions/ModeFeeSharing.sol";

contract ModeDeployBaseTest is BaseFixture {
    using stdStorage for StdStorage;

    DeployBase public deploy;
    DeployBase.DeploymentParameters public params;
    DeployBase.ModeDeploymentParameters public modeParams;

    // leaf superchain contracts
    XERC20Factory public leafXFactory;
    XERC20 public leafXVelo;
    Router public leafRouter;
    TokenBridge public leafTokenBridge;
    LeafMessageBridge public leafMessageBridge;
    LeafHLMessageModule public leafMessageModule;

    // leaf-only contracts
    PoolFactory public leafPoolFactory;
    Pool public leafPoolImplementation;
    LeafGaugeFactory public leafGaugeFactory;
    LeafVoter public leafVoter;
    VotingRewardsFactory public leafVotingRewardsFactory;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        deploy = new DeployBase();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deploy)).sig("isTest()").checked_write(true);
    }

    function testRun() public {
        deploy.run();

        leafPoolImplementation = deploy.leafPoolImplementation();
        leafPoolFactory = deploy.leafPoolFactory();
        leafGaugeFactory = deploy.leafGaugeFactory();
        leafVotingRewardsFactory = deploy.leafVotingRewardsFactory();
        leafVoter = deploy.leafVoter();

        leafXFactory = deploy.leafXFactory();
        leafXVelo = deploy.leafXVelo();

        leafTokenBridge = deploy.leafTokenBridge();
        leafMessageBridge = deploy.leafMessageBridge();
        leafMessageModule = deploy.leafMessageModule();

        leafIsm = deploy.ism();
        leafRouter = deploy.leafRouter();

        params = deploy.params();
        modeParams = deploy.modeParams();

        assertNotEq(address(leafPoolImplementation), address(0));
        assertNotEq(address(leafPoolFactory), address(0));

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

        assertEq(leafPoolFactory.implementation(), address(leafPoolImplementation));
        assertEq(leafPoolFactory.poolAdmin(), params.poolAdmin);
        assertEq(leafPoolFactory.pauser(), params.pauser);
        assertEq(leafPoolFactory.feeManager(), params.feeManager);
        assertEq(leafPoolFactory.isPaused(), false);
        assertEq(leafPoolFactory.stableFee(), 5);
        assertEq(leafPoolFactory.volatileFee(), 30);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).tokenId(), 553);

        assertEq(leafGaugeFactory.voter(), address(leafVoter));
        assertEq(leafGaugeFactory.xerc20(), address(leafXVelo));
        assertEq(leafGaugeFactory.bridge(), address(leafMessageBridge));

        assertEq(leafVotingRewardsFactory.voter(), address(leafVoter));
        assertEq(leafVotingRewardsFactory.bridge(), address(leafMessageBridge));

        assertEq(leafVoter.bridge(), address(leafMessageBridge));
        assertEq(ModeFeeSharing(address(leafVoter)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(leafVoter)).tokenId(), 556);

        assertEq(leafXFactory.owner(), params.tokenAdmin);
        assertEq(leafXFactory.name(), "Superchain Velodrome");
        assertEq(leafXFactory.symbol(), "XVELO");
        assertEq(leafXFactory.XERC20_ENTROPY(), XERC20_ENTROPY);
        assertEq(leafXFactory.LOCKBOX_ENTROPY(), LOCKBOX_ENTROPY);
        assertEq(leafXFactory.owner(), params.tokenAdmin);
        assertEq(leafXFactory.erc20(), address(0));
        assertEq(ModeFeeSharing(address(leafXFactory)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(leafXFactory)).tokenId(), 555);

        assertEq(leafXVelo.name(), "Superchain Velodrome");
        assertEq(leafXVelo.symbol(), "XVELO");
        assertEq(leafXVelo.owner(), params.tokenAdmin);
        assertEq(leafXVelo.lockbox(), address(0));

        assertEq(leafTokenBridge.owner(), params.bridgeOwner);
        assertEq(leafTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafTokenBridge.mailbox(), params.mailbox);
        assertEq(address(leafTokenBridge.securityModule()), address(leafIsm));
        assertEq(ModeFeeSharing(address(leafTokenBridge)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(leafTokenBridge)).tokenId(), 558);

        assertEq(leafMessageBridge.owner(), params.bridgeOwner);
        assertEq(leafMessageBridge.xerc20(), address(leafXVelo));
        assertEq(leafMessageBridge.voter(), address(leafVoter));
        assertEq(leafMessageBridge.module(), address(leafMessageModule));
        assertEq(ModeFeeSharing(address(leafMessageBridge)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(leafMessageBridge)).tokenId(), 557);

        assertEq(leafMessageModule.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.xerc20(), address(leafXVelo));
        assertEq(leafMessageModule.voter(), address(leafVoter));
        assertEq(leafMessageModule.mailbox(), params.mailbox);
        assertEq(address(leafMessageModule.securityModule()), address(leafIsm));

        assertEq(leafRouter.factory(), address(leafPoolFactory));
        assertEq(leafRouter.poolImplementation(), address(leafPoolImplementation));
        assertEq(address(leafRouter.weth()), params.weth);
        assertEq(ModeFeeSharing(address(leafRouter)).sfs(), modeParams.sfs);
        assertEq(ModeFeeSharing(address(leafRouter)).tokenId(), 554);
    }
}
