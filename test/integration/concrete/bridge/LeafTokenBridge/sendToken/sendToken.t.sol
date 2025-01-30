// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafTokenBridge.t.sol";

contract SendTokenIntegrationConcreteTest is LeafTokenBridgeTest {
    uint256 public amount;
    address public recipient;

    function test_WhenTheRequestedAmountIsZero() external {
        // It should revert with {ZeroAmount}
        vm.expectRevert(ITokenBridge.ZeroAmount.selector);
        leafTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: rootDomain});
    }

    modifier whenTheRequestedAmountIsNotZero() {
        amount = TOKEN_1 * 1000;

        vm.selectFork({forkId: rootId});
        // deal tokens to allow unwrapping xerc20
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});
        vm.selectFork({forkId: leafId});
        _;
    }

    function test_WhenTheRecipientIsAddressZero() external whenTheRequestedAmountIsNotZero {
        // It should revert with {ZeroAddress}
        vm.expectRevert(ITokenBridge.ZeroAddress.selector);
        leafTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: rootDomain});
    }

    modifier whenTheRecipientIsNotAddressZero() {
        recipient = address(leafGauge);
        _;
    }

    function test_WhenTheRequestedChainIsNotARegisteredChain()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
    {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        leafTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: rootDomain});
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

    function test_WhenTheMsgValueIsSmallerThanQuotedFee()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with {InsufficientBalance}
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(leafGauge), newBalance: ethAmount});

        vm.expectRevert(ITokenBridge.InsufficientBalance.selector);
        leafTokenBridge.sendToken{value: ethAmount - 1}({_recipient: recipient, _amount: amount, _chainid: rootDomain});
    }

    modifier whenTheMsgValueIsGreaterThanOrEqualToQuotedFee() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
    {
        // It should revert with "RateLimited: buffer cap overflow"
        amount = 1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(leafGauge), newBalance: ethAmount});
        deal({token: address(leafXVelo), to: address(leafGauge), give: amount});

        vm.startPrank(address(leafGauge));
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        leafTokenBridge.sendToken{value: ethAmount}({_recipient: recipient, _amount: amount, _chainid: rootDomain});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It should revert with {ERC20InsufficientBalance}
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(leafGauge), newBalance: ethAmount});
        deal({token: address(leafXVelo), to: address(leafGauge), give: amount - 1});

        vm.startPrank(address(leafGauge));
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(leafGauge), amount - 1, amount
            )
        );
        leafTokenBridge.sendToken{value: ethAmount}({_recipient: recipient, _amount: amount, _chainid: rootDomain});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller() {
        _;
    }

    function test_WhenThereIsNoHookSet()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
    {
        // It burns the caller's tokens
        // It dispatches a message to the destination mailbox using default quote
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It sends the amount of unwrapped tokens to the caller on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(leafXVelo), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        vm.expectEmit(address(leafTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: rootDomain,
            _recipient: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: leafTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        leafTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _chainid: rootDomain
        });

        assertEq(leafXVelo.balanceOf(users.alice), 0);
        assertEq(address(leafTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: rootId});
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount))
        });
        rootMailbox.processNextInboundMessage();
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(recipient), amount);
    }

    function test_WhenThereIsACustomHookSet()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
    {
        // It burns the caller's tokens
        // It dispatches a message to the destination mailbox using quote from hook
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It sends the amount of unwrapped tokens to the caller on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(leafXVelo), to: users.alice, give: amount});

        address hook = address(new MockCustomHook(users.owner, defaultCommands, defaultGasLimits));
        vm.prank(leafTokenBridge.owner());
        leafTokenBridge.setHook({_hook: address(hook)});

        vm.startPrank(users.alice);
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        vm.expectEmit(address(leafTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: rootDomain,
            _recipient: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: leafTokenBridge.GAS_LIMIT() * 2, // custom hook returns twice the gas limit
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        leafTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _chainid: rootDomain
        });

        assertEq(leafXVelo.balanceOf(users.alice), 0);
        assertEq(leafXVelo.balanceOf(recipient), 0);
        assertEq(address(leafTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: rootId});
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount))
        });
        rootMailbox.processNextInboundMessage();
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(recipient), amount);
    }

    function testGas_sendToken()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        uint256 ethAmount = MESSAGE_FEE + TOKEN_1;
        vm.deal({account: users.alice, newBalance: ethAmount});
        deal({token: address(leafXVelo), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        leafXVelo.approve({spender: address(leafTokenBridge), value: amount});

        leafTokenBridge.sendToken{value: ethAmount}({_recipient: recipient, _amount: amount, _chainid: rootDomain});
        vm.snapshotGasLastCall("TokenBridge_sendToken");
    }
}
