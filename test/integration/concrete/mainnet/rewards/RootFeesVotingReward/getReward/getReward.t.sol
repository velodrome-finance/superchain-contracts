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
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({_payload: depositPayload});
        vm.stopPrank();

        skipToNextEpoch(1);

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
        // It should revert with NotAuthorized
        address[] memory tokens = new address[](0);
        vm.prank(users.charlie);
        vm.expectRevert(IRootBribeVotingReward.NotAuthorized.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    modifier whenCallerIsVoter() {
        _;
    }

    function test_WhenNumberOfTokensToBeClaimedExceedsMaxRewards()
        external
        whenCallerIsNotApprovedOrOwnerOfTokenId
        whenCallerIsVoter
    {
        // It should revert with {MaxTokensExceeded}
        address[] memory tokens = new address[](rootIVR.MAX_REWARDS() + 1);

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectRevert(IRootFeesVotingReward.MaxTokensExceeded.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    function test_WhenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards()
        external
        whenCallerIsNotApprovedOrOwnerOfTokenId
        whenCallerIsVoter
    {
        // It should encode the owner, token id and token addresses
        // It should forward the message to the corresponding fees reward contract on the leaf chain
        // It should claim rewards for owner on the leaf fees voting contract
        // It should update lastEarn timestamp for token id on leaf fees voting rewards contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
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

        vm.prank({msgSender: users.bob, txOrigin: users.bob});
        vm.expectRevert(IRootBribeVotingReward.MaxTokensExceeded.selector);
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    function test_WhenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards_()
        external
        whenCallerIsApprovedOrOwnerOfTokenId
    {
        // It should encode the owner, token id and token addresses
        // It should forward the message to the corresponding fees reward contract on the leaf chain
        // It should claim rewards for owner on the leaf fees voting contract
        // It should update lastEarn timestamp for token id on leaf fees voting rewards contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        vm.prank({msgSender: users.bob, txOrigin: users.bob});
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

    function testGas_WhenNumberOfTokensToBeClaimedDoesNotExceedMaxRewards_()
        external
        whenCallerIsApprovedOrOwnerOfTokenId
    {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        vm.prank({msgSender: users.bob, txOrigin: users.bob});
        rootFVR.getReward({_tokenId: tokenId, _tokens: tokens});
        snapLastCall("RootFeesVotingReward_getReward");
    }
}
