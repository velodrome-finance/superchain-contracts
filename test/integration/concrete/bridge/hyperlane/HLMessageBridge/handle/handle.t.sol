// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLMessageBridge.t.sol";

contract HandleIntegrationConcreteTest is HLMessageBridgeTest {
    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenCallerIsNotMailbox() external {
        // It reverts with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLMessageBridge.NotMailbox.selector);
        leafMessageModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.charlie),
            _message: abi.encode(users.charlie, abi.encode(1))
        });
    }

    modifier whenCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheCommandIsDeposit() external whenCallerIsMailbox {
        // It decodes the gauge address from the message
        // It calls deposit on the fee rewards contract corresponding to the gauge with the payload
        // It calls deposit on the incentive rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        emit IHLMessageBridge.ReceivedMessage({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _value: 0,
            _message: string(message)
        });
        leafMessageModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _message: message
        });

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }

    function test_WhenTheCommandIsWithdraw() external whenCallerIsMailbox {
        // It decodes the gauge address from the message
        // It calls withdraw on the fee rewards contract corresponding to the gauge with the payload
        // It calls withdraw on the incentive rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        leafMessageModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _message: message
        });
        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);

        message = abi.encode(Commands.WITHDRAW, abi.encode(address(leafGauge), payload));

        emit IHLMessageBridge.ReceivedMessage({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _value: 0,
            _message: string(message)
        });
        leafMessageModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _message: message
        });

        assertEq(leafFVR.totalSupply(), 0);
        assertEq(leafFVR.balanceOf(tokenId), 0);
        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
    }

    function test_WhenTheCommandIsInvalid() external whenCallerIsMailbox {
        // It reverts with {InvalidCommand}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(type(uint256).max, abi.encode(address(leafGauge), payload));

        vm.expectRevert(IHLMessageBridge.InvalidCommand.selector);
        leafMessageModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _message: message
        });
    }
}
