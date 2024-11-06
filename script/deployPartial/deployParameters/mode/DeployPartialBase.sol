// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../../01_DeployPartialBaseFixture.s.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModeLeafVoter} from "src/voter/extensions/ModeLeafVoter.sol";
import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";
import {ModeTokenBridge} from "src/bridge/extensions/ModeTokenBridge.sol";
import {ModeLeafGaugeFactory} from "src/gauges/extensions/ModeLeafGaugeFactory.sol";
import {ModeLeafMessageBridge} from "src/bridge/extensions/ModeLeafMessageBridge.sol";
import {ModeLeafHLMessageModule} from "src/bridge/extensions/hyperlane/ModeLeafHLMessageModule.sol";

contract DeployPartialBase is DeployPartialBaseFixture {
    using CreateXLibrary for bytes11;

    struct ModeDeploymentParameters {
        address recipient;
    }

    ModeDeploymentParameters internal _modeParams;

    function setUp() public override {
        _params = DeployPartialBaseFixture.DeploymentParameters({
            tokenAdmin: 0x0000000000000000000000000000000000000001,
            bridgeOwner: 0x0000000000000000000000000000000000000001,
            moduleOwner: 0x0000000000000000000000000000000000000001,
            mailbox: 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7,
            inputFilename: "mode.json",
            outputFilename: "mode.json"
        });
        _modeParams = ModeDeploymentParameters({recipient: 0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3});
        super.setUp();
    }

    function deploy() internal override {
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

        leafMessageBridge = ModeLeafMessageBridge(
            CreateXLibrary.computeCreate3Address({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer})
        );
        leafVoter = ModeLeafVoter(
            cx.deployCreate3({
                salt: VOTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeLeafVoter).creationCode,
                    abi.encode(
                        address(leafMessageBridge), // message bridge
                        _modeParams.recipient // sfs nft recipient
                    )
                )
            })
        );
        checkAddress({_entropy: VOTER_ENTROPY, _output: address(leafVoter)});

        leafXVelo = XERC20(leafXFactory.deployXERC20());

        leafMessageModule = ModeLeafHLMessageModule(
            CreateXLibrary.computeCreate3Address({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: _deployer})
        );
        leafMessageBridge = ModeLeafMessageBridge(
            cx.deployCreate3({
                salt: MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeLeafMessageBridge).creationCode,
                    abi.encode(
                        _params.bridgeOwner, // message bridge owner
                        address(leafXVelo), // xerc20 address
                        address(leafVoter), // leaf voter
                        address(leafMessageModule), // message module
                        _modeParams.recipient // sfs nft recipient
                    )
                )
            })
        );
        checkAddress({_entropy: MESSAGE_BRIDGE_ENTROPY, _output: address(leafMessageBridge)});

        leafMessageModule = ModeLeafHLMessageModule(
            cx.deployCreate3({
                salt: HL_MESSAGE_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeLeafHLMessageModule).creationCode,
                    abi.encode(
                        _params.moduleOwner, // leaf module owner
                        address(leafMessageBridge), // leaf message bridge
                        _params.mailbox, // leaf mailbox
                        address(ism) // leaf security module
                    )
                )
            })
        );
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _output: address(leafMessageModule)});

        leafTokenBridge = ModeTokenBridge(
            cx.deployCreate3({
                salt: TOKEN_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeTokenBridge).creationCode,
                    abi.encode(
                        _params.bridgeOwner, // bridge owner
                        address(leafXVelo), // xerc20 address
                        _params.mailbox, // mailbox
                        address(ism), // security module
                        _modeParams.recipient // sfs nft recipient
                    )
                )
            })
        );
        checkAddress({_entropy: TOKEN_BRIDGE_ENTROPY, _output: address(leafTokenBridge)});

        leafGaugeFactory = ModeLeafGaugeFactory(
            cx.deployCreate3({
                salt: GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeLeafGaugeFactory).creationCode,
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

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
