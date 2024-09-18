// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract HandleIntegrationConcreteTest is TokenBridgeTest {
    using SafeCast for uint256;

    bytes32 sender = TypeCasts.addressToBytes32(users.charlie);

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafTokenBridge.handle({_origin: root, _sender: sender, _message: abi.encode(users.charlie, 1)});
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheSenderIsNotBridge() external whenTheCallerIsMailbox {
        // It should revert with NotBridge
        vm.expectRevert(ITokenBridge.NotBridge.selector);
        leafTokenBridge.handle({_origin: root, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheSenderIsBridge() {
        sender = TypeCasts.addressToBytes32(address(leafTokenBridge));
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
    {
        // It should revert with "RateLimited: rate limit hit"
        uint256 amount = TOKEN_1;

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.expectRevert("RateLimited: rate limit hit");
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() external whenTheSenderIsBridge {
        // It should mint tokens to the destination contract
        // It should emit {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 bufferCap = amount * 2;

        vm.prank(users.owner);
        leafXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});

        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
