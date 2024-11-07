// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";
import {DeployPartialBase} from "script/deployPartial/deployParameters/mode/DeployPartialBase.sol";

import {ModeFeeSharing} from "src/extensions/ModeFeeSharing.sol";

contract ModeDeployPartialBaseTest is BaseFixture {
    using stdStorage for StdStorage;

    string public addresses;
    DeployPartialBase public deploy;
    DeployPartialBase.DeploymentParameters public params;
    DeployPartialBase.ModeDeploymentParameters public modeParams;

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

    address constant sfs = 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        deploy = new DeployPartialBase();
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

        string memory path = string(abi.encodePacked(vm.projectRoot(), "/deployment-addresses/", params.inputFilename));
        addresses = vm.readFile(path);

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

        assertEq(address(leafPoolImplementation), vm.parseJsonAddress(addresses, ".poolImplementation"));
        assertEq(address(leafPoolFactory), vm.parseJsonAddress(addresses, ".poolFactory"));
        assertEq(address(leafRouter), vm.parseJsonAddress(addresses, ".router"));

        assertEq(leafPoolFactory.implementation(), address(leafPoolImplementation));
        assertEq(leafPoolFactory.isPaused(), false);
        assertEq(leafPoolFactory.stableFee(), 5);
        assertEq(leafPoolFactory.volatileFee(), 30);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).sfs(), sfs);
        assertEq(ModeFeeSharing(address(leafPoolFactory)).tokenId(), 530);

        assertEq(leafGaugeFactory.voter(), address(leafVoter));
        assertEq(leafGaugeFactory.xerc20(), address(leafXVelo));
        assertEq(leafGaugeFactory.bridge(), address(leafMessageBridge));

        assertEq(leafVotingRewardsFactory.voter(), address(leafVoter));
        assertEq(leafVotingRewardsFactory.bridge(), address(leafMessageBridge));

        assertEq(leafVoter.bridge(), address(leafMessageBridge));
        assertEq(ModeFeeSharing(address(leafVoter)).sfs(), sfs);
        assertEq(ModeFeeSharing(address(leafVoter)).tokenId(), 553);

        assertEq(leafXFactory.owner(), params.tokenAdmin);
        assertEq(leafXFactory.name(), "Superchain Velodrome");
        assertEq(leafXFactory.symbol(), "XVELO");
        assertEq(leafXFactory.XERC20_ENTROPY(), XERC20_ENTROPY);
        assertEq(leafXFactory.LOCKBOX_ENTROPY(), LOCKBOX_ENTROPY);
        assertEq(leafXFactory.owner(), params.tokenAdmin);
        assertEq(leafXFactory.erc20(), address(0));

        assertEq(leafXVelo.name(), "Superchain Velodrome");
        assertEq(leafXVelo.symbol(), "XVELO");
        assertEq(leafXVelo.owner(), params.tokenAdmin);
        assertEq(leafXVelo.lockbox(), address(0));

        assertEq(leafTokenBridge.owner(), params.bridgeOwner);
        assertEq(leafTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafTokenBridge.mailbox(), params.mailbox);
        assertEq(address(leafTokenBridge.securityModule()), address(leafIsm));
        assertEq(ModeFeeSharing(address(leafTokenBridge)).sfs(), sfs);
        assertEq(ModeFeeSharing(address(leafTokenBridge)).tokenId(), 555);

        assertEq(leafMessageBridge.owner(), params.bridgeOwner);
        assertEq(leafMessageBridge.xerc20(), address(leafXVelo));
        assertEq(leafMessageBridge.voter(), address(leafVoter));
        assertEq(leafMessageBridge.module(), address(leafMessageModule));
        assertEq(ModeFeeSharing(address(leafMessageBridge)).sfs(), sfs);
        assertEq(ModeFeeSharing(address(leafMessageBridge)).tokenId(), 554);

        assertEq(leafMessageModule.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.xerc20(), address(leafXVelo));
        assertEq(leafMessageModule.voter(), address(leafVoter));
        assertEq(leafMessageModule.mailbox(), params.mailbox);
        assertEq(address(leafMessageModule.securityModule()), address(leafIsm));

        assertEq(leafRouter.factory(), address(leafPoolFactory));
        assertEq(leafRouter.poolImplementation(), address(leafPoolImplementation));
        assertEq(ModeFeeSharing(address(leafRouter)).tokenId(), 531);
    }
}