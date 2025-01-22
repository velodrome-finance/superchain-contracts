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

    modifier whenTheOriginDomainIsLinkedToAChainid() {
        assertNotEq(rootMessageModule.chains(leafDomain), 0);
        _;
    }

    function test_WhenTheChainidOfOriginIsNotARegisteredChain()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
    {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheChainidOfOriginIsARegisteredChain() {
        vm.startPrank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
    {
        // It should revert with "RateLimited: rate limit hit"
        uint256 amount = TOKEN_1;

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectRevert("RateLimited: rate limit hit");
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 bufferCap = amount * 2;
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.startPrank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), amount);
    }

    modifier whenTheOriginDomainIsNotLinkedToAChainid() {
        vm.startPrank(rootMessageBridge.owner());
        rootMessageModule.setDomain({_chainid: leaf, _domain: 0});
        // @dev if domain not linked to chain, domain should be equal to chainid
        leafDomain = leaf;

        vm.startPrank(address(rootMailbox));
        assertEq(rootMessageModule.chains(leaf), 0);
        _;
    }

    function test_WhenTheOriginDomainIsNotARegisteredChain()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
    {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheOriginDomainIsARegisteredChain() {
        vm.startPrank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit_()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
    {
        // It should revert with "RateLimited: rate limit hit"
        uint256 amount = TOKEN_1;

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectRevert("RateLimited: rate limit hit");
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit_()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
    {
        // It should mint tokens to the destination contract
        // It should emit {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 bufferCap = amount * 2;
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.startPrank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), amount);
    }

    function testGas_handle()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
    {
        uint256 amount = TOKEN_1 * 1000;
        uint256 bufferCap = amount * 2;
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.startPrank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
        vm.snapshotGasLastCall("RootTokenBridge_handle");
    }
}
