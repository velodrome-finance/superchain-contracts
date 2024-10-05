// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../01_DeployBaseFixture.s.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";

contract DeployBase is DeployBaseFixture {
    using CreateXLibrary for bytes11;

    struct ModeDeploymentParameters {
        address sfs;
        address recipient;
    }

    ModeDeploymentParameters internal _modeParams;

    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            pauser: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            feeManager: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            tokenAdmin: 0x0000000000000000000000000000000000000001,
            bridgeOwner: 0x0000000000000000000000000000000000000001,
            moduleOwner: 0x0000000000000000000000000000000000000001,
            mailbox: 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7,
            outputFilename: "mode.json"
        });
        _modeParams = ModeDeploymentParameters({
            sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020,
            recipient: 0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3
        });
    }

    function deploy() internal override {
        address _deployer = deployer;

        poolImplementation = ModePool(
            cx.deployCreate3({
                salt: POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(ModePool).creationCode)
            })
        );
        checkAddress({_entropy: POOL_ENTROPY, _output: address(poolImplementation)});

        poolFactory = ModePoolFactory(
            cx.deployCreate3({
                salt: POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModePoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // pool implementation
                        _params.poolAdmin, // pool admin
                        _params.pauser, // pauser
                        _params.feeManager, // fee manager
                        _modeParams.sfs, // sequencer fee sharing contract
                        _modeParams.recipient // sfs nft recipient
                    )
                )
            })
        );
        checkAddress({_entropy: POOL_FACTORY_ENTROPY, _output: address(poolFactory)});

        router = ModeRouter(
            payable(
                cx.deployCreate3({
                    salt: ROUTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(ModeRouter).creationCode,
                        abi.encode(
                            address(poolFactory), // pool factory
                            _params.weth, // weth contract
                            _modeParams.sfs, // sequencer fee sharing contract
                            _modeParams.recipient // sfs nft recipient
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
                        address(cx), // create x address
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

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
