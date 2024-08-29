// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootBribeVotingReward.t.sol";

contract GetRewardIntegrationConcreteTest is RootBribeVotingRewardTest {
    uint256 public tokenId = 1;

    function setUp() public override {
        super.setUp();

        // Notify rewards contracts
        vm.selectFork({forkId: leafId});
        deal(address(token0), address(leafGauge), TOKEN_1 * 2);
        deal(address(token1), address(leafGauge), TOKEN_1 * 2);
        // Using WETH as Bribe token
        deal(address(weth), address(leafGauge), TOKEN_1);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), TOKEN_1);
        token1.approve(address(leafFVR), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token1), TOKEN_1);

        token0.approve(address(leafIVR), TOKEN_1);
        token1.approve(address(leafIVR), TOKEN_1);
        weth.approve(address(leafIVR), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token1), TOKEN_1);
        leafIVR.notifyRewardAmount(address(weth), TOKEN_1);

        // Deposit & Skip to next Epoch to vest rewards
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({_payload: depositPayload});
        leafIVR._deposit({_payload: depositPayload});
        vm.stopPrank();

        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        vm.prank(users.alice);
        mockEscrow.createLock(TOKEN_1, WEEK);
    }

    modifier whenCallerIsNotApprovedOrOwnerOfTokenId() {
        _;
    }

    function test_WhenCallerIsNotVoter() external whenCallerIsNotApprovedOrOwnerOfTokenId {
        // It should revert with NotAuthorized
        address[] memory tokens = new address[](0);
        vm.prank(users.charlie);
        vm.expectRevert(IRootBribeVotingReward.NotAuthorized.selector);
        rootIVR.getReward({_tokenId: tokenId, _tokens: tokens});
    }

    function test_WhenCallerIsVoter() external whenCallerIsNotApprovedOrOwnerOfTokenId {
        // It should encode the owner, token id and token addresses
        // It should forward the message to the corresponding reward contracts on the leaf chain
        // It should claim rewards for owner on the leaf fee + incentive voting contracts
        // It should update lastEarn timestamp for token id on leaf voting reward contracts
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);

        vm.prank(address(mockVoter));
        rootIVR.getReward({_tokenId: tokenId, _tokens: tokens});

        vm.selectFork({forkId: leafId});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({
                _sender: users.alice,
                _reward: tokens[i],
                _amount: tokens[i] != address(weth) ? TOKEN_1 : 0
            });
        }
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(weth), tokenId), block.timestamp);

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1 * 2);
        assertEq(token1.balanceOf(users.alice), TOKEN_1 * 2);
        assertEq(weth.balanceOf(users.alice), TOKEN_1);
    }

    function test_WhenCallerIsApprovedOrOwnerOfTokenId() external {
        // It should encode the owner, token id and token addresses
        // It should forward the message to the corresponding reward contracts on the leaf chain
        // It should claim rewards for owner on the leaf fee + incentive voting contracts
        // It should update lastEarn timestamp for token id on leaf voting reward contracts
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);

        vm.prank(mockEscrow.ownerOf(tokenId));
        rootIVR.getReward({_tokenId: tokenId, _tokens: tokens});

        vm.selectFork({forkId: leafId});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({
                _sender: users.alice,
                _reward: tokens[i],
                _amount: tokens[i] != address(weth) ? TOKEN_1 : 0
            });
        }
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(weth), tokenId), block.timestamp);

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1 * 2);
        assertEq(token1.balanceOf(users.alice), TOKEN_1 * 2);
        assertEq(weth.balanceOf(users.alice), TOKEN_1);
    }
}