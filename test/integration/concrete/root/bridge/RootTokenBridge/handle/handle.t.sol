// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootTokenBridge.t.sol";

contract HandleIntegrationConcreteTest is RootTokenBridgeTest {
    using SafeCast for uint256;

    bytes32 sender = TypeCasts.addressToBytes32(users.charlie);

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with {NotMailbox}
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        rootTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(rootMailbox));
        _;
    }

    function test_WhenTheSenderIsNotBridge() external whenTheCallerIsMailbox {
        // It should revert with {NotBridge}
        vm.expectRevert(ITokenBridge.NotBridge.selector);
        rootTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheSenderIsBridge() {
        sender = TypeCasts.addressToBytes32(address(rootTokenBridge));
        _;
    }

    function test_WhenTheOriginChainIsNotARegisteredChain() external whenTheCallerIsMailbox whenTheSenderIsBridge {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheOriginChainIsARegisteredChain() {
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leafDomain});
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

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.expectRevert("RateLimited: rate limit hit");
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit()
        external
        whenTheOriginChainIsARegisteredChain
        whenTheSenderIsBridge
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 bufferCap = amount * 2;
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.prank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.prank(address(rootMailbox));
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(leafGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(leafGauge)), amount);
    }

    function testGas_handle() external whenTheSenderIsBridge whenTheOriginChainIsARegisteredChain {
        uint256 amount = TOKEN_1 * 1000;
        uint256 bufferCap = amount * 2;
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.prank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.prank(address(rootMailbox));
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
        vm.snapshotGasLastCall("RootTokenBridge_handle");
    }
}
