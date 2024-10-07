// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../BribeVotingReward.t.sol";

contract GetRewardIntegrationFuzzTest is BribeVotingRewardTest {
    uint256 public tokenId = 1;
    uint256 public MAX_TOKENS_NOTIFY = 1e37;

    function setUp() public override {
        super.setUp();

        // Notify Bribe rewards contract
        deal(address(token0), address(this), MAX_TOKENS_NOTIFY);
        deal(address(token1), address(this), MAX_TOKENS_NOTIFY);
        // Using WETH as Bribe token
        deal(address(weth), address(this), MAX_TOKENS_NOTIFY);

        token0.approve(address(leafIVR), MAX_TOKENS_NOTIFY);
        token1.approve(address(leafIVR), MAX_TOKENS_NOTIFY);
        weth.approve(address(leafIVR), MAX_TOKENS_NOTIFY);

        leafIVR.notifyRewardAmount(address(token0), MAX_TOKENS_NOTIFY);
        leafIVR.notifyRewardAmount(address(token1), MAX_TOKENS_NOTIFY);
        leafIVR.notifyRewardAmount(address(weth), MAX_TOKENS_NOTIFY);
    }

    function test_WhenCallerIsNotTheModuleSetOnTheBridge(address _caller) external {
        // It reverts with {NotAuthorized}
        vm.assume(_caller != address(leafMessageModule));
        address[] memory tokens = new address[](0);

        vm.prank(_caller);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafIVR.getReward({_recipient: users.alice, _tokenId: tokenId, _tokens: tokens});
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

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: 0});
        }
        leafIVR.getReward({_recipient: users.alice, _tokenId: tokenId, _tokens: tokens});

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);
        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);
    }

    function test_WhenThereAreClaimableRewardsForTokenId(uint256 _amount)
        external
        whenCallerIsTheModuleSetOnTheBridge
    {
        // It should update lastEarn timestamp for token id on the leaf incentive voting contract
        // It should transfer token id's rewards to recipient on the leaf incentive voting contract
        // It should emit a {ClaimRewards} event

        _amount = bound(_amount, 1, MAX_TOKENS_NOTIFY);
        // Deposit and Skip to next epoch to vest all rewards
        bytes memory depositPayload = abi.encode(_amount, tokenId);
        leafIVR._deposit({_payload: depositPayload});

        skipToNextEpoch(1);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: MAX_TOKENS_NOTIFY});
        }
        leafIVR.getReward({_recipient: users.alice, _tokenId: tokenId, _tokens: tokens});

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);
        assertEq(token0.balanceOf(users.alice), MAX_TOKENS_NOTIFY);
        assertEq(token1.balanceOf(users.alice), MAX_TOKENS_NOTIFY);
        assertEq(weth.balanceOf(users.alice), MAX_TOKENS_NOTIFY);
    }
}
