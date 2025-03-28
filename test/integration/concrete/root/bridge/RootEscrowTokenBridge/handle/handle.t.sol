// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootEscrowTokenBridge.t.sol";

contract HandleIntegrationConcreteTest is RootEscrowTokenBridgeTest {
    using SafeCast for uint256;

    bytes32 sender = TypeCasts.addressToBytes32(users.charlie);
    uint256 tokenId;
    uint256 invalidTokenId;
    uint256 lockAmount = TOKEN_1 * 1000;
    uint256 amount = TOKEN_1 * 1000;
    uint256 bufferCap = amount * 2;

    function setUp() public virtual override {
        super.setUp();
        deal({token: address(rootRewardToken), to: address(users.bob), give: lockAmount});
        vm.prank(users.bob);
        tokenId = mockEscrow.createLock({_value: lockAmount, _lockDuration: 1 weeks});
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with {NotMailbox}
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        rootEscrowTokenBridge.handle({
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
        rootEscrowTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheSenderIsBridge() {
        sender = TypeCasts.addressToBytes32(address(rootEscrowTokenBridge));
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
        rootEscrowTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheChainidOfOriginIsARegisteredChain() {
        vm.startPrank(users.owner);
        rootEscrowTokenBridge.registerChain({_chainid: leaf});
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
        amount = TOKEN_1;

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectRevert("RateLimited: rate limit hit");
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }

    modifier whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() {
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.startPrank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootEscrowTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        _;
    }

    function test_WhenTheMessageLengthIsSendTokenLength()
        external
        whenTheSenderIsBridge
        whenTheCallerIsMailbox
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootEscrowTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), amount);
    }

    modifier whenTheMessageLengthIsSendTokenAndLockLength() {
        _;
    }

    function test_WhenTheTokenIdIsValid()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit
        whenTheMessageLengthIsSendTokenAndLockLength
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It deposit the unwrapped tokens to the lock with the given tokenId
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, tokenId);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootEscrowTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(mockEscrow.balanceOfNFT(tokenId), amount + lockAmount);
    }

    function test_WhenTheTokenIdIsNotValid()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit
        whenTheMessageLengthIsSendTokenAndLockLength
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should leave zero allowance of token bridge to the escrow contract
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, invalidTokenId);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootEscrowTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), amount);
        assertEq(mockEscrow.balanceOfNFT(tokenId), lockAmount);
        assertEq(rootRewardToken.allowance(address(rootTokenBridge), address(mockEscrow)), 0);
    }

    function test_WhenTheMessageLengthIsInvalid()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit
    {
        // It should revert with {InvalidCommand}
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked("");

        vm.startPrank(address(rootMailbox));
        vm.expectRevert(IRootEscrowTokenBridge.InvalidCommand.selector);
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
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
        rootEscrowTokenBridge.handle({
            _origin: leafDomain,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheOriginDomainIsARegisteredChain() {
        vm.startPrank(users.owner);
        rootEscrowTokenBridge.registerChain({_chainid: leaf});
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
        amount = TOKEN_1;

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectRevert("RateLimited: rate limit hit");
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }

    modifier whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit_() {
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.startPrank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootEscrowTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        _;
    }

    function test_WhenTheMessageLengthIsSendTokenLength_()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit_
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootEscrowTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), amount);
    }

    modifier whenTheMessageLengthIsSendTokenAndLockLength_() {
        _;
    }

    function test_WhenTheTokenIdIsValid_()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit_
        whenTheMessageLengthIsSendTokenAndLockLength_
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It deposit the unwrapped tokens to the lock with the given tokenId
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, tokenId);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootEscrowTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(mockEscrow.balanceOfNFT(tokenId), amount + lockAmount);
    }

    function test_WhenTheTokenIdIsNotValid_()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit_
        whenTheMessageLengthIsSendTokenAndLockLength_
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should leave zero allowance of token bridge to the escrow contract
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, invalidTokenId);

        vm.startPrank(address(rootMailbox));
        vm.expectEmit(address(rootEscrowTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), amount);
        assertEq(mockEscrow.balanceOfNFT(tokenId), lockAmount);
        assertEq(rootRewardToken.allowance(address(rootTokenBridge), address(mockEscrow)), 0);
    }

    function test_WhenTheMessageLengthIsInvalid_()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit_
    {
        // It should revert with {InvalidCommand}
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, tokenId, tokenId);

        vm.startPrank(address(rootMailbox));
        vm.expectRevert(IRootEscrowTokenBridge.InvalidCommand.selector);
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }

    function testGas_handle()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginDomainIsNotLinkedToAChainid
        whenTheOriginDomainIsARegisteredChain
    {
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.startPrank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootEscrowTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, tokenId);

        vm.startPrank(address(rootMailbox));
        rootEscrowTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
        vm.snapshotGasLastCall("RootEscrowTokenBridge_handle");
    }
}
