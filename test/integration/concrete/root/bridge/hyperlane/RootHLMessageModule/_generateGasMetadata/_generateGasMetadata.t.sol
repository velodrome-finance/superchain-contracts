// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract GenerateGasMetadataIntegrationConcreteTest is RootHLMessageModuleTest {
    using GasLimits for uint256;

    MockCustomHook public hook;
    uint256 public constant tokenId = 1;
    uint256 public constant ethAmount = TOKEN_1;
    uint256 public constant amount = TOKEN_1 * 1000;

    function setUp() public virtual override {
        super.setUp();

        hook = new MockCustomHook();
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
    }

    function test_WhenThereIsNoCustomHookSet() external {
        // It should fetch the gas limit for the command from the library
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(0));

        uint256 expectedGasLimit = Commands.DEPOSIT.gasLimit();
        string memory expectedMetadata = string(
            StandardHookMetadata.formatMetadata({
                _msgValue: ethAmount,
                _gasLimit: expectedGasLimit,
                _refundAddress: users.alice,
                _customMetadata: ""
            })
        );

        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(expectedMessage),
            _metadata: expectedMetadata
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    function test_WhenThereIsACustomHookSet() external {
        // It should fetch the gas limit for the command from the custom hook
        vm.prank(rootMessageBridge.owner());
        rootMessageModule.setHook({_hook: address(hook)});

        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(0));

        /// @dev MockCustomHook returns twice the gas limit
        uint256 expectedGasLimit = Commands.DEPOSIT.gasLimit() * 2;
        string memory expectedMetadata = string(
            StandardHookMetadata.formatMetadata({
                _msgValue: ethAmount,
                _gasLimit: expectedGasLimit,
                _refundAddress: users.alice,
                _customMetadata: ""
            })
        );

        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(expectedMessage),
            _metadata: expectedMetadata
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }
}
