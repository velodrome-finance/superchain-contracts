// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {RootVotingRewardsFactory} from "src/root/rewards/RootVotingRewardsFactory.sol";
import {RootGaugeFactory} from "src/root/gauges/RootGaugeFactory.sol";
import {RootPoolFactory} from "src/root/pools/RootPoolFactory.sol";
import {RootPool} from "src/root/pools/RootPool.sol";

import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {XERC20} from "src/xerc20/XERC20.sol";

import {EmergencyCouncil} from "src/root/emergencyCouncil/EmergencyCouncil.sol";
import {RootHLMessageModule} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";
import {PaymasterVault} from "src/root/bridge/hyperlane/PaymasterVault.sol";
import {RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
import {RootEscrowTokenBridge} from "src/root/bridge/RootEscrowTokenBridge.sol";

import {Commands} from "src/libraries/Commands.sol";
import {GasLimits} from "src/libraries/GasLimits.sol";

abstract contract DeployRootBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;
    using GasLimits for uint256;

    struct RootDeploymentParameters {
        address weth;
        address voter;
        address velo;
        address tokenAdmin;
        address bridgeOwner;
        address emergencyCouncilOwner;
        address notifyAdmin;
        address emissionAdmin;
        uint256 defaultCap;
        address mailbox;
        string outputFilename;
    }

    // root superchain contracts
    XERC20Factory public rootXFactory;
    XERC20 public rootXVelo;
    RootEscrowTokenBridge public rootTokenBridge;
    RootMessageBridge public rootMessageBridge;
    RootHLMessageModule public rootMessageModule;
    PaymasterVault public rootTokenBridgeVault;
    PaymasterVault public rootModuleVault;

    EmergencyCouncil public emergencyCouncil;

    // root-only contracts
    XERC20Lockbox public rootLockbox;
    RootPool public rootPoolImplementation;
    RootPoolFactory public rootPoolFactory;
    RootGaugeFactory public rootGaugeFactory;
    RootVotingRewardsFactory public rootVotingRewardsFactory;

    IInterchainSecurityModule public ism;
    RootDeploymentParameters internal _params;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        rootMessageBridge =
            RootMessageBridge(payable(MESSAGE_BRIDGE_ENTROPY.computeCreate3Address({_deployer: _deployer})));
        rootPoolImplementation = RootPool(
            cx.deployCreate3({
                salt: POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(RootPool).creationCode)
            })
        );
        rootPoolFactory = RootPoolFactory(
            cx.deployCreate3({
                salt: POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootPoolFactory).creationCode,
                    abi.encode(
                        address(rootPoolImplementation), // root pool implementation
                        address(rootMessageBridge) // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: POOL_FACTORY_ENTROPY, _output: address(rootPoolFactory)});

        rootXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: XERC20_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        _params.tokenAdmin, // xerc20 owner address
                        _params.velo // erc20 address
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(rootXFactory)});

        (address _xVelo, address _lockbox) = rootXFactory.deployXERC20WithLockbox();
        rootXVelo = XERC20(_xVelo);
        rootLockbox = XERC20Lockbox(_lockbox);

        rootMessageBridge = RootMessageBridge(
            payable(
                cx.deployCreate3({
                    salt: MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(RootMessageBridge).creationCode,
                        abi.encode(
                            _params.bridgeOwner, // message bridge owner
                            address(rootXVelo), // xerc20 address
                            _params.voter, // root voter
                            _params.weth // weth address
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: MESSAGE_BRIDGE_ENTROPY, _output: address(rootMessageBridge)});

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

        rootVotingRewardsFactory = RootVotingRewardsFactory(
            cx.deployCreate3({
                salt: REWARDS_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootVotingRewardsFactory).creationCode,
                    abi.encode(
                        address(rootMessageBridge) // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: REWARDS_FACTORY_ENTROPY, _output: address(rootVotingRewardsFactory)});

        rootGaugeFactory = RootGaugeFactory(
            cx.deployCreate3({
                salt: GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootGaugeFactory).creationCode,
                    abi.encode(
                        _params.voter, // voter address
                        address(rootXVelo), // xerc20 address
                        address(rootLockbox), // lockbox address
                        address(rootMessageBridge), // message bridge address
                        address(rootPoolFactory), // pool factory address
                        address(rootVotingRewardsFactory), // voting rewards factory address
                        _params.notifyAdmin, // notify admin
                        _params.emissionAdmin, // emission admin
                        _params.defaultCap // default cap
                    )
                )
            })
        );
        checkAddress({_entropy: GAUGE_FACTORY_ENTROPY, _output: address(rootGaugeFactory)});

        emergencyCouncil = new EmergencyCouncil({_owner: _params.emergencyCouncilOwner, _voter: _params.voter});
    }

    function params() external view returns (RootDeploymentParameters memory) {
        return _params;
    }

    /// @dev Used by tests to set the deployment parameters
    function setParams(RootDeploymentParameters memory _params_) external {
        _params = _params_;
    }

    function logParams() internal view override {
        console.log("rootPoolImplementation: ", address(rootPoolImplementation));
        console.log("rootPoolFactory: ", address(rootPoolFactory));
        console.log("rootGaugeFactory: ", address(rootGaugeFactory));
        console.log("rootVotingRewardsFactory: ", address(rootVotingRewardsFactory));

        console.log("rootXFactory: ", address(rootXFactory));
        console.log("rootXVelo: ", address(rootXVelo));
        console.log("rootLockbox: ", address(rootLockbox));

        console.log("rootTokenBridge: ", address(rootTokenBridge));
        console.log("rootTokenBridgeVault: ", address(rootTokenBridgeVault));
        console.log("rootMessageBridge: ", address(rootMessageBridge));
        console.log("rootMessageModule: ", address(rootMessageModule));
        console.log("rootModuleVault: ", address(rootModuleVault));

        console.log("emergencyCouncil: ", address(emergencyCouncil));
        console.log("ism: ", address(ism));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        vm.writeJson(vm.serializeAddress("", "rootPoolImplementation", address(rootPoolImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "rootPoolFactory", address(rootPoolFactory)), path);
        vm.writeJson(vm.serializeAddress("", "rootGaugeFactory", address(rootGaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "rootVotingRewardsFactory", address(rootVotingRewardsFactory)), path);

        vm.writeJson(vm.serializeAddress("", "rootXFactory", address(rootXFactory)), path);
        vm.writeJson(vm.serializeAddress("", "rootXVelo", address(rootXVelo)), path);
        vm.writeJson(vm.serializeAddress("", "rootLockbox", address(rootLockbox)), path);

        vm.writeJson(vm.serializeAddress("", "rootTokenBridge", address(rootTokenBridge)), path);
        vm.writeJson(vm.serializeAddress("", "rootTokenBridgeVault", address(rootTokenBridgeVault)), path);
        vm.writeJson(vm.serializeAddress("", "rootMessageBridge", address(rootMessageBridge)), path);
        vm.writeJson(vm.serializeAddress("", "rootMessageModule", address(rootMessageModule)), path);
        vm.writeJson(vm.serializeAddress("", "rootModuleVault", address(rootModuleVault)), path);

        vm.writeJson(vm.serializeAddress("", "emergencyCouncil", address(emergencyCouncil)), path);
        vm.writeJson(vm.serializeAddress("", "ism", address(ism)), path);
    }
}
