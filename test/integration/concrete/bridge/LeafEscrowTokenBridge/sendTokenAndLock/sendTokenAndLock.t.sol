// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafEscrowTokenBridge.t.sol";

contract SendTokenAndLockIntegrationConcreteTest is LeafEscrowTokenBridgeTest {
    uint256 public amount;
    address public recipient;
    uint256 public tokenId;

    function test_WhenTheTokenIdIsZero() external {
        // It should revert with {ZeroTokenId}
        vm.expectRevert(ILeafEscrowTokenBridge.ZeroTokenId.selector);
        leafEscrowTokenBridge.sendTokenAndLock({_recipient: recipient, _amount: amount, _tokenId: tokenId});
    }

    modifier whenTheTokenIdIsNotZero() {
        vm.selectFork({forkId: rootId});
        // create lock for bob to allow depositFor on root chain
        deal({token: address(rootRewardToken), to: address(users.bob), give: TOKEN_1 * 1000});
        vm.prank(users.bob);
        tokenId = mockEscrow.createLock({_value: TOKEN_1 * 1000, _lockDuration: 1 weeks});
        vm.selectFork({forkId: leafId});
        _;
    }

    function test_WhenTheRequestedAmountIsZero() external whenTheTokenIdIsNotZero {
        // It should revert with {ZeroAmount}
        vm.expectRevert(ITokenBridge.ZeroAmount.selector);
        leafEscrowTokenBridge.sendTokenAndLock({_recipient: recipient, _amount: amount, _tokenId: tokenId});
    }

    modifier whenTheRequestedAmountIsNotZero() {
        amount = TOKEN_1 * 1000;

        vm.selectFork({forkId: rootId});
        // deal tokens to allow unwrapping xerc20
        deal({token: address(rootRewardToken), to: address(rootLockbox), give: amount});
        vm.selectFork({forkId: leafId});
        _;
    }

    function test_WhenTheRecipientIsAddressZero() external whenTheTokenIdIsNotZero whenTheRequestedAmountIsNotZero {
        // It should revert with {ZeroAddress}
        vm.expectRevert(ITokenBridge.ZeroAddress.selector);
        leafEscrowTokenBridge.sendTokenAndLock({_recipient: recipient, _amount: amount, _tokenId: tokenId});
    }

    modifier whenTheRecipientIsNotAddressZero() {
        recipient = address(leafGauge);
        _;
    }

    function test_WhenTheRequestedChainIsNotARegisteredChain()
        external
        whenTheTokenIdIsNotZero
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
    {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        leafEscrowTokenBridge.sendTokenAndLock({_recipient: recipient, _amount: amount, _tokenId: tokenId});
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

    function test_WhenTheMsgValueIsSmallerThanQuotedFee()
        external
        whenTheTokenIdIsNotZero
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with {InsufficientBalance}
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: address(leafGauge), newBalance: ethAmount});

        vm.expectRevert(ITokenBridge.InsufficientBalance.selector);
        leafEscrowTokenBridge.sendTokenAndLock{value: ethAmount - 1}({
            _recipient: recipient,
            _amount: amount,
            _tokenId: tokenId
        });
    }

    modifier whenTheMsgValueIsGreaterThanOrEqualToQuotedFee() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenTheTokenIdIsNotZero
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
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        leafEscrowTokenBridge.sendTokenAndLock{value: ethAmount}({
            _recipient: recipient,
            _amount: amount,
            _tokenId: tokenId
        });
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfCaller()
        external
        whenTheTokenIdIsNotZero
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
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(leafGauge), amount - 1, amount
            )
        );
        leafEscrowTokenBridge.sendTokenAndLock{value: ethAmount}({
            _recipient: recipient,
            _amount: amount,
            _tokenId: tokenId
        });
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller() {
        _;
    }

    function test_WhenThereIsNoHookSet()
        external
        whenTheTokenIdIsNotZero
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
        // It deposits on the lock with the given tokenId on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(leafXVelo), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        vm.expectEmit(address(leafEscrowTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: root,
            _recipient: TypeCasts.addressToBytes32(address(leafEscrowTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount, tokenId)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: leafEscrowTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        leafEscrowTokenBridge.sendTokenAndLock{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _tokenId: tokenId
        });

        assertEq(leafXVelo.balanceOf(users.alice), 0);
        assertEq(address(leafEscrowTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: rootId});
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount, tokenId))
        });
        rootMailbox.processNextInboundMessage();
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(recipient), 0);
        assertEq(mockEscrow.balanceOfNFT(tokenId), TOKEN_1 * 1000 + amount);
    }

    function test_WhenThereIsACustomHookSet()
        external
        whenTheTokenIdIsNotZero
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
        // It deposits on the lock with the given tokenId on the destination chain
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(leafXVelo), to: users.alice, give: amount});

        address hook = address(new MockCustomHook(users.owner, defaultCommands, defaultGasLimits));
        vm.prank(leafEscrowTokenBridge.owner());
        leafEscrowTokenBridge.setHook({_hook: address(hook)});

        vm.startPrank(users.alice);
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        vm.expectEmit(address(leafEscrowTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: root,
            _recipient: TypeCasts.addressToBytes32(address(leafEscrowTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount, tokenId)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: leafEscrowTokenBridge.GAS_LIMIT() * 2, // custom hook returns twice the gas limit
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        leafEscrowTokenBridge.sendTokenAndLock{value: ethAmount + leftoverEth}({
            _recipient: recipient,
            _amount: amount,
            _tokenId: tokenId
        });

        assertEq(leafXVelo.balanceOf(users.alice), 0);
        assertEq(leafXVelo.balanceOf(recipient), 0);
        assertEq(address(leafEscrowTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: rootId});
        vm.expectEmit(address(rootTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: leafDomain,
            _sender: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount, tokenId))
        });
        rootMailbox.processNextInboundMessage();
        assertEq(rootXVelo.balanceOf(recipient), 0);
        assertEq(rootRewardToken.balanceOf(recipient), 0);
        assertEq(mockEscrow.balanceOfNFT(tokenId), TOKEN_1 * 1000 + amount);
    }

    function testGas_sendToken()
        external
        whenTheTokenIdIsNotZero
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
        leafXVelo.approve({spender: address(leafEscrowTokenBridge), value: amount});

        leafEscrowTokenBridge.sendTokenAndLock{value: ethAmount}({
            _recipient: recipient,
            _amount: amount,
            _tokenId: tokenId
        });
        vm.snapshotGasLastCall("LeafEscrowTokenBridge_sendTokenAndLock");
    }
}
