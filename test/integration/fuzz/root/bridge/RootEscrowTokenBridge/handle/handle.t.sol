// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootEscrowTokenBridge.t.sol";

contract HandleIntegrationFuzzTest is RootEscrowTokenBridgeTest {
    using SafeCast for uint256;

    bytes32 sender;
    uint256 tokenId;
    uint256 lockAmount = TOKEN_1 * 1000;
    uint256 amount;
    uint256 bufferCap;

    function setUp() public virtual override {
        super.setUp();
        deal({token: address(rootRewardToken), to: address(users.bob), give: lockAmount});
        vm.prank(users.bob);
        tokenId = mockEscrow.createLock({_value: lockAmount, _lockDuration: 1 weeks});
    }

    function testFuzz_WhenTheCallerIsNotMailbox(address _caller) external {
        // It should revert with {NotMailbox}
        vm.assume(_caller != address(rootMailbox));

        vm.prank(_caller);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        rootTokenBridge.handle({
            _origin: leafDomain,
            _sender: TypeCasts.addressToBytes32(_caller),
            _message: abi.encodePacked(_caller, uint256(1))
        });
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(rootMailbox));
        _;
    }

    function testFuzz_WhenTheSenderIsNotBridge(address _sender) external whenTheCallerIsMailbox {
        // It should revert with {NotBridge}
        vm.assume(_sender != address(rootTokenBridge));
        sender = TypeCasts.addressToBytes32(_sender);
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

    function testFuzz_WhenTheOriginChainIsNotARegisteredChain(uint32 _origin)
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
    {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootTokenBridge.handle({
            _origin: _origin,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheOriginChainIsARegisteredChain() {
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});
        _;
    }

    modifier whenTheChainidOfOriginIsARegisteredChain() {
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit(uint112 _bufferCap, uint256 _amount)
        external
        whenTheOriginChainIsARegisteredChain
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
    {
        // It should revert with "RateLimited: rate limit hit"
        _bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        _amount = bound(_amount, _bufferCap / 2 + 1, type(uint256).max / 2);
        uint128 rateLimitPerSecond = Math.min((_bufferCap / 2) / DAY, rootXVelo.maxRateLimitPerSecond()).toUint128();

        vm.startPrank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootTokenBridge),
                bufferCap: _bufferCap,
                rateLimitPerSecond: rateLimitPerSecond
            })
        );

        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), _amount);

        vm.startPrank(address(rootMailbox));
        vm.expectRevert("RateLimited: rate limit hit");
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }

    modifier whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(uint256 _bufferCap, uint256 _amount) {
        bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        amount = bound(_amount, WEEK, bufferCap / 2);
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});
        uint128 rateLimitPerSecond = Math.min((bufferCap / 2) / DAY, rootXVelo.maxRateLimitPerSecond()).toUint128();

        vm.prank(users.owner);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(rootTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rateLimitPerSecond
            })
        );

        _;
    }

    function testFuzz_WhenTheMessageLengthIsSendTokenLength(uint112 _bufferCap, uint256 _amount)
        external
        whenTheSenderIsBridge
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(_bufferCap, _amount)
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1 / 2);

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

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), amount);
    }

    modifier whenTheMessageLengthIsSendTokenAndLockLength() {
        _;
    }

    function testFuzz_WhenTheTokenIdIsValid(uint112 _bufferCap, uint256 _amount)
        external
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(_bufferCap, _amount)
        whenTheMessageLengthIsSendTokenAndLockLength
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It deposit the unwrapped tokens to the lock with the given tokenId
        // It should emit {ReceivedMessage} event
        vm.deal(address(rootMailbox), TOKEN_1 / 2);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, tokenId);

        vm.prank(address(rootMailbox));
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(mockEscrow.balanceOfNFT(tokenId), amount + lockAmount);
    }

    function testFuzz_WhenTheTokenIdIsNotValid(uint112 _bufferCap, uint256 _amount, uint256 _tokenId)
        external
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(_bufferCap, _amount)
        whenTheMessageLengthIsSendTokenAndLockLength
    {
        // It should mint tokens
        // It should unwrap the newly minted xerc20 tokens
        // It should leave zero allowance of token bridge to the escrow contract
        // It should send the unwrapped tokens to the recipient contract
        // It should emit {ReceivedMessage} event
        vm.assume(_tokenId != tokenId);
        vm.deal(address(rootMailbox), TOKEN_1);

        bytes memory _message = abi.encodePacked(address(rootGauge), amount, _tokenId);

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
        assertEq(mockEscrow.balanceOfNFT(tokenId), lockAmount);
        assertEq(rootRewardToken.allowance(address(rootTokenBridge), address(mockEscrow)), 0);
    }

    function testFuzz_WhenTheMessageLengthIsInvalid(bytes memory _message)
        external
        whenTheSenderIsBridge
        whenTheOriginDomainIsLinkedToAChainid
        whenTheChainidOfOriginIsARegisteredChain
        whenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(TOKEN_1 * 1000, TOKEN_1 * 2000)
    {
        // It should revert with {InvalidCommand}
        vm.assume(
            _message.length != Commands.SEND_TOKEN_LENGTH && _message.length != Commands.SEND_TOKEN_AND_LOCK_LENGTH
        );
        vm.deal(address(rootMailbox), TOKEN_1);

        vm.startPrank(address(rootMailbox));
        vm.expectRevert(IRootEscrowTokenBridge.InvalidCommand.selector);
        rootTokenBridge.handle{value: TOKEN_1 / 2}({_origin: leafDomain, _sender: sender, _message: _message});
    }
}
