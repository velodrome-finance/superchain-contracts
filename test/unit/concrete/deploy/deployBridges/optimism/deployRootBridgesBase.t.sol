// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

import {DeployRootBridgesBase} from "script/root/deployBridges/deployParameters/optimism/DeployRootBridgesBase.s.sol";

import {RootHLMessageModule} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";
import {RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
import {RootTokenBridge} from "src/root/bridge/RootTokenBridge.sol";

contract DeployRootBridgesBaseTest is BaseFixture {
    using stdStorage for StdStorage;
    using GasLimits for uint256;

    string public addresses;
    DeployRootBridgesBase public deploy;
    DeployRootBridgesBase.RootDeploymentParameters public params;

    // root superchain contracts
    XERC20 public rootXVelo;
    RootTokenBridge public rootTokenBridge;
    RootMessageBridge public rootMessageBridge;
    RootHLMessageModule public rootMessageModule;

    IInterchainSecurityModule public rootIsm;

    function setUp() public override {
        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 130970000});
        deploy = new DeployRootBridgesBase();
        // this runs automatically when you run the script, but must be called manually in the test
        deploy.setUp();

        createUsers();
        stdstore.target(address(deploy)).sig("deployer()").checked_write(users.owner);
        stdstore.target(address(deploy)).sig("isTest()").checked_write(true);
    }

    function testRun() public {
        deploy.run();

        rootXVelo = deploy.rootXVelo();

        rootTokenBridge = deploy.rootTokenBridge();
        rootMessageBridge = deploy.rootMessageBridge();
        rootMessageModule = deploy.rootMessageModule();

        rootIsm = deploy.ism();

        params = deploy.params();

        string memory path = string(abi.encodePacked(vm.projectRoot(), "/deployment-addresses/", params.outputFilename));
        addresses = vm.readFile(path);

        assertNotEq(address(rootXVelo), address(0));

        assertNotEq(address(rootTokenBridge), address(0));
        assertNotEq(address(rootMessageBridge), address(0));
        assertNotEq(address(rootMessageModule), address(0));

        // assertNotEq(address(rootIsm), address(0));

        assertEq(address(rootXVelo), vm.parseJsonAddress(addresses, ".rootXVelo"));
        assertEq(address(rootMessageBridge), vm.parseJsonAddress(addresses, ".rootMessageBridge"));

        assertEq(rootXVelo.symbol(), "XVELO");
        assertEq(rootXVelo.name(), "Superchain Velodrome");
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));

        assertEq(address(rootTokenBridge.lockbox()), address(rootXVelo.lockbox()));
        assertEq(address(rootTokenBridge.erc20()), address(IXERC20Lockbox(rootXVelo.lockbox()).ERC20()));
        assertEq(rootTokenBridge.module(), address(rootMessageModule));
        assertEq(rootTokenBridge.owner(), params.bridgeOwner);
        assertEq(rootTokenBridge.xerc20(), address(rootXVelo));
        assertEq(rootTokenBridge.mailbox(), params.mailbox);
        assertEq(rootTokenBridge.hook(), address(0));
        assertEq(address(rootTokenBridge.securityModule()), address(rootIsm));

        assertEq(rootMessageModule.bridge(), address(rootMessageBridge));
        assertEq(rootMessageModule.xerc20(), address(rootXVelo));
        assertEq(rootMessageModule.mailbox(), params.mailbox);
        assertEq(rootMessageModule.voter(), rootMessageBridge.voter());
        assertEq(rootMessageModule.hook(), address(0));

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
    }
}
