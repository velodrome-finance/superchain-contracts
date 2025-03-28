// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootTokenBridge.t.sol";

contract SendTokenIntegrationFuzzTest is RootTokenBridgeTest {
    uint256 public amount;
    uint256 public balance;

    modifier whenTheRequestedAmountIsNotZero() {
        _;
    }

    modifier whenTheRecipientIsNotAddressZero(address _recipient) {
        vm.assume(_recipient != address(0));
        _;
    }

    modifier whenTheRequestedChainIsARegisteredChain() {
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});

        vm.selectFork({forkId: leafId});
        vm.prank(users.owner);
        leafTokenBridge.registerChain({_chainid: root});
        vm.selectFork({forkId: rootId});
        _;
    }

    function testFuzz_WhenTheMsgValueIsSmallerThanQuotedFee(address _recipient, uint256 _msgValue)
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with {InsufficientBalance}
        _msgValue = bound(_msgValue, 0, MESSAGE_FEE - 1);
        vm.deal({account: address(rootGauge), newBalance: MESSAGE_FEE});

        vm.expectRevert(ITokenBridge.InsufficientBalance.selector);
        rootTokenBridge.sendToken{value: _msgValue}({_recipient: _recipient, _amount: TOKEN_1, _chainid: leaf});
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
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
    {
        // It should revert with "RateLimited: buffer cap overflow"
        _bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        amount = bound(_amount, _bufferCap / 2 + 2, type(uint256).max / 2); // increment by 2 to account for rounding

        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(rootGauge), newBalance: ethAmount});
        deal({token: address(rootRewardToken), to: address(rootGauge), give: amount});
        setLimits({_rootBufferCap: _bufferCap, _leafBufferCap: _bufferCap});

        vm.startPrank(address(rootGauge));
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        rootTokenBridge.sendToken{value: ethAmount}({_recipient: _recipient, _amount: amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(uint256 _bufferCap, uint256 _amount) {
        _bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
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
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
    {
        // It should revert with {ERC20InsufficientBalance}
        _balance = bound(_balance, 0, amount - 1);
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(rootGauge), newBalance: ethAmount});
        deal({token: address(rootRewardToken), to: address(rootGauge), give: _balance});

        vm.startPrank(address(rootGauge));
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), _balance, amount)
        );
        rootTokenBridge.sendToken{value: ethAmount}({_recipient: _recipient, _amount: amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller(uint256 _balance) {
        balance = bound(_balance, amount, type(uint256).max / 2);
        _;
    }

    modifier whenThereIsADomainSetForTheChain() {
        _;
    }

    modifier whenThereIsNoHookSet() {
        _;
    }

    function testFuzz_WhenTheCallerIsNotWhitelisted(
        uint256 _bufferCap,
        uint256 _amount,
        uint256 _msgValue,
        uint256 _balance,
        address _recipient
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller(_balance)
        whenThereIsADomainSetForTheChain
        whenThereIsNoHookSet
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using default quote & chain as domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        _msgValue = bound(_msgValue, MESSAGE_FEE, MAX_TOKENS);

        vm.deal({account: users.alice, newBalance: _msgValue});
        deal({token: address(rootRewardToken), to: users.alice, give: balance});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: MESSAGE_FEE,
            _message: string(abi.encodePacked(_recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: _msgValue,
                    _gasLimit: rootTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: _msgValue}({_recipient: _recipient, _amount: amount, _chainid: leaf});

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertApproxEqAbs(rootRewardToken.balanceOf(users.alice), balance - amount, 1e18);
        assertEq(users.alice.balance, _msgValue - MESSAGE_FEE);
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(_recipient), amount);
    }

    function testFuzz_WhenTheCallerIsWhitelisted(
        uint256 _bufferCap,
        uint256 _amount,
        uint256 _msgValue,
        uint256 _balance,
        address _recipient
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller(_balance)
        whenThereIsADomainSetForTheChain
        whenThereIsNoHookSet
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using default quote & chain as domain
        // It pays for dispatch using weth from paymaster
        // It refunds any msg value to caller
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        _msgValue = bound(_msgValue, 0, MAX_TOKENS);

        vm.deal({account: users.alice, newBalance: _msgValue});
        deal({token: address(rootRewardToken), to: users.alice, give: balance});

        vm.startPrank(rootTokenBridge.owner());
        rootTokenBridge.whitelistForSponsorship({_account: users.alice, _state: true});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        uint256 paymasterBalBefore = address(rootTokenBridgeVault).balance;

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: MESSAGE_FEE,
            _message: string(abi.encodePacked(_recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: MESSAGE_FEE,
                    _gasLimit: rootTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: _msgValue}({_recipient: _recipient, _amount: amount, _chainid: leaf});

        /// @dev Transaction sponsored by Paymaster, msg value refunded to caller
        assertEq(address(rootTokenBridgeVault).balance, paymasterBalBefore - MESSAGE_FEE);
        assertEq(users.alice.balance, _msgValue);

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertApproxEqAbs(rootRewardToken.balanceOf(users.alice), balance - amount, 1e18);
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(_recipient), amount);
    }

    modifier whenThereIsACustomHookSet() {
        vm.startPrank(rootTokenBridge.owner());
        rootTokenBridge.setHook({_hook: address(rootHook)});
        _;
    }

    function testFuzz_WhenTheCallerIsNotWhitelisted_(
        uint256 _bufferCap,
        uint256 _amount,
        uint256 _msgValue,
        uint256 _balance,
        address _recipient
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller(_balance)
        whenThereIsADomainSetForTheChain
        whenThereIsACustomHookSet
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using quote from hook & chain as domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        _msgValue = bound(_msgValue, MESSAGE_FEE, MAX_TOKENS);

        vm.deal({account: users.alice, newBalance: _msgValue});
        deal({token: address(rootRewardToken), to: users.alice, give: balance});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: MESSAGE_FEE,
            _message: string(abi.encodePacked(_recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: _msgValue,
                    _gasLimit: rootTokenBridge.GAS_LIMIT() * 2, // custom hook returns twice the gas limit
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: _msgValue}({_recipient: _recipient, _amount: amount, _chainid: leaf});

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertApproxEqAbs(rootRewardToken.balanceOf(users.alice), balance - amount, 1e18);
        assertEq(users.alice.balance, _msgValue - MESSAGE_FEE);
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(_recipient), amount);
    }

    function testFuzz_WhenTheCallerIsWhitelisted_(
        uint256 _bufferCap,
        uint256 _amount,
        uint256 _msgValue,
        uint256 _balance,
        address _recipient
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero(_recipient)
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller(_balance)
        whenThereIsADomainSetForTheChain
        whenThereIsACustomHookSet
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using quote from hook & chain as domain
        // It pays for dispatch using weth from paymaster
        // It refunds any msg value to caller
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        _msgValue = bound(0, MESSAGE_FEE, MAX_TOKENS);

        vm.deal({account: users.alice, newBalance: _msgValue});
        deal({token: address(rootRewardToken), to: users.alice, give: balance});

        vm.startPrank(rootTokenBridge.owner());
        rootTokenBridge.whitelistForSponsorship({_account: users.alice, _state: true});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        uint256 paymasterBalBefore = address(rootTokenBridgeVault).balance;

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: MESSAGE_FEE,
            _message: string(abi.encodePacked(_recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: MESSAGE_FEE,
                    _gasLimit: rootTokenBridge.GAS_LIMIT() * 2, // custom hook returns twice the gas limit
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: _msgValue}({_recipient: _recipient, _amount: amount, _chainid: leaf});

        /// @dev Transaction sponsored by Paymaster, msg value refunded to caller
        assertEq(address(rootTokenBridgeVault).balance, paymasterBalBefore - MESSAGE_FEE);
        assertEq(users.alice.balance, _msgValue);

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertApproxEqAbs(rootRewardToken.balanceOf(users.alice), balance - amount, 1e18);
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(_recipient), amount);
    }

    modifier whenThereIsNoDomainSetForTheChain() {
        _;
    }

    modifier whenThereIsNoHookSet_() {
        _;
    }

    function testFuzz_WhenTheCallerIsNotWhitelisted__() external {}

    function testFuzz_WhenTheCallerIsWhitelisted__() external {}

    modifier whenThereIsACustomHookSet_() {
        _;
    }

    function testFuzz_WhenTheCallerIsNotWhitelisted___() external {}

    function testFuzz_WhenTheCallerIsWhitelisted___() external {}
}
