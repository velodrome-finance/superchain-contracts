// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {LeafHLMessageModule} from "src/bridge/hyperlane/LeafHLMessageModule.sol";
import {LeafMessageBridge} from "src/bridge/LeafMessageBridge.sol";

contract DeployBaseFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    LeafHLMessageModule public leafMessageModule;
    IInterchainSecurityModule public ism;

    LeafMessageBridge public leafMessageBridge = LeafMessageBridge(0xF278761576f45472bdD721EACA19317cE159c011);
    address public moduleOwner = 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA;
    address public mailbox = 0x730f8a4128Fa8c53C777B62Baa1abeF94cAd34a9;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        leafMessageModule = LeafHLMessageModule(
            cx.deployCreate3({
                salt: HL_MESSAGE_BRIDGE_ENTROPY_V1_5.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafHLMessageModule).creationCode,
                    abi.encode(
                        moduleOwner, // leaf module owner
                        address(leafMessageBridge), // leaf message bridge
                        mailbox, // leaf mailbox
                        address(ism) // leaf security module
                    )
                )
            })
        );
        checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY_V1_5, _output: address(leafMessageModule)});

        logParams();
    }

    function logParams() internal view override {
        console.log("leafMessageModule: ", address(leafMessageModule));
        console.log("ism: ", address(ism));
    }

    function setUp() public override {}

    function logOutput() internal view override {}
}
