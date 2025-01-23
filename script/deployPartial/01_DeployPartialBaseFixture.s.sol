// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

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
import {LeafTokenBridge} from "src/bridge/LeafTokenBridge.sol";
import {LeafVoter} from "src/voter/LeafVoter.sol";

abstract contract DeployPartialBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address tokenAdmin;
        address bridgeOwner;
        address moduleOwner;
        address mailbox;
        string inputFilename;
        string outputFilename;
    }

    // leaf superchain contracts
    XERC20Factory public leafXFactory;
    XERC20 public leafXVelo;
    Router public leafRouter;
    LeafTokenBridge public leafTokenBridge;
    LeafMessageBridge public leafMessageBridge;
    LeafHLMessageModule public leafMessageModule;

    // leaf-only contracts
    PoolFactory public leafPoolFactory;
    Pool public leafPoolImplementation;
    LeafGaugeFactory public leafGaugeFactory;
    LeafVoter public leafVoter;
    VotingRewardsFactory public leafVotingRewardsFactory;

    IInterchainSecurityModule public ism;

    DeploymentParameters internal _params;
    string public addresses;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    function setUp() public virtual override {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.inputFilename));
        addresses = vm.readFile(path);

        /// @dev Use contracts from existing deployment
        leafPoolImplementation = Pool(vm.parseJsonAddress(addresses, ".leafPoolImplementation"));
        leafPoolFactory = PoolFactory(vm.parseJsonAddress(addresses, ".leafPoolFactory"));
        leafRouter = Router(payable(vm.parseJsonAddress(addresses, ".leafRouter")));
    }

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        leafXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: XERC20_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        _params.tokenAdmin, // xerc20 owner
                        address(0) // erc20 address
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(leafXFactory)});

        leafMessageBridge = LeafMessageBridge(
            CreateXLibrary.computeCreate3Address({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer})
        );
        leafVoter = LeafVoter(
            cx.deployCreate3({
                salt: VOTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafVoter).creationCode,
                    abi.encode(
                        address(leafMessageBridge) // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: VOTER_ENTROPY, _output: address(leafVoter)});

        leafXVelo = XERC20(leafXFactory.deployXERC20());

        leafMessageModule = LeafHLMessageModule(
            CreateXLibrary.computeCreate3Address({_entropy: HL_MESSAGE_BRIDGE_ENTROPY_V2, _deployer: _deployer})
        );
        leafMessageBridge = LeafMessageBridge(
            cx.deployCreate3({
                salt: MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafMessageBridge).creationCode,
                    abi.encode(
                        _params.bridgeOwner, // message bridge owner
                        address(leafXVelo), // xerc20 address
                        address(leafVoter), // leaf voter
                        address(leafMessageModule) // message module
                    )
                )
            })
        );
        checkAddress({_entropy: MESSAGE_BRIDGE_ENTROPY, _output: address(leafMessageBridge)});

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

        leafTokenBridge = LeafTokenBridge(
            cx.deployCreate3({
                salt: TOKEN_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafTokenBridge).creationCode,
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

        leafGaugeFactory = LeafGaugeFactory(
            cx.deployCreate3({
                salt: GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafGaugeFactory).creationCode,
                    abi.encode(
                        address(leafVoter), // voter address
                        address(leafXVelo), // xerc20 address
                        address(leafMessageBridge) // bridge address
                    )
                )
            })
        );
        checkAddress({_entropy: GAUGE_FACTORY_ENTROPY, _output: address(leafGaugeFactory)});

        leafVotingRewardsFactory = VotingRewardsFactory(
            cx.deployCreate3({
                salt: REWARDS_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(VotingRewardsFactory).creationCode,
                    abi.encode(
                        address(leafVoter), // voter address
                        address(leafMessageBridge) // bridge address
                    )
                )
            })
        );
        checkAddress({_entropy: REWARDS_FACTORY_ENTROPY, _output: address(leafVotingRewardsFactory)});
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("leafPoolImplementation: ", address(leafPoolImplementation));
        console.log("leafPoolFactory: ", address(leafPoolFactory));
        console.log("leafGaugeFactory: ", address(leafGaugeFactory));
        console.log("leafVotingRewardsFactory: ", address(leafVotingRewardsFactory));
        console.log("leafVoter: ", address(leafVoter));

        console.log("leafXFactory: ", address(leafXFactory));
        console.log("leafXVelo: ", address(leafXVelo));

        console.log("leafTokenBridge: ", address(leafTokenBridge));
        console.log("leafMessageBridge: ", address(leafMessageBridge));
        console.log("leafMessageModule: ", address(leafMessageModule));

        console.log("ism: ", address(ism));
        console.log("leafRouter: ", address(leafRouter));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path =
            string(abi.encodePacked(root, "/deployment-addresses/deployPartial/", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress("", "leafPoolImplementation", address(leafPoolImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "leafPoolFactory", address(leafPoolFactory)), path);
        vm.writeJson(vm.serializeAddress("", "leafGaugeFactory", address(leafGaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "leafVotingRewardsFactory", address(leafVotingRewardsFactory)), path);
        vm.writeJson(vm.serializeAddress("", "leafVoter", address(leafVoter)), path);

        vm.writeJson(vm.serializeAddress("", "leafXFactory", address(leafXFactory)), path);
        vm.writeJson(vm.serializeAddress("", "leafXVelo", address(leafXVelo)), path);

        vm.writeJson(vm.serializeAddress("", "leafTokenBridge", address(leafTokenBridge)), path);
        vm.writeJson(vm.serializeAddress("", "leafMessageBridge", address(leafMessageBridge)), path);
        vm.writeJson(vm.serializeAddress("", "leafMessageModule", address(leafMessageModule)), path);

        vm.writeJson(vm.serializeAddress("", "leafRouter", address(leafRouter)), path);
        vm.writeJson(vm.serializeAddress("", "ism", address(ism)), path);
    }
}
