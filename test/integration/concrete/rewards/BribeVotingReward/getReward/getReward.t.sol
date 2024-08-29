// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../BribeVotingReward.t.sol";

contract GetRewardIntegrationConcreteTest is BribeVotingRewardTest {
    uint256 public tokenId = 1;

    function setUp() public override {
        super.setUp();

        // Notify Bribe rewards contract
        deal(address(token0), address(this), TOKEN_1);
        deal(address(token1), address(this), TOKEN_1);
        // Using WETH as Bribe token
        deal(address(weth), address(this), TOKEN_1);

        token0.approve(address(leafIVR), TOKEN_1);
        token1.approve(address(leafIVR), TOKEN_1);
        weth.approve(address(leafIVR), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token1), TOKEN_1);
        leafIVR.notifyRewardAmount(address(weth), TOKEN_1);
    }

    function test_WhenCallerIsNotTheModuleSetOnTheBridge() external {
        // It reverts with {NotAuthorized}
        address[] memory tokens = new address[](0);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);

        vm.prank(users.charlie);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafIVR.getReward({_payload: payload});
    }

    modifier whenCallerIsTheModuleSetOnTheBridge() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function test_WhenThereAreNoClaimableRewardsForTokenId() external whenCallerIsTheModuleSetOnTheBridge {
        // It should update lastEarn timestamp for token id on the leaf incentive voting contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: 0});
        }
        leafIVR.getReward({_payload: payload});

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);
        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);
    }

    function test_WhenThereAreClaimableRewardsForTokenId() external whenCallerIsTheModuleSetOnTheBridge {
        // It should update lastEarn timestamp for token id on the leaf incentive voting contract
        // It should transfer token id's rewards to recipient on the leaf incentive voting contract
        // It should emit a {ClaimRewards} event

        // Deposit and Skip to next epoch to vest all rewards
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        leafIVR._deposit({_payload: depositPayload});

        skipToNextEpoch(1);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafIVR.getReward({_payload: payload});

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);
        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
        assertEq(weth.balanceOf(users.alice), TOKEN_1);
    }
}