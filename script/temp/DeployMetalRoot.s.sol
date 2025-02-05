// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity >=0.8.19 <0.9.0;
//
// import "../DeployFixture.sol";
//
// import {RootHLMessageModule} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";
// import {RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
//
// contract DeployRootBaseFixture is DeployFixture {
//     using CreateXLibrary for bytes11;
//
//     RootHLMessageModule public rootMessageModule;
//
//     RootMessageBridge public rootMessageBridge = RootMessageBridge(payable(0xF278761576f45472bdD721EACA19317cE159c011));
//     address public mailbox = 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D;
//
//     /// @dev Override if deploying extensions
//     function deploy() internal virtual override {
//         address _deployer = deployer;
//
//         rootMessageModule = RootHLMessageModule(
//             payable(
//                 cx.deployCreate3({
//                     salt: HL_MESSAGE_BRIDGE_ENTROPY_V1_5.calculateSalt({_deployer: _deployer}),
//                     initCode: abi.encodePacked(
//                         type(RootHLMessageModule).creationCode,
//                         abi.encode(
//                             address(rootMessageBridge), // root message bridge
//                             mailbox // root mailbox
//                         )
//                     )
//                 })
//             )
//         );
//         checkAddress({_entropy: HL_MESSAGE_BRIDGE_ENTROPY_V1_5, _output: address(rootMessageModule)});
//     }
//
//     function logParams() internal view override {
//         console.log("rootMessageBridge: ", address(rootMessageBridge));
//         console.log("rootMessageModule: ", address(rootMessageModule));
//     }
//
//     function setUp() public override {}
//
//     function logOutput() internal view override {}
// }
