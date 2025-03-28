// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootFeesVotingReward.t.sol";

contract GetRewardIntegrationConcreteTest is RootFeesVotingRewardTest {
    uint256 public tokenId = 1;

    function setUp() public override {
        super.setUp();

        // Notify rewards contracts
        vm.selectFork({forkId: leafId});
        deal(address(token0), address(leafGauge), TOKEN_1);
        deal(address(token1), address(leafGauge), TOKEN_1);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), TOKEN_1);
        token1.approve(address(leafFVR), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token1), TOKEN_1);

        // Deposit & Skip to next Epoch to vest rewards
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({amount: TOKEN_1, tokenId: tokenId, timestamp: block.timestamp});
        vm.stopPrank();

        skipToNextEpoch(1 hours + 1);

        vm.selectFork({forkId: rootId});
        vm.prank(users.alice);
        mockEscrow.createLock(TOKEN_1, WEEK);

        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});

        deal({token: address(weth), to: users.bob, give: MESSAGE_FEE});
        vm.prank(users.bob);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});
    }

    modifier whenCallerIsNotApprovedOrOwnerOfTokenId() {
        _;
    }

    function test_WhenCallerIsNotVoter() external whenCallerIsNotApprovedOrOwnerOfTokenId {
        // It should revert with {NotAuthorized}
        address[] memory tokens = new address[](0);
        vm.prank(users.charlie);
        vm.expectRevert(IRootIncentiveVotingReward.NotAuthorized.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    modifier whenCallerIsVoter() {
        vm.startPrank({msgSender: address(mockVoter), txOrigin: users.alice});
        _;
    }

    function test_WhenNumberOfTokensToBeClaimedExceedsMaxRewards()
        external
        whenCallerIsNotApprovedOrOwnerOfTokenId
        whenCallerIsVoter
    {
        // It should revert with {MaxTokensExceeded}
        address[] memory tokens = new address[](rootFVR.MAX_REWARDS() + 1);

        vm.expectRevert(IRootIncentiveVotingReward.MaxTokensExceeded.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    modifier whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards() {
        _;
    }

    modifier whenOwnerOfTokenIdIsAContract() {
        vm.mockCall(
            address(mockEscrow),
            abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId),
            abi.encode(address(mockVoter))
        );
        _;
    }

    function test_WhenRecipientIsNotSetOnTheFactory()
        external
        whenCallerIsNotApprovedOrOwnerOfTokenId
        whenCallerIsVoter
        whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards
        whenOwnerOfTokenIdIsAContract
    {
        // It should revert with RecipientNotSet
        address[] memory tokens = new address[](0);
        vm.expectRevert(IRootIncentiveVotingReward.RecipientNotSet.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    function test_WhenRecipientIsSetOnTheFactory()
        external
        whenCallerIsNotApprovedOrOwnerOfTokenId
        whenCallerIsVoter
        whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards
        whenOwnerOfTokenIdIsAContract
    {
        // It should encode the recipient, token id and token addresses
        // It should forward the message to the corresponding incentive rewards contract on the leaf chain
        // It should claim rewards for recipient on the leaf incentive voting contract
        // It should update lastEarn timestamp for token id on leaf incentive voting rewards contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        rootVotingRewardsFactory.setRecipient({_chainid: leaf, _recipient: users.alice});

        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});

        vm.selectFork({forkId: leafId});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
    }

    function test_WhenOwnerOfTokenIdIsAnEOA()
        external
        whenCallerIsNotApprovedOrOwnerOfTokenId
        whenCallerIsVoter
        whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards
    {
        // It should encode the recipient, token id and token addresses
        // It should forward the message to the corresponding incentive rewards contract on the leaf chain
        // It should claim rewards for recipient on the leaf incentive voting contract
        // It should update lastEarn timestamp for token id on leaf incentive voting rewards contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});

        vm.selectFork({forkId: leafId});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
    }

    modifier whenCallerIsApprovedOrOwnerOfTokenId() {
        vm.prank(users.alice);
        mockEscrow.approve(users.bob, tokenId);
        _;
    }

    function test_WhenNumberOfTokensToBeClaimedExceedsMaxRewards_() external whenCallerIsApprovedOrOwnerOfTokenId {
        // It should revert with {MaxTokensExceeded}
        address[] memory tokens = new address[](rootFVR.MAX_REWARDS() + 1);

        vm.startPrank({msgSender: users.bob, txOrigin: users.bob});
        vm.expectRevert(IRootIncentiveVotingReward.MaxTokensExceeded.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    modifier whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards_() {
        _;
    }

    modifier whenOwnerOfTokenIdIsAContract_() {
        vm.mockCall(
            address(mockEscrow),
            abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId),
            abi.encode(address(mockVoter))
        );
        _;
    }

    function test_WhenRecipientIsNotSetOnTheFactory_()
        external
        whenCallerIsApprovedOrOwnerOfTokenId
        whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards_
        whenOwnerOfTokenIdIsAContract_
    {
        // It should revert with RecipientNotSet
        address[] memory tokens = new address[](0);
        vm.startPrank({msgSender: users.bob, txOrigin: users.bob});
        vm.expectRevert(IRootIncentiveVotingReward.RecipientNotSet.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    function test_WhenRecipientIsSetOnTheFactory_()
        external
        whenCallerIsApprovedOrOwnerOfTokenId
        whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards_
        whenOwnerOfTokenIdIsAContract_
    {
        // It should encode the recipient, token id and token addresses
        // It should forward the message to the corresponding incentive rewards contract on the leaf chain
        // It should claim rewards for recipient on the leaf incentive voting contract
        // It should update lastEarn timestamp for token id on leaf incentive voting rewards contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        vm.prank({msgSender: address(mockVoter)});
        rootVotingRewardsFactory.setRecipient({_chainid: leaf, _recipient: users.alice});

        vm.startPrank({msgSender: users.bob, txOrigin: users.bob});
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});

        vm.selectFork({forkId: leafId});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
    }

    function test_WhenOwnerOfTokenIdIsAnEOA_()
        external
        whenCallerIsApprovedOrOwnerOfTokenId
        whenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards_
    {
        // It should encode the recipient, token id and token addresses
        // It should forward the message to the corresponding incentive rewards contract on the leaf chain
        // It should claim rewards for recipient on the leaf incentive voting contract
        // It should update lastEarn timestamp for token id on leaf incentive voting rewards contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        vm.startPrank({msgSender: users.bob, txOrigin: users.bob});
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});

        vm.selectFork({forkId: leafId});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
    }

    function testGas_RootFeesVotingReward_getReward() external whenCallerIsApprovedOrOwnerOfTokenId {
        // Skip distribute window
        vm.warp({newTimestamp: VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1});

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        vm.prank({msgSender: users.bob, txOrigin: users.bob});
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
        vm.snapshotGasLastCall("RootFeesVotingReward_getReward");
    }
}
