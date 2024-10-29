// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract QuoteIntegrationConcreteTest is RootHLMessageModuleTest {
    using stdStorage for StdStorage;
    using GasLimits for uint256;

    function test_WhenTheCommandIsDeposit() external {
        // It returns the quote for a message encoded with nonce
        uint256 sendingNonce = 1_000;
        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(sendingNonce);

        uint256 tokenId = 1;
        uint256 amount = TOKEN_1 * 1000;
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);

        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(sendingNonce));
        bytes memory expectedMetadata = StandardHookMetadata.formatMetadata({
            _msgValue: 0,
            _gasLimit: Commands.DEPOSIT.gasLimit(),
            _refundAddress: users.alice,
            _customMetadata: ""
        });

        /// @dev Expect `quoteDispatch` call with encoded nonce
        vm.expectCall(
            address(rootMailbox),
            abi.encodeWithSelector(
                bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)")),
                leaf,
                TypeCasts.addressToBytes32(address(rootMessageModule)),
                expectedMessage,
                expectedMetadata,
                address(0)
            )
        );
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }

    function test_WhenTheCommandIsWithdraw() external {
        // It returns the quote for a message encoded with nonce
        uint256 sendingNonce = 1_000;
        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(sendingNonce);

        uint256 tokenId = 1;
        uint256 amount = TOKEN_1 * 1000;
        bytes memory message = abi.encodePacked(uint8(Commands.WITHDRAW), address(leafGauge), amount, tokenId);

        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.WITHDRAW), address(leafGauge), amount, tokenId, uint256(sendingNonce));
        bytes memory expectedMetadata = StandardHookMetadata.formatMetadata({
            _msgValue: 0,
            _gasLimit: Commands.WITHDRAW.gasLimit(),
            _refundAddress: users.alice,
            _customMetadata: ""
        });

        /// @dev Expect `quoteDispatch` call with encoded nonce
        vm.expectCall(
            address(rootMailbox),
            abi.encodeWithSelector(
                bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)")),
                leaf,
                TypeCasts.addressToBytes32(address(rootMessageModule)),
                expectedMessage,
                expectedMetadata,
                address(0)
            )
        );
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }

    function test_WhenTheCommandIsNotDepositOrWithdraw() external {
        // It returns the quote for a message encoded without nonce
        uint256 amount = TOKEN_1 * 1000;
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), amount);
        bytes memory expectedMetadata = StandardHookMetadata.formatMetadata({
            _msgValue: 0,
            _gasLimit: Commands.NOTIFY.gasLimit(),
            _refundAddress: users.alice,
            _customMetadata: ""
        });

        vm.expectCall(
            address(rootMailbox),
            abi.encodeWithSelector(
                bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)")),
                leaf,
                TypeCasts.addressToBytes32(address(rootMessageModule)),
                message,
                expectedMetadata,
                address(0)
            )
        );
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }
}
