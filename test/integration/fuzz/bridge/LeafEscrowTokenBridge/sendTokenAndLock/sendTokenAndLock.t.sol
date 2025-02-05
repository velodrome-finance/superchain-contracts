// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafEscrowTokenBridge.t.sol";

contract SendTokenAndLockIntegrationFuzzTest is LeafEscrowTokenBridgeTest {
    using SafeCast for uint256;

    uint256 public amount;
    uint256 public tokenId;
    uint256 public lockAmount = TOKEN_1 * 1000;
    uint256 public msgValue;

    modifier whenTheTokenIdIsNotZero() {
        vm.selectFork({forkId: rootId});
        // create lock for bob to allow depositFor on root chain
        deal({token: address(rootRewardToken), to: address(users.bob), give: lockAmount});
        vm.prank(users.bob);
        tokenId = mockEscrow.createLock({_value: lockAmount, _lockDuration: 1 weeks});
        vm.selectFork({forkId: leafId});
        _;
    }

    modifier whenTheRequestedAmountIsNotZero(uint256 _amount) {
        amount = bound(_amount, 1, MAX_BUFFER_CAP / 2);

        vm.selectFork({forkId: rootId});
        // deal tokens to allow unwrapping xerc20
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: MAX_BUFFER_CAP / 2});
        vm.selectFork({forkId: leafId});
        _;
    }

    modifier whenTheRecipientIsNotAddressZero(address _recipient) {
        vm.assume(_recipient != address(0) && _recipient != address(mockEscrow) && _recipient != address(rootLockbox));
        _;
    }

    modifier whenTheRequestedChainIsARegisteredChain() {
        vm.prank(users.owner);
        leafEscrowTokenBridge.registerChain({_chainid: root});

        vm.selectFork({forkId: rootId});
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});
        vm.selectFork({forkId: leafId});
        _;
    }

    function testFuzz_WhenTheMsgValueIsSmallerThanQuotedFee(uint256 _amount, address _recipient, uint256 _msgValue)
        external
        whenTheTokenIdIsNotZero
        whenTheRequestedAmountIsNotZero(_amount)
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with {InsufficientBalance}
        msgValue = bound(_msgValue, 0, MESSAGE_FEE - 1);
        vm.deal({account: address(leafGauge), newBalance: MESSAGE_FEE});

        vm.expectRevert(ITokenBridge.InsufficientBalance.selector);
        leafEscrowTokenBridge.sendTokenAndLock{value: msgValue}({
            _recipient: _recipient,
            _amount: amount,
            _tokenId: tokenId
        });
    }

    modifier whenTheMsgValueIsGreaterThanOrEqualToQuotedFee(uint256 _msgValue) {
        msgValue = bound(_msgValue, MESSAGE_FEE, MAX_TOKENS);
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint256 _amount,
        address _recipient,
        uint256 _msgValue,
        uint112 _bufferCap
    )
        external
        whenTheTokenIdIsNotZero
        whenTheRequestedAmountIsNotZero(_amount)
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee(_msgValue)
    {
        // It should revert with "RateLimited: buffer cap overflow"
        _bufferCap = bound(_bufferCap, leafXVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        amount = bound(_amount, _bufferCap / 2 + 2, type(uint256).max / 2); // increment by 2 to account for rounding
        uint128 rateLimitPerSecond = Math.min((_bufferCap / 2) / DAY, leafXVelo.maxRateLimitPerSecond()).toUint128();

        vm.startPrank(users.owner);
        leafXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafTokenBridge),
                bufferCap: _bufferCap,
                rateLimitPerSecond: rateLimitPerSecond
            })
        );

        vm.deal({account: address(leafGauge), newBalance: msgValue});
        deal({token: address(leafXVelo), to: address(leafGauge), give: amount});

        vm.startPrank(address(leafGauge));
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        leafEscrowTokenBridge.sendTokenAndLock{value: msgValue}({
            _recipient: _recipient,
            _amount: amount,
            _tokenId: tokenId
        });
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(uint256 _bufferCap, uint256 _amount) {
        _bufferCap = bound(_bufferCap, leafXVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        amount = bound(_amount, WEEK, _bufferCap / 2);
        setLimits({_rootBufferCap: _bufferCap, _leafBufferCap: _bufferCap});
        _;
    }

    function testFuzz_WhenTheAmountIsLargerThanTheBalanceOfCaller(
        uint256 _amount,
        address _recipient,
        uint256 _msgValue,
        uint256 _bufferCap,
        uint256 _balance
    )
        external
        whenTheTokenIdIsNotZero
        whenTheRequestedAmountIsNotZero(_amount)
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee(_msgValue)
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
    {
        // It should revert with {ERC20InsufficientBalance}
        _balance = bound(_balance, 0, amount - 1);
        vm.deal({account: address(leafGauge), newBalance: msgValue});
        deal({token: address(leafXVelo), to: address(leafGauge), give: _balance});

        vm.startPrank(address(leafGauge));
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(leafGauge), _balance, amount)
        );
        leafEscrowTokenBridge.sendTokenAndLock{value: msgValue}({
            _recipient: _recipient,
            _amount: amount,
            _tokenId: tokenId
        });
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller() {
        _;
    }

    function testFuzz_WhenThereIsNoHookSet(
        uint256 _amount,
        address _recipient,
        uint256 _msgValue,
        uint256 _bufferCap,
        uint256 _balance
    )
        external
        whenTheTokenIdIsNotZero
        whenTheRequestedAmountIsNotZero(_amount)
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee(_msgValue)
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
    {
        // It burns the caller's tokens
        // It dispatches a message to the destination mailbox using default quote
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It deposits on the lock with the given tokenId on the destination chain
        _balance = bound(_balance, amount, type(uint256).max / 2);
        msgValue = MESSAGE_FEE;
        vm.deal({account: address(leafGauge), newBalance: msgValue});
        deal({token: address(leafXVelo), to: address(leafGauge), give: _balance});

        vm.startPrank(address(leafGauge));
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        vm.expectEmit(address(leafEscrowTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: root,
            _recipient: TypeCasts.addressToBytes32(address(leafEscrowTokenBridge)),
            _value: msgValue,
            _message: string(abi.encodePacked(_recipient, amount, tokenId)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: msgValue,
                    _gasLimit: leafEscrowTokenBridge.GAS_LIMIT(),
                    _refundAddress: address(leafGauge),
                    _customMetadata: ""
                })
            )
        });
        leafEscrowTokenBridge.sendTokenAndLock{value: msgValue}({
            _recipient: _recipient,
            _amount: amount,
            _tokenId: tokenId
        });

        assertEq(leafXVelo.balanceOf(address(leafGauge)), _balance - amount);
        assertEq(address(leafGauge).balance, msgValue - MESSAGE_FEE);
        assertEq(address(leafEscrowTokenBridge).balance, 0);

        vm.selectFork({forkId: rootId});
        uint256 balBefore = rootRewardToken.balanceOf(_recipient);

        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, amount, tokenId))
        });
        rootMailbox.processNextInboundMessage();
        assertEq(rootXVelo.balanceOf(_recipient), 0);
        assertEq(rootRewardToken.balanceOf(_recipient), balBefore);
        assertEq(mockEscrow.balanceOfNFT(tokenId), lockAmount + amount);
    }

    function testFuzz_WhenThereIsACustomHookSet() external {}
}
