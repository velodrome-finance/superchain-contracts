// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {RootVotingRewardsFactory} from "src/mainnet/rewards/RootVotingRewardsFactory.sol";
import {RootGaugeFactory} from "src/mainnet/gauges/RootGaugeFactory.sol";
import {RootPoolFactory} from "src/mainnet/pools/RootPoolFactory.sol";
import {RootPool} from "src/mainnet/pools/RootPool.sol";

import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {XERC20} from "src/xerc20/XERC20.sol";

import {EmergencyCouncil} from "src/mainnet/emergencyCouncil/EmergencyCouncil.sol";
import {RootHLMessageModule} from "src/mainnet/bridge/hyperlane/RootHLMessageModule.sol";
import {RootMessageBridge} from "src/mainnet/bridge/RootMessageBridge.sol";
import {TokenBridge} from "src/bridge/TokenBridge.sol";

abstract contract DeployRootBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;

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

    RootPool public poolImplementation;
    RootPoolFactory public poolFactory;
    RootGaugeFactory public gaugeFactory;
    RootVotingRewardsFactory public votingRewardsFactory;

    XERC20Factory public xerc20Factory;
    XERC20 public xVelo;
    XERC20Lockbox public lockbox;

    TokenBridge public tokenBridge;
    RootMessageBridge public messageBridge;
    RootHLMessageModule public messageModule;
    EmergencyCouncil public emergencyCouncil;

    IInterchainSecurityModule public ism;
    RootDeploymentParameters internal _params;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        messageBridge = RootMessageBridge(
            payable(CreateXLibrary.computeCreate3Address({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer}))
        );
        poolImplementation = RootPool(
            cx.deployCreate3({
                salt: POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(RootPool).creationCode)
            })
        );
        poolFactory = RootPoolFactory(
            cx.deployCreate3({
                salt: POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootPoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // root pool implementation
                        address(messageBridge) // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: POOL_FACTORY_ENTROPY, _output: address(poolFactory)});

        xerc20Factory = XERC20Factory(
            cx.deployCreate3({
                salt: XERC20_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        address(cx), // create x address
                        _params.tokenAdmin // xerc20 owner address
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(xerc20Factory)});

        (address _xVelo, address _lockbox) = xerc20Factory.deployXERC20WithLockbox({_erc20: _params.velo});
        xVelo = XERC20(_xVelo);
        lockbox = XERC20Lockbox(_lockbox);

        messageBridge = RootMessageBridge(
            payable(
                cx.deployCreate3({
                    salt: MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(RootMessageBridge).creationCode,
                        abi.encode(
                            _params.bridgeOwner, // message bridge owner
                            address(xVelo), // xerc20 address
                            _params.voter, // root voter
                            _params.weth // weth address
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: MESSAGE_BRIDGE_ENTROPY, _output: address(messageBridge)});

        messageModule = RootHLMessageModule(
            cx.deployCreate3({
                salt: HL_MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootHLMessageModule).creationCode,
                    abi.encode(
                        address(messageBridge), // root message bridge
                        _params.mailbox // root mailbox
                    )
                )
            })
        );
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _output: address(messageModule)});

        tokenBridge = TokenBridge(
            cx.deployCreate3({
                salt: TOKEN_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(TokenBridge).creationCode,
                    abi.encode(
                        _params.bridgeOwner, // bridge owner
                        address(xVelo), // xerc20 address
                        _params.mailbox, // mailbox
                        address(ism) // security module
                    )
                )
            })
        );
        checkAddress({_entropy: TOKEN_BRIDGE_ENTROPY, _output: address(tokenBridge)});

        votingRewardsFactory = RootVotingRewardsFactory(
            cx.deployCreate3({
                salt: REWARDS_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootVotingRewardsFactory).creationCode,
                    abi.encode(
                        address(messageBridge) // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: REWARDS_FACTORY_ENTROPY, _output: address(votingRewardsFactory)});

        gaugeFactory = RootGaugeFactory(
            cx.deployCreate3({
                salt: GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootGaugeFactory).creationCode,
                    abi.encode(
                        _params.voter, // voter address
                        address(xVelo), // xerc20 address
                        address(lockbox), // lockbox address
                        address(messageBridge), // message bridge address
                        address(poolFactory), // pool factory address
                        address(votingRewardsFactory), // voting rewards factory address
                        _params.notifyAdmin, // notify admin
                        _params.emissionAdmin, // emission admin
                        _params.defaultCap // default cap
                    )
                )
            })
        );
        checkAddress({_entropy: GAUGE_FACTORY_ENTROPY, _output: address(gaugeFactory)});

        emergencyCouncil = new EmergencyCouncil({
            _owner: _params.emergencyCouncilOwner,
            _voter: _params.voter,
            _bridge: address(messageBridge)
        });
    }

    function params() external view returns (RootDeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("poolImplementation: ", address(poolImplementation));
        console.log("poolFactory: ", address(poolFactory));
        console.log("gaugeFactory: ", address(gaugeFactory));
        console.log("votingRewardsFactory: ", address(votingRewardsFactory));

        console.log("xerc20Factory: ", address(xerc20Factory));
        console.log("xVelo: ", address(xVelo));
        console.log("lockbox: ", address(lockbox));

        console.log("tokenBridge: ", address(tokenBridge));
        console.log("messageBridge: ", address(messageBridge));
        console.log("messageModule: ", address(messageModule));

        console.log("emergencyCouncil: ", address(emergencyCouncil));
        console.log("ism: ", address(ism));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        vm.writeJson(vm.serializeAddress("", "poolImplementation: ", address(poolImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "poolFactory: ", address(poolFactory)), path);
        vm.writeJson(vm.serializeAddress("", "gaugeFactory: ", address(gaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "votingRewardsFactory: ", address(votingRewardsFactory)), path);

        vm.writeJson(vm.serializeAddress("", "xerc20Factory: ", address(xerc20Factory)), path);
        vm.writeJson(vm.serializeAddress("", "xVelo: ", address(xVelo)), path);
        vm.writeJson(vm.serializeAddress("", "lockbox: ", address(lockbox)), path);

        vm.writeJson(vm.serializeAddress("", "tokenBridge: ", address(tokenBridge)), path);
        vm.writeJson(vm.serializeAddress("", "messageBridge: ", address(messageBridge)), path);
        vm.writeJson(vm.serializeAddress("", "messageModule: ", address(messageModule)), path);

        vm.writeJson(vm.serializeAddress("", "emergencyCouncil: ", address(emergencyCouncil)), path);
        vm.writeJson(vm.serializeAddress("", "ism: ", address(ism)), path);
    }
}
