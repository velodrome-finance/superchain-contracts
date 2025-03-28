// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafTokenBridge.t.sol";

contract HandleIntegrationConcreteTest is LeafTokenBridgeTest {
    using SafeCast for uint256;

    bytes32 sender = TypeCasts.addressToBytes32(users.charlie);

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with {NotMailbox}
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafTokenBridge.handle({
            _origin: rootDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheSenderIsNotBridge() external whenTheCallerIsMailbox {
        // It should revert with {NotBridge}
        vm.expectRevert(ITokenBridge.NotBridge.selector);
        leafTokenBridge.handle({
            _origin: rootDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheSenderIsBridge() {
        sender = TypeCasts.addressToBytes32(address(leafTokenBridge));
        _;
    }

    function test_WhenTheOriginChainIsNotARegisteredChain() external whenTheCallerIsMailbox whenTheSenderIsBridge {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        leafTokenBridge.handle({
            _origin: rootDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheOriginChainIsARegisteredChain() {
        vm.prank(users.owner);
        leafTokenBridge.registerChain({_chainid: rootDomain});
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit()
        external
        whenTheOriginChainIsARegisteredChain
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
    {
        // It should revert with "RateLimited: rate limit hit"
        uint256 amount = TOKEN_1;

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(leafGauge), amount);

        vm.expectRevert("RateLimited: rate limit hit");
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: rootDomain, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit()
        external
        whenTheOriginChainIsARegisteredChain
        whenTheSenderIsBridge
    {
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

        bytes memory _message = abi.encodePacked(address(leafGauge), amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: rootDomain, _sender: sender, _message: _message});

        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }

    function testGas_handle() external whenTheSenderIsBridge whenTheOriginChainIsARegisteredChain {
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

        bytes memory _message = abi.encodePacked(address(leafGauge), amount);

        vm.prank(address(leafMailbox));
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: rootDomain, _sender: sender, _message: _message});
        vm.snapshotGasLastCall("TokenBridge_handle");
    }
}
