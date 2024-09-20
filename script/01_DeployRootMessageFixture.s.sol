// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "./DeployFixture.sol";

import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {IXERC20, XERC20} from "src/xerc20/XERC20.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";

import {RootPool} from "src/mainnet/pools/RootPool.sol";
import {RootPoolFactory} from "src/mainnet/pools/RootPoolFactory.sol";
import {RootMessageBridge} from "src/mainnet/bridge/RootMessageBridge.sol";
import {RootHLMessageModule} from "src/mainnet/bridge/hyperlane/RootHLMessageModule.sol";

import {EmergencyCouncil} from "src/mainnet/emergencyCouncil/EmergencyCouncil.sol";

import {IRootGaugeFactory, RootGaugeFactory} from "src/mainnet/gauges/RootGaugeFactory.sol";
import {IRootVotingRewardsFactory, RootVotingRewardsFactory} from "src/mainnet/rewards/RootVotingRewardsFactory.sol";

abstract contract DeployRootMessageFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    struct RootDeploymentParameters {
        address weth;
        address voter;
        address votingEscrow;
        address velo;
        address factoryRegistry;
        address tokenAdmin;
        address bridgeOwner;
        address emergencyCouncilOwner;
        address notifyAdmin;
        address emissionAdmin;
        uint256 defaultCap;
        address mailbox;
        string outputFilename;
    }

    XERC20Factory public xerc20Factory;
    XERC20 public xVelo;
    XERC20Lockbox public lockbox;

    RootMessageBridge public messageBridge;
    RootHLMessageModule public messageModule;

    RootPool public poolImplementation;
    RootPoolFactory public poolFactory;
    RootGaugeFactory public gaugeFactory;
    RootVotingRewardsFactory public votingRewardsFactory;

    EmergencyCouncil public emergencyCouncil;

    RootDeploymentParameters internal _params;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        messageBridge = RootMessageBridge(
            payable(CreateXLibrary.computeCreate3Address({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer}))
        );
        poolImplementation = new RootPool();
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
        (address _xVelo, address _lockbox) = xerc20Factory.deployXERC20WithLockbox({_erc20: _params.velo});
        xVelo = XERC20(_xVelo);
        lockbox = XERC20Lockbox(_lockbox);

        messageModule = RootHLMessageModule(
            CreateXLibrary.computeCreate3Address({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer})
        );

        gaugeFactory = RootGaugeFactory(
            CreateXLibrary.computeCreate3Address({_entropy: GAUGE_FACTORY_ENTROPY, _deployer: _deployer})
        );
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
                            address(messageModule), // message module
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
                        _params.mailbox, // root mailbox
                        address(0) // root security module
                    )
                )
            })
        );
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _output: address(messageModule)});

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
                        xVelo, // xerc20 address
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
        console2.log("xerc20Factory: ", address(xerc20Factory));
        console2.log("xVelo: ", address(xVelo));
        console2.log("lockbox: ", address(lockbox));

        console2.log("messageBridge: ", address(messageBridge));
        console2.log("messageModule: ", address(messageModule));

        console2.log("gaugeFactory: ", address(gaugeFactory));
        console2.log("emergencyCouncil: ", address(emergencyCouncil));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));

        vm.writeJson(vm.serializeAddress("", "xerc20Factory: ", address(xerc20Factory)), path);
        vm.writeJson(vm.serializeAddress("", "xVelo: ", address(xVelo)), path);
        vm.writeJson(vm.serializeAddress("", "lockbox: ", address(lockbox)), path);

        vm.writeJson(vm.serializeAddress("", "messageBridge: ", address(messageBridge)), path);
        vm.writeJson(vm.serializeAddress("", "messageModule: ", address(messageModule)), path);

        vm.writeJson(vm.serializeAddress("", "gaugeFactory: ", address(gaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "emergencyCouncil: ", address(emergencyCouncil)), path);
    }
}
