// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../../01_DeployBridgesBaseFixture.s.sol";

import {ModeLeafEscrowTokenBridge} from "src/bridge/extensions/ModeLeafEscrowTokenBridge.sol";
import {ModeLeafHLMessageModule} from "src/bridge/extensions/hyperlane/ModeLeafHLMessageModule.sol";

contract DeployBridgesMode is DeployBridgesBaseFixture {
    using CreateXLibrary for bytes11;

    struct ModeDeploymentParameters {
        address recipient;
    }

    ModeDeploymentParameters internal _modeParams;

    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            bridgeOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            mailbox: 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7,
            outputFilename: "mode.json"
        });
        _modeParams = ModeDeploymentParameters({recipient: 0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3});
        super.setUp();
    }

    function deploy() internal virtual override {
        address _deployer = deployer;

        leafTokenBridge = ModeLeafEscrowTokenBridge(
            cx.deployCreate3({
                salt: TOKEN_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModeLeafEscrowTokenBridge).creationCode,
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
        checkAddress({_entropy: TOKEN_BRIDGE_ENTROPY_V2, _output: address(leafTokenBridge)});

        leafMessageModule = ModeLeafHLMessageModule(
            cx.deployCreate3({
                salt: HL_MESSAGE_BRIDGE_ENTROPY_V2.calculateSalt({_deployer: _deployer}),
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
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY_V2, _output: address(leafMessageModule)});
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
