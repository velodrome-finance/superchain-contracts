// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "./DeployFixture.sol";

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {VotingRewardsFactory} from "src/rewards/VotingRewardsFactory.sol";
import {LeafGaugeFactory} from "src/gauges/LeafGaugeFactory.sol";
import {PoolFactory} from "src/pools/PoolFactory.sol";
import {Pool} from "src/pools/Pool.sol";
import {Router} from "src/Router.sol";

import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {XERC20} from "src/xerc20/XERC20.sol";

import {LeafHLMessageModule} from "src/bridge/hyperlane/LeafHLMessageModule.sol";
import {LeafMessageBridge} from "src/bridge/LeafMessageBridge.sol";
import {TokenBridge} from "src/bridge/TokenBridge.sol";
import {LeafVoter} from "src/voter/LeafVoter.sol";

abstract contract DeployBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address weth;
        address poolAdmin;
        address pauser;
        address feeManager;
        address tokenAdmin;
        address bridgeOwner;
        address moduleOwner;
        address mailbox;
        string outputFilename;
    }

    Pool public poolImplementation;
    PoolFactory public poolFactory;
    LeafGaugeFactory public gaugeFactory;
    VotingRewardsFactory public votingRewardsFactory;
    LeafVoter public voter;

    XERC20Factory public xerc20Factory;
    XERC20 public xVelo;

    TokenBridge public tokenBridge;
    LeafMessageBridge public messageBridge;
    LeafHLMessageModule public messageModule;

    IInterchainSecurityModule public ism;
    Router public router;

    DeploymentParameters internal _params;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        poolImplementation = Pool(
            cx.deployCreate3({
                salt: POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(Pool).creationCode)
            })
        );
        checkAddress({_entropy: POOL_ENTROPY, _output: address(poolImplementation)});

        poolFactory = PoolFactory(
            cx.deployCreate3({
                salt: POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(PoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // pool implementation
                        _params.poolAdmin, // pool admin
                        _params.pauser, // pauser
                        _params.feeManager // fee manager
                    )
                )
            })
        );
        checkAddress({_entropy: POOL_FACTORY_ENTROPY, _output: address(poolFactory)});

        router = Router(
            payable(
                cx.deployCreate3({
                    salt: ROUTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(Router).creationCode,
                        abi.encode(
                            address(poolFactory), // pool factory
                            _params.weth // weth contract
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: ROUTER_ENTROPY, _output: address(router)});

        xerc20Factory = XERC20Factory(
            cx.deployCreate3({
                salt: XERC20_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        _params.tokenAdmin // xerc20 owner
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(xerc20Factory)});

        messageBridge = LeafMessageBridge(
            CreateXLibrary.computeCreate3Address({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer})
        );
        voter = LeafVoter(
            cx.deployCreate3({
                salt: VOTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafVoter).creationCode,
                    abi.encode(
                        address(messageBridge) // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: VOTER_ENTROPY, _output: address(voter)});

        xVelo = XERC20(xerc20Factory.deployXERC20());

        messageModule = LeafHLMessageModule(
            CreateXLibrary.computeCreate3Address({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer})
        );
        messageBridge = LeafMessageBridge(
            cx.deployCreate3({
                salt: MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafMessageBridge).creationCode,
                    abi.encode(
                        _params.bridgeOwner, // message bridge owner
                        address(xVelo), // xerc20 address
                        address(voter), // leaf voter
                        address(messageModule) // message module
                    )
                )
            })
        );
        checkAddress({_entropy: MESSAGE_BRIDGE_ENTROPY, _output: address(messageBridge)});

        messageModule = LeafHLMessageModule(
            cx.deployCreate3({
                salt: HL_MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafHLMessageModule).creationCode,
                    abi.encode(
                        _params.moduleOwner, // leaf module owner
                        address(messageBridge), // leaf message bridge
                        _params.mailbox, // leaf mailbox
                        address(ism) // leaf security module
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

        gaugeFactory = LeafGaugeFactory(
            cx.deployCreate3({
                salt: GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafGaugeFactory).creationCode,
                    abi.encode(
                        address(voter), // voter address
                        address(xVelo), // xerc20 address
                        address(messageBridge) // bridge address
                    )
                )
            })
        );
        checkAddress({_entropy: GAUGE_FACTORY_ENTROPY, _output: address(gaugeFactory)});

        votingRewardsFactory = VotingRewardsFactory(
            cx.deployCreate3({
                salt: REWARDS_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(VotingRewardsFactory).creationCode,
                    abi.encode(
                        address(voter), // voter address
                        address(messageBridge) // bridge address
                    )
                )
            })
        );
        checkAddress({_entropy: REWARDS_FACTORY_ENTROPY, _output: address(votingRewardsFactory)});
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("poolImplementation: ", address(poolImplementation));
        console.log("poolFactory: ", address(poolFactory));
        console.log("gaugeFactory: ", address(gaugeFactory));
        console.log("votingRewardsFactory: ", address(votingRewardsFactory));
        console.log("voter: ", address(voter));

        console.log("xerc20Factory: ", address(xerc20Factory));
        console.log("xVelo: ", address(xVelo));

        console.log("tokenBridge: ", address(tokenBridge));
        console.log("messageBridge: ", address(messageBridge));
        console.log("messageModule: ", address(messageModule));

        console.log("ism: ", address(ism));
        console.log("router: ", address(router));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress("", "poolImplementation", address(poolImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "poolFactory", address(poolFactory)), path);
        vm.writeJson(vm.serializeAddress("", "gaugeFactory: ", address(gaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "votingRewardsFactory: ", address(votingRewardsFactory)), path);
        vm.writeJson(vm.serializeAddress("", "voter: ", address(voter)), path);

        vm.writeJson(vm.serializeAddress("", "xerc20Factory: ", address(xerc20Factory)), path);
        vm.writeJson(vm.serializeAddress("", "xVelo: ", address(xVelo)), path);

        vm.writeJson(vm.serializeAddress("", "tokenBridge: ", address(tokenBridge)), path);
        vm.writeJson(vm.serializeAddress("", "messageBridge: ", address(messageBridge)), path);
        vm.writeJson(vm.serializeAddress("", "messageModule: ", address(messageModule)), path);

        vm.writeJson(vm.serializeAddress("", "router: ", address(router)), path);
        vm.writeJson(vm.serializeAddress("", "ism: ", address(ism)), path);
    }
}
