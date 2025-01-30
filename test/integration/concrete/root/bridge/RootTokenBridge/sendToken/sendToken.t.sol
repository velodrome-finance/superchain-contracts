// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootTokenBridge.t.sol";

contract SendTokenIntegrationConcreteTest is RootTokenBridgeTest {
    uint256 public amount;
    address public recipient;

    function test_WhenTheRequestedAmountIsZero() external {
        // It should revert with {ZeroAmount}
        vm.expectRevert(ITokenBridge.ZeroAmount.selector);
        rootTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: leaf});
    }

    modifier whenTheRequestedAmountIsNotZero() {
        amount = TOKEN_1 * 1000;
        _;
    }

    function test_WhenTheRecipientIsAddressZero() external whenTheRequestedAmountIsNotZero {
        // It should revert with {ZeroAddress}
        vm.expectRevert(ITokenBridge.ZeroAddress.selector);
        rootTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: leaf});
    }

    modifier whenTheRecipientIsNotAddressZero() {
        recipient = address(rootGauge);
        _;
    }

    function test_WhenTheRequestedChainIsNotARegisteredChain()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
    {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: leaf});
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

    function test_WhenTheMsgValueIsSmallerThanQuotedFee()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with {InsufficientBalance}
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(rootGauge), newBalance: ethAmount});

        vm.expectRevert(ITokenBridge.InsufficientBalance.selector);
        rootTokenBridge.sendToken{value: ethAmount - 1}({_recipient: recipient, _amount: amount, _chainid: leaf});
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
        vm.deal({account: address(rootGauge), newBalance: ethAmount});
        deal({token: address(rootRewardToken), to: address(rootGauge), give: amount});

        vm.startPrank(address(rootGauge));
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        rootTokenBridge.sendToken{value: ethAmount}({_recipient: recipient, _amount: amount, _chainid: leaf});
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
        vm.deal({account: address(rootGauge), newBalance: ethAmount});
        deal({token: address(rootRewardToken), to: address(rootGauge), give: amount - 1});

        vm.startPrank(address(rootGauge));
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), amount - 1, amount
            )
        );
        rootTokenBridge.sendToken{value: ethAmount}({_recipient: recipient, _amount: amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller() {
        _;
    }

    modifier whenThereIsNoDomainSetForTheChain() {
        vm.startPrank(rootMessageBridge.owner());
        rootMessageModule.setDomain({_chainid: leaf, _domain: 0});
        // @dev if domain not linked to chain, domain should be equal to chainid
        leafDomain = leaf;

        assertEq(rootMessageModule.domains(leaf), 0);

        rootMailbox.addRemoteMailbox({_domain: leaf, _mailbox: leafMailbox});
        rootMailbox.setDomainForkId({_domain: leaf, _forkId: leafId});

        vm.selectFork({forkId: leafId});

        vm.startPrank(users.deployer);
        // Deploy mock mailbox with leaf chainid as domain
        MultichainMockMailbox leafMailboxDefaultChainid = new MultichainMockMailbox(leaf);
        // Mock `mailbox.process()` to process messages using leaf chainid as domain
        vm.mockFunction(
            address(leafMailbox), address(leafMailboxDefaultChainid), abi.encodeWithSelector(Mailbox.process.selector)
        );

        vm.startPrank(rootMessageBridge.owner());
        vm.selectFork({forkId: rootId});
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
        whenThereIsNoDomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using default quote & chain as domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootRewardToken), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: rootTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _chainid: leaf
        });

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRewardToken.balanceOf(recipient), 0);
        assertEq(address(rootTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(recipient), amount);
    }

    function test_WhenThereIsACustomHookSet()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsNoDomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using quote from hook & chain as domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootRewardToken), to: users.alice, give: amount});

        address hook = address(new MockCustomHook());
        vm.startPrank(rootTokenBridge.owner());
        rootTokenBridge.setHook({_hook: address(hook)});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: rootTokenBridge.GAS_LIMIT() * 2, // custom hook returns twice the gas limit
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _chainid: leaf
        });

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRewardToken.balanceOf(recipient), 0);
        assertEq(address(rootTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(recipient), amount);
    }

    modifier whenThereIsADomainSetForTheChain() {
        _;
    }

    function test_WhenThereIsNoHookSet_()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsADomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using default quote & the chain's domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootRewardToken), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        address hook = address(new MockCustomHook());
        vm.startPrank(rootTokenBridge.owner());
        rootTokenBridge.setHook({_hook: address(hook)});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: rootTokenBridge.GAS_LIMIT() * 2, // custom hook returns twice the gas limit
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _chainid: leaf
        });

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRewardToken.balanceOf(recipient), 0);
        assertEq(address(rootTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(recipient), amount);
    }

    function test_WhenThereIsACustomHookSet_()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsADomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using quote from hook & the chain's domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootRewardToken), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: rootTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _chainid: leaf
        });

        assertEq(rootXVelo.balanceOf(users.alice), 0);
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRewardToken.balanceOf(recipient), 0);
        assertEq(address(rootTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(recipient), amount);
    }

    function testGas_sendToken()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsNoDomainSetForTheChain
    {
        uint256 ethAmount = MESSAGE_FEE + TOKEN_1;
        vm.deal({account: users.alice, newBalance: ethAmount});
        deal({token: address(rootRewardToken), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        rootRewardToken.approve({spender: address(rootTokenBridge), value: amount});

        rootTokenBridge.sendToken{value: ethAmount}({_recipient: recipient, _amount: amount, _chainid: leaf});
        vm.snapshotGasLastCall("RootTokenBridge_sendToken");
    }
}
