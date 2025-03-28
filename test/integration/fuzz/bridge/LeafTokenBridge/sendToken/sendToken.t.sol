// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafTokenBridge.t.sol";

contract SendTokenIntegrationFuzzTest is LeafTokenBridgeTest {
    uint256 public amount;

    modifier whenTheRequestedAmountIsNotZero() {
        _;
    }

    modifier whenTheRecipientIsNotAddressZero() {
        _;
    }

    modifier whenTheRequestedChainIsARegisteredChain() {
        vm.prank(users.owner);
        leafTokenBridge.registerChain({_chainid: rootDomain});

        vm.selectFork({forkId: rootId});
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});
        vm.selectFork({forkId: leafId});
        _;
    }

    function testFuzz_WhenTheMsgValueIsSmallerThanQuotedFee(address _recipient, uint256 _msgValue)
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with {InsufficientBalance}
        _msgValue = bound(_msgValue, 0, MESSAGE_FEE - 1);
        vm.deal({account: address(leafGauge), newBalance: MESSAGE_FEE});
        vm.assume(_recipient != address(0));

        vm.expectRevert(ITokenBridge.InsufficientBalance.selector);
        leafTokenBridge.sendToken{value: _msgValue}({_recipient: _recipient, _amount: TOKEN_1, _chainid: rootDomain});
    }

    modifier whenTheMsgValueIsGreaterThanOrEqualToQuotedFee() {
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint256 _bufferCap,
        uint256 _amount,
        address _recipient
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
    {
        // It should revert with "RateLimited: buffer cap overflow"
        _bufferCap = bound(_bufferCap, leafXVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        amount = bound(_amount, _bufferCap / 2 + 2, type(uint256).max / 2); // increment by 2 to account for rounding
        vm.assume(_recipient != address(0));

        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(leafGauge), newBalance: ethAmount});
        deal({token: address(leafXVelo), to: address(leafGauge), give: amount});
        setLimits({_rootBufferCap: _bufferCap, _leafBufferCap: _bufferCap});

        vm.startPrank(address(leafGauge));
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        leafTokenBridge.sendToken{value: ethAmount}({_recipient: _recipient, _amount: amount, _chainid: rootDomain});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(uint256 _bufferCap, uint256 _amount) {
        _bufferCap = bound(_bufferCap, leafXVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        amount = bound(_amount, WEEK, _bufferCap / 2);
        setLimits({_rootBufferCap: _bufferCap, _leafBufferCap: _bufferCap});
        _;
    }

    function testFuzz_WhenTheAmountIsLargerThanTheBalanceOfCaller(
        uint256 _bufferCap,
        uint256 _amount,
        address _recipient,
        uint256 _balance
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
    {
        // It should revert with {ERC20InsufficientBalance}
        _balance = bound(_balance, 0, amount - 1);
        vm.assume(_recipient != address(0));
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(leafGauge), newBalance: ethAmount});
        deal({token: address(leafXVelo), to: address(leafGauge), give: _balance});

        vm.startPrank(address(leafGauge));
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(leafGauge), _balance, amount)
        );
        leafTokenBridge.sendToken{value: ethAmount}({_recipient: _recipient, _amount: amount, _chainid: rootDomain});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller() {
        _;
    }

    function testFuzz_WhenThereIsNoHookSet(
        uint256 _bufferCap,
        uint256 _amount,
        uint256 _msgValue,
        uint256 _balance,
        address _recipient
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
    {
        // It burns the caller's tokens
        // It dispatches a message to the destination mailbox
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It sends the amount of unwrapped tokens to the caller on the destination chain
        _msgValue = bound(_msgValue, MESSAGE_FEE, MAX_TOKENS);
        _balance = bound(_balance, amount, type(uint256).max / 2);
        vm.assume(_recipient != address(0));

        vm.deal({account: users.alice, newBalance: _msgValue});
        deal({token: address(leafXVelo), to: users.alice, give: _balance});

        vm.startPrank(users.alice);
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        vm.expectEmit(address(leafTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: rootDomain,
            _recipient: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: MESSAGE_FEE,
            _message: string(abi.encodePacked(_recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: _msgValue,
                    _gasLimit: leafTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        leafTokenBridge.sendToken{value: _msgValue}({_recipient: _recipient, _amount: amount, _chainid: rootDomain});

        assertEq(leafXVelo.balanceOf(users.alice), _balance - amount);
        assertEq(users.alice.balance, _msgValue - MESSAGE_FEE);
        assertEq(address(leafTokenBridge).balance, 0);

        vm.selectFork({forkId: rootId});
        // deal tokens to allow unwrapping xerc20
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, amount))
        });
        rootMailbox.processNextInboundMessage();
        assertEq(rootXVelo.balanceOf(_recipient), 0);
        assertEq(rootRewardToken.balanceOf(_recipient), amount);
    }

    function testFuzz_WhenThereIsACustomHookSet() external {}
}
