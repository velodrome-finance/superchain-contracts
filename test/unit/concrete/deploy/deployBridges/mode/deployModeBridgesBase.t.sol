// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

import {DeployBridgesMode} from "script/deployBridges/deployParameters/mode/DeployBridgesMode.s.sol";

import {ModeFeeSharing} from "src/extensions/ModeFeeSharing.sol";

contract DeployModeBridgesBaseTest is BaseFixture {
    using stdStorage for StdStorage;

    string public addresses;
    DeployBridgesMode public deploy;
    DeployBridgesMode.DeploymentParameters public params;
    DeployBridgesMode.ModeDeploymentParameters public modeParams;

    // leaf superchain contracts
    XERC20 public leafXVelo;
    LeafTokenBridge public leafTokenBridge;
    LeafMessageBridge public leafMessageBridge;
    LeafHLMessageModule public leafMessageModule;

    address constant sfs = 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "mode", blockNumber: 18690000});

        deploy = new DeployBridgesMode();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deploy)).sig("isTest()").checked_write(true);
    }

    function testRun() public {
        deploy.run();

        leafXVelo = deploy.leafXVelo();

        leafTokenBridge = deploy.leafTokenBridge();
        leafMessageBridge = deploy.leafMessageBridge();
        leafMessageModule = deploy.leafMessageModule();

        leafIsm = deploy.ism();

        params = deploy.params();
        modeParams = deploy.modeParams();

        string memory path = string(abi.encodePacked(vm.projectRoot(), "/deployment-addresses/", params.outputFilename));
        addresses = vm.readFile(path);

        assertNotEq(address(leafXVelo), address(0));

        assertNotEq(address(leafTokenBridge), address(0));
        assertNotEq(address(leafMessageBridge), address(0));
        assertNotEq(address(leafMessageModule), address(0));

        // assertNotEq(address(leafIsm), address(0));

        assertEq(address(leafXVelo), vm.parseJsonAddress(addresses, ".leafXVelo"));
        assertEq(address(leafMessageBridge), vm.parseJsonAddress(addresses, ".leafMessageBridge"));

        assertEq(leafXVelo.symbol(), "XVELO");
        assertEq(leafXVelo.name(), "Superchain Velodrome");
        assertEq(leafMessageBridge.xerc20(), address(leafXVelo));

        assertEq(leafTokenBridge.owner(), params.bridgeOwner);
        assertEq(leafTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafTokenBridge.mailbox(), params.mailbox);
        assertEq(address(leafTokenBridge.securityModule()), address(leafIsm));
        assertEq(ModeFeeSharing(address(leafTokenBridge)).sfs(), sfs);
        assertEq(ModeFeeSharing(address(leafTokenBridge)).tokenId(), 603);

        assertEq(leafMessageModule.owner(), params.moduleOwner);
        assertEq(leafMessageModule.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.xerc20(), address(leafXVelo));
        assertEq(leafMessageModule.voter(), leafMessageBridge.voter());
        assertEq(leafMessageModule.mailbox(), params.mailbox);
        assertEq(address(leafMessageModule.securityModule()), address(leafIsm));
    }
}
