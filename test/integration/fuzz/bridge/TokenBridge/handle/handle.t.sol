// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract HandleIntegrationFuzzTest is TokenBridgeTest {
    using SafeCast for uint256;

    bytes32 sender;

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function testFuzz_WhenTheCallerIsNotMailbox(address _caller) external {
        // It should revert with NotMailbox
        vm.assume(_caller != address(leafMailbox));

        vm.prank(_caller);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafTokenBridge.handle({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(_caller),
            _message: abi.encodePacked(_caller, uint256(1))
        });
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function testFuzz_WhenTheSenderIsNotBridge(address _sender) external whenTheCallerIsMailbox {
        // It should revert with NotBridge
        vm.assume(_sender != address(leafTokenBridge));
        sender = TypeCasts.addressToBytes32(_sender);
        vm.expectRevert(ITokenBridge.NotBridge.selector);
        leafTokenBridge.handle({_origin: root, _sender: sender, _message: abi.encodePacked(users.charlie, uint256(1))});
    }

    modifier whenTheSenderIsBridge() {
        sender = TypeCasts.addressToBytes32(address(leafTokenBridge));
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit(uint112 _bufferCap, uint256 _amount)
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
    {
        // It should revert with "RateLimited: rate limit hit"
        _bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        _amount = bound(_amount, _bufferCap / 2 + 1, type(uint256).max / 2);
        uint128 rateLimitPerSecond = Math.min((_bufferCap / 2) / DAY, leafXVelo.maxRateLimitPerSecond()).toUint128();

        vm.startPrank(users.owner);
        leafXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafTokenBridge),
                bufferCap: _bufferCap,
                rateLimitPerSecond: rateLimitPerSecond
            })
        );

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(leafGauge), _amount);

        vm.startPrank(address(leafMailbox));
        vm.expectRevert("RateLimited: rate limit hit");
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(
        uint112 _bufferCap,
        uint256 _amount
    ) external whenTheSenderIsBridge {
        // It should mint tokens to the destination bridge
        // It should emit {ReceivedMessage} event
        _bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        _amount = bound(_amount, WEEK, _bufferCap / 2);
        uint128 rateLimitPerSecond = Math.min((_bufferCap / 2) / DAY, leafXVelo.maxRateLimitPerSecond()).toUint128();

        vm.prank(users.owner);
        leafXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafTokenBridge),
                bufferCap: _bufferCap,
                rateLimitPerSecond: rateLimitPerSecond
            })
        );

        vm.deal(address(leafMailbox), TOKEN_1 / 2);

        bytes memory _message = abi.encodePacked(address(leafGauge), _amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});

        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);
    }
}
