// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {LeafHLMessageModule} from "src/bridge/hyperlane/LeafHLMessageModule.sol";
import {LeafMessageBridge} from "src/bridge/LeafMessageBridge.sol";
import {LeafEscrowTokenBridge} from "src/bridge/LeafEscrowTokenBridge.sol";

import {XERC20} from "src/xerc20/XERC20.sol";

abstract contract DeployBridgesBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address moduleOwner;
        address bridgeOwner;
        address mailbox;
        string outputFilename;
    }

    // leaf superchain contracts
    XERC20 public leafXVelo;
    LeafEscrowTokenBridge public leafTokenBridge;
    LeafMessageBridge public leafMessageBridge;
    LeafHLMessageModule public leafMessageModule;

    IInterchainSecurityModule public ism;

    DeploymentParameters internal _params;
    string public addresses;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    function setUp() public virtual override {
        string memory root = vm.projectRoot();
        // @dev Reading addresses from old output in `outputFilename`
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        addresses = vm.readFile(path);

        /// @dev Use contracts from existing deployment
        leafXVelo = XERC20(vm.parseJsonAddress(addresses, ".leafXVelo"));
        leafMessageBridge = LeafMessageBridge(vm.parseJsonAddress(addresses, ".leafMessageBridge"));
    }

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        leafTokenBridge = LeafEscrowTokenBridge(
            cx.deployCreate3({
                salt: TOKEN_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafEscrowTokenBridge).creationCode,
                    abi.encode(
                        _params.bridgeOwner, // bridge owner
                        address(leafXVelo), // xerc20 address
                        _params.mailbox, // mailbox
                        address(ism) // security module
                    )
                )
            })
        );
        checkAddress({_entropy: TOKEN_BRIDGE_ENTROPY_V2, _output: address(leafTokenBridge)});

        leafMessageModule = LeafHLMessageModule(
            cx.deployCreate3({
                salt: HL_MESSAGE_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafHLMessageModule).creationCode,
                    abi.encode(
                        _params.moduleOwner, // leaf module owner
                        address(leafMessageBridge), // leaf message bridge
                        _params.mailbox, // leaf mailbox
                        address(ism) // leaf security module
                    )
                )
            })
        );
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY_V2, _output: address(leafMessageModule)});
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("leafTokenBridge: ", address(leafTokenBridge));
        console.log("leafMessageModule: ", address(leafMessageModule));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev Update addresses in original deployment file
        vm.writeJson(vm.toString(address(leafTokenBridge)), path, ".leafTokenBridge");
        vm.writeJson(vm.toString(address(leafMessageModule)), path, ".leafMessageModule");
    }
}
