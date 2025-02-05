// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../DeployFixture.sol";

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {RootHLMessageModule} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";
import {PaymasterVault} from "src/root/bridge/hyperlane/PaymasterVault.sol";
import {RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
import {RootEscrowTokenBridge} from "src/root/bridge/RootEscrowTokenBridge.sol";
import {RootTokenBridge} from "src/root/bridge/RootTokenBridge.sol";

import {XERC20} from "src/xerc20/XERC20.sol";

import {Commands} from "src/libraries/Commands.sol";
import {GasLimits} from "src/libraries/GasLimits.sol";

abstract contract DeployRootBridgesBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;
    using GasLimits for uint256;

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
    PaymasterVault public rootTokenBridgeVault;
    PaymasterVault public rootModuleVault;

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

        rootMessageModule =
            RootHLMessageModule(payable(HL_MESSAGE_BRIDGE_ENTROPY_V2.computeCreate3Address({_deployer: _deployer})));
        rootModuleVault = new PaymasterVault({_owner: _params.bridgeOwner, _vaultManager: address(rootMessageModule)});
        rootMessageModule = RootHLMessageModule(
            payable(
                cx.deployCreate3({
                    salt: HL_MESSAGE_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(RootHLMessageModule).creationCode,
                        abi.encode(
                            address(rootMessageBridge), // root message bridge
                            _params.mailbox, // root mailbox
                            address(rootModuleVault), // module paymaster vault
                            defaultCommands, // commands for gas router
                            defaultGasLimits // gas limits for gas router
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY_V2, _output: address(rootMessageModule)});

        rootTokenBridge =
            RootEscrowTokenBridge(payable(TOKEN_BRIDGE_ENTROPY_V2.computeCreate3Address({_deployer: _deployer})));
        rootTokenBridgeVault =
            new PaymasterVault({_owner: _params.bridgeOwner, _vaultManager: address(rootTokenBridge)});
        rootTokenBridge = RootEscrowTokenBridge(
            payable(
                cx.deployCreate3({
                    salt: TOKEN_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(RootEscrowTokenBridge).creationCode,
                        abi.encode(
                            _params.bridgeOwner, // bridge owner
                            address(rootXVelo), // xerc20 address
                            address(rootMessageModule), // message module
                            address(rootTokenBridgeVault), // token bridge paymaster vault
                            address(ism) // security module
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: TOKEN_BRIDGE_ENTROPY_V2, _output: address(rootTokenBridge)});
    }

    function params() external view returns (RootDeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("rootTokenBridge: ", address(rootTokenBridge));
        console.log("rootTokenBridgeVault: ", address(rootTokenBridgeVault));
        console.log("rootMessageModule: ", address(rootMessageModule));
        console.log("rootModuleVault: ", address(rootModuleVault));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev Update addresses in original deployment file
        vm.writeJson(vm.toString(address(rootTokenBridge)), path, ".rootTokenBridge");
        vm.writeJson(vm.toString(address(rootTokenBridgeVault)), path, ".rootTokenBridgeVault");
        vm.writeJson(vm.toString(address(rootMessageModule)), path, ".rootMessageModule");
        vm.writeJson(vm.toString(address(rootModuleVault)), path, ".rootModuleVault");
    }
}
