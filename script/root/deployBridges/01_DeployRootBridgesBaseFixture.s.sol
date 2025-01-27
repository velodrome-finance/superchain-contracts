// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../DeployFixture.sol";

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {RootHLMessageModule} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";
import {RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
import {RootEscrowTokenBridge} from "src/root/bridge/RootEscrowTokenBridge.sol";
import {RootTokenBridge} from "src/root/bridge/RootTokenBridge.sol";

import {XERC20} from "src/xerc20/XERC20.sol";

abstract contract DeployRootBridgesBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    struct RootDeploymentParameters {
        address bridgeOwner;
        address mailbox;
        string outputFilename;
    }

    // root superchain contracts
    XERC20 public rootXVelo;
    RootEscrowTokenBridge public rootTokenBridge;
    RootMessageBridge public rootMessageBridge;
    RootHLMessageModule public rootMessageModule;

    IInterchainSecurityModule public ism;

    string public addresses;
    RootDeploymentParameters internal _params;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    function setUp() public virtual override {
        string memory root = vm.projectRoot();
        // @dev Reading addresses from old output in `outputFilename`
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        addresses = vm.readFile(path);

        /// @dev Use contracts from existing deployment
        rootXVelo = XERC20(vm.parseJsonAddress(addresses, ".rootXVelo"));
        rootMessageBridge = RootMessageBridge(payable(vm.parseJsonAddress(addresses, ".rootMessageBridge")));
    }

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        rootMessageModule = RootHLMessageModule(
            cx.deployCreate3({
                salt: HL_MESSAGE_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootHLMessageModule).creationCode,
                    abi.encode(
                        address(rootMessageBridge), // root message bridge
                        _params.mailbox // root mailbox
                    )
                )
            })
        );
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY_V2, _output: address(rootMessageModule)});

        rootTokenBridge = RootEscrowTokenBridge(
            cx.deployCreate3({
                salt: TOKEN_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootEscrowTokenBridge).creationCode,
                    abi.encode(
                        _params.bridgeOwner, // bridge owner
                        address(rootXVelo), // xerc20 address
                        address(rootMessageModule), // message module
                        address(ism) // security module
                    )
                )
            })
        );
        checkAddress({_entropy: TOKEN_BRIDGE_ENTROPY_V2, _output: address(rootTokenBridge)});
    }

    function params() external view returns (RootDeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("rootTokenBridge: ", address(rootTokenBridge));
        console.log("rootMessageModule: ", address(rootMessageModule));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev Update addresses in original deployment file
        vm.writeJson(vm.toString(address(rootTokenBridge)), path, ".rootTokenBridge");
        vm.writeJson(vm.toString(address(rootMessageModule)), path, ".rootMessageModule");
    }
}
