// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootRestrictedTokenBridge.t.sol";

contract SendTokenIntegrationConcreteTest is RootRestrictedTokenBridgeTest {
    uint256 public _amount;
    address public _recipient;
    uint256 public _rewardsLength;
    uint256 public _epochStart;
    uint256 public _tokenRewardsPerEpoch;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork({forkId: leafId});
        _rewardsLength = leafIVR.rewardsListLength();
        _epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        _tokenRewardsPerEpoch = leafIVR.tokenRewardsPerEpoch(address(leafRestrictedRewardToken), _epochStart);
        vm.selectFork({forkId: rootId});
    }

    function test_WhenTheRequestedAmountIsZero() external {
        // It should revert with {ZeroAmount}
        vm.expectRevert(ITokenBridge.ZeroAmount.selector);
        rootRestrictedTokenBridge.sendToken({_recipient: _recipient, _amount: 0, _chainid: leaf});
    }

    modifier whenTheRequestedAmountIsNotZero() {
        _amount = TOKEN_1 * 1000;
        _;
    }

    function test_WhenTheRecipientIsAddressZero() external whenTheRequestedAmountIsNotZero {
        // It should revert with {ZeroAddress}
        vm.expectRevert(ITokenBridge.ZeroAddress.selector);
        rootRestrictedTokenBridge.sendToken({_recipient: address(0), _amount: _amount, _chainid: leaf});
    }

    modifier whenTheRecipientIsNotAddressZero() {
        _recipient = users.alice;
        _;
    }

    function test_WhenTheRequestedChainIsNotARegisteredChain()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
    {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootRestrictedTokenBridge.sendToken({_recipient: _recipient, _amount: _amount, _chainid: leaf});
    }

    modifier whenTheRequestedChainIsARegisteredChain() {
        vm.prank(users.owner);
        rootRestrictedTokenBridge.registerChain({_chainid: leaf});

        vm.selectFork({forkId: leafId});
        vm.prank(users.owner);
        leafRestrictedTokenBridge.registerChain({_chainid: root});
        vm.selectFork({forkId: rootId});
        _;
    }

    function test_WhenTheRecipientIsNotARegisteredGauge()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with {InvalidGauge}
        vm.expectRevert(IRootRestrictedTokenBridge.InvalidGauge.selector);
        rootRestrictedTokenBridge.sendToken({_recipient: address(1), _amount: _amount, _chainid: leaf});
    }

    modifier whenTheRecipientIsARegisteredGauge() {
        _recipient = address(leafGauge);
        _;
    }

    function test_WhenTheGaugeIsNotAlive()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
    {
        // It should revert with {GaugeNotAlive}
        vm.prank(users.owner);
        mockVoter.killGauge({_gauge: _recipient});
        vm.expectRevert(IRootRestrictedTokenBridge.GaugeNotAlive.selector);
        rootRestrictedTokenBridge.sendToken({_recipient: _recipient, _amount: _amount, _chainid: leaf});
    }

    modifier whenTheGaugeIsAlive() {
        _;
    }

    function test_WhenTheGaugesChainidDoesNotMatchDestinationChain()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
    {
        // It should revert with {InvalidChainId}
        vm.mockCall({callee: address(leafGauge), data: abi.encodeWithSignature("chainid()"), returnData: abi.encode(1)});
        vm.expectRevert(IRootRestrictedTokenBridge.InvalidChainId.selector);
        rootRestrictedTokenBridge.sendToken({_recipient: _recipient, _amount: _amount, _chainid: leaf});
    }

    modifier whenTheGaugesChainidMatchesDestinationChain() {
        _;
    }

    function test_WhenTheMsgValueIsSmallerThanQuotedFee()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
    {
        // It should revert with {InsufficientBalance}
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount});

        vm.expectRevert(ITokenBridge.InsufficientBalance.selector);
        rootRestrictedTokenBridge.sendToken{value: ethAmount - 1}({
            _recipient: _recipient,
            _amount: _amount,
            _chainid: leaf
        });
    }

    modifier whenTheMsgValueIsGreaterThanOrEqualToQuotedFee() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
    {
        // It should revert with "RateLimited: buffer cap overflow"
        _amount = 1;
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount});
        deal({token: address(rootIncentiveToken), to: users.alice, give: _amount});

        vm.startPrank(users.alice);
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: _amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        rootRestrictedTokenBridge.sendToken{value: ethAmount}({_recipient: _recipient, _amount: _amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        setLimitsRestricted({_rootBufferCap: _amount * 2, _leafBufferCap: _amount * 2});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It should revert with {ERC20InsufficientBalance}
        uint256 ethAmount = MESSAGE_FEE;
        vm.deal({account: users.alice, newBalance: ethAmount});
        deal({token: address(rootIncentiveToken), to: users.alice, give: _amount - 1});

        vm.startPrank(users.alice);
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: _amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, users.alice, _amount - 1, _amount)
        );
        rootRestrictedTokenBridge.sendToken{value: ethAmount}({_recipient: _recipient, _amount: _amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller() {
        _;
    }

    modifier whenThereIsNoDomainSetForTheChain() {
        vm.startPrank(rootMessageBridge.owner());
        rootMessageModule.setDomain({_chainid: leaf, _domain: 0});
        leafDomain = leaf;

        assertEq(rootMessageModule.domains(leaf), 0);

        rootMailbox.addRemoteMailbox({_domain: leaf, _mailbox: leafMailbox});
        rootMailbox.setDomainForkId({_domain: leaf, _forkId: leafId});

        vm.selectFork({forkId: leafId});

        vm.startPrank(users.deployer);
        MultichainMockMailbox leafMailboxDefaultChainid = new MultichainMockMailbox(leaf);
        vm.mockFunction(
            address(leafMailbox), address(leafMailboxDefaultChainid), abi.encodeWithSelector(Mailbox.process.selector)
        );
        vm.stopPrank();

        vm.selectFork({forkId: rootId});
        _;
    }

    function test_WhenThereIsNoHookSet()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsNoDomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using default quote & chain's domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It should mint tokens to the bridge
        // It should approve the incentive reward contract
        // It should notify reward amount
        // It should emit {ReceivedMessage} event
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        _recipient = address(leafGauge);
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootIncentiveToken), to: users.alice, give: _amount});

        vm.startPrank(users.alice);
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: _amount});

        vm.expectEmit(address(rootRestrictedTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootRestrictedTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(_recipient, _amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: rootRestrictedTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootRestrictedTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: _recipient,
            _amount: _amount,
            _chainid: leaf
        });

        assertEq(rootRestrictedRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRestrictedRewardToken.balanceOf(_recipient), 0);
        assertEq(rootIncentiveToken.balanceOf(users.alice), 0);
        assertEq(rootIncentiveToken.balanceOf(_recipient), 0);
        assertEq(address(rootRestrictedTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafRestrictedTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafRestrictedTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, _amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafRestrictedRewardToken.balanceOf(address(leafIVR)), _amount);

        assertTrue(leafIVR.isReward(address(leafRestrictedRewardToken)));
        assertEq(leafIVR.rewardsListLength(), _rewardsLength + 1);
        assertEq(leafIVR.rewards(_rewardsLength), address(leafRestrictedRewardToken));
        assertEq(
            leafIVR.tokenRewardsPerEpoch(address(leafRestrictedRewardToken), _epochStart),
            _tokenRewardsPerEpoch + _amount
        );
        address[] memory whitelist = leafRestrictedRewardToken.whitelist();
        assertEq(whitelist.length, 2);
        assertEq(whitelist[0], address(leafRestrictedTokenBridge));
        assertEq(whitelist[1], address(leafIVR));
    }

    function test_WhenThereIsACustomHookSet()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsNoDomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using quote from hook & chain's domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It should mint tokens to the bridge
        // It should approve the incentive reward contract
        // It should notify reward amount
        // It should emit {ReceivedMessage} event
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        _recipient = address(leafGauge);
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootIncentiveToken), to: users.alice, give: _amount});

        vm.startPrank(rootRestrictedTokenBridge.owner());
        rootRestrictedTokenBridge.setHook({_hook: address(rootHook)});

        vm.startPrank(users.alice);
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: _amount});

        vm.expectEmit(address(rootRestrictedTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootRestrictedTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(_recipient, _amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: IHookGasEstimator(rootHook).estimateSendTokenGas(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootRestrictedTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: _recipient,
            _amount: _amount,
            _chainid: leaf
        });

        assertEq(rootRestrictedRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRestrictedRewardToken.balanceOf(_recipient), 0);
        assertEq(rootIncentiveToken.balanceOf(users.alice), 0);
        assertEq(rootIncentiveToken.balanceOf(_recipient), 0);
        assertEq(address(rootRestrictedTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafRestrictedTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafRestrictedTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, _amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafRestrictedRewardToken.balanceOf(address(leafIVR)), _amount);

        assertTrue(leafIVR.isReward(address(leafRestrictedRewardToken)));
        assertEq(leafIVR.rewardsListLength(), _rewardsLength + 1);
        assertEq(leafIVR.rewards(_rewardsLength), address(leafRestrictedRewardToken));
        assertEq(
            leafIVR.tokenRewardsPerEpoch(address(leafRestrictedRewardToken), _epochStart),
            _tokenRewardsPerEpoch + _amount
        );
        address[] memory whitelist = leafRestrictedRewardToken.whitelist();
        assertEq(whitelist.length, 2);
        assertEq(whitelist[0], address(leafRestrictedTokenBridge));
        assertEq(whitelist[1], address(leafIVR));
    }

    modifier whenThereIsADomainSetForTheChain() {
        _;
    }

    function test_WhenThereIsNoHookSet_()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsADomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using default quote & chain's custom domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It should mint tokens to the bridge
        // It should approve the incentive reward contract
        // It should notify reward amount
        // It should emit {ReceivedMessage} event
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        _recipient = address(leafGauge);
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootIncentiveToken), to: users.alice, give: _amount});

        vm.startPrank(users.alice);
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: _amount});

        vm.expectEmit(address(rootRestrictedTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootRestrictedTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(_recipient, _amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: rootRestrictedTokenBridge.GAS_LIMIT(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootRestrictedTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: _recipient,
            _amount: _amount,
            _chainid: leaf
        });

        assertEq(rootRestrictedRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRestrictedRewardToken.balanceOf(_recipient), 0);
        assertEq(rootIncentiveToken.balanceOf(users.alice), 0);
        assertEq(rootIncentiveToken.balanceOf(_recipient), 0);
        assertEq(address(rootRestrictedTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafRestrictedTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafRestrictedTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, _amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafRestrictedRewardToken.balanceOf(address(leafIVR)), _amount);

        assertTrue(leafIVR.isReward(address(leafRestrictedRewardToken)));
        assertEq(leafIVR.rewardsListLength(), _rewardsLength + 1);
        assertEq(leafIVR.rewards(_rewardsLength), address(leafRestrictedRewardToken));
        assertEq(
            leafIVR.tokenRewardsPerEpoch(address(leafRestrictedRewardToken), _epochStart),
            _tokenRewardsPerEpoch + _amount
        );
        address[] memory whitelist = leafRestrictedRewardToken.whitelist();
        assertEq(whitelist.length, 2);
        assertEq(whitelist[0], address(leafRestrictedTokenBridge));
        assertEq(whitelist[1], address(leafIVR));
    }

    function test_WhenThereIsACustomHookSet_()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsADomainSetForTheChain
    {
        // It pulls the caller's tokens
        // It wraps to xerc20
        // It burns the newly minted xerc20 tokens
        // It dispatches a message to the destination mailbox using quote from hook & chain's custom domain
        // It refunds any excess value
        // It emits a {SentMessage} event
        // It should mint tokens to the bridge
        // It should approve the incentive reward contract
        // It should notify reward amount
        // It should emit {ReceivedMessage} event
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        _recipient = address(leafGauge);
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootIncentiveToken), to: users.alice, give: _amount});

        vm.startPrank(rootRestrictedTokenBridge.owner());
        rootRestrictedTokenBridge.setHook({_hook: address(rootHook)});

        vm.startPrank(users.alice);
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: _amount});

        vm.expectEmit(address(rootRestrictedTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootRestrictedTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(_recipient, _amount)),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount + leftoverEth,
                    _gasLimit: IHookGasEstimator(rootHook).estimateSendTokenGas(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootRestrictedTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: _recipient,
            _amount: _amount,
            _chainid: leaf
        });

        assertEq(rootRestrictedRewardToken.balanceOf(users.alice), 0);
        assertEq(rootRestrictedRewardToken.balanceOf(_recipient), 0);
        assertEq(rootIncentiveToken.balanceOf(users.alice), 0);
        assertEq(rootIncentiveToken.balanceOf(_recipient), 0);
        assertEq(address(rootRestrictedTokenBridge).balance, 0);
        assertEq(users.alice.balance, leftoverEth);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafRestrictedTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: TypeCasts.addressToBytes32(address(leafRestrictedTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(_recipient, _amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafRestrictedRewardToken.balanceOf(address(leafIVR)), _amount);

        assertTrue(leafIVR.isReward(address(leafRestrictedRewardToken)));
        assertEq(leafIVR.rewardsListLength(), _rewardsLength + 1);
        assertEq(leafIVR.rewards(_rewardsLength), address(leafRestrictedRewardToken));
        assertEq(
            leafIVR.tokenRewardsPerEpoch(address(leafRestrictedRewardToken), _epochStart),
            _tokenRewardsPerEpoch + _amount
        );
        address[] memory whitelist = leafRestrictedRewardToken.whitelist();
        assertEq(whitelist.length, 2);
        assertEq(whitelist[0], address(leafRestrictedTokenBridge));
        assertEq(whitelist[1], address(leafIVR));
    }

    function testGas_sendToken()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheRecipientIsARegisteredGauge
        whenTheGaugeIsAlive
        whenTheGaugesChainidMatchesDestinationChain
        whenTheMsgValueIsGreaterThanOrEqualToQuotedFee
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
        whenTheAmountIsLessThanOrEqualToTheBalanceOfCaller
        whenThereIsADomainSetForTheChain
    {
        uint256 leftoverEth = TOKEN_1;
        uint256 ethAmount = MESSAGE_FEE;
        _recipient = address(leafGauge);
        vm.deal({account: users.alice, newBalance: ethAmount + leftoverEth});
        deal({token: address(rootIncentiveToken), to: users.alice, give: _amount});

        vm.startPrank(users.alice);
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: _amount});

        rootRestrictedTokenBridge.sendToken{value: ethAmount + leftoverEth}({
            _recipient: _recipient,
            _amount: _amount,
            _chainid: leaf
        });
        vm.snapshotGasLastCall("RootRestrictedTokenBridge_sendToken");
    }
}
