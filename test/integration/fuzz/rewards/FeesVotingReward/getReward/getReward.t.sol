// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../FeesVotingReward.t.sol";

contract GetRewardIntegrationFuzzTest is FeesVotingRewardTest {
    uint256 public tokenId = 1;
    uint256 public MAX_TOKENS_NOTIFY = 1e37;

    function setUp() public override {
        super.setUp();

        // Notify Fee rewards contract
        deal(address(token0), address(leafGauge), MAX_TOKENS_NOTIFY);
        deal(address(token1), address(leafGauge), MAX_TOKENS_NOTIFY);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), MAX_TOKENS_NOTIFY);
        token1.approve(address(leafFVR), MAX_TOKENS_NOTIFY);

        leafFVR.notifyRewardAmount(address(token0), MAX_TOKENS_NOTIFY);
        leafFVR.notifyRewardAmount(address(token1), MAX_TOKENS_NOTIFY);
        vm.stopPrank();
    }

    function test_WhenCallerIsNotTheModuleSetOnTheBridge(address _caller) external {
        // It reverts with {NotAuthorized}
        address[] memory tokens = new address[](0);

        vm.assume(_caller != address(leafMessageModule));

        vm.prank(_caller);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafFVR.getReward({_recipient: users.alice, _tokenId: tokenId, _tokens: tokens});
    }

    modifier whenCallerIsTheModuleSetOnTheBridge() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function test_WhenThereAreNoClaimableRewardsForTokenId() external whenCallerIsTheModuleSetOnTheBridge {
        // It should update lastEarn timestamp for token id on the leaf fee voting contract
        // It should emit a {ClaimRewards} event
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: 0});
        }
        leafFVR.getReward({_recipient: users.alice, _tokenId: tokenId, _tokens: tokens});

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);
    }

    function test_WhenThereAreClaimableRewardsForTokenId(uint256 _amount)
        external
        whenCallerIsTheModuleSetOnTheBridge
    {
        // It should update lastEarn timestamp for token id on the leaf fee voting contract
        // It should transfer token id's rewards to recipient on the leaf fee voting contract
        // It should emit a {ClaimRewards} event

        // Deposit and Skip to next epoch to vest all rewards
        _amount = bound(_amount, 1, MAX_TOKENS_NOTIFY);
        leafFVR._deposit({amount: _amount, tokenId: tokenId, timestamp: block.timestamp});

        skipToNextEpoch(1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: MAX_TOKENS_NOTIFY});
        }
        leafFVR.getReward({_recipient: users.alice, _tokenId: tokenId, _tokens: tokens});

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(token0.balanceOf(users.alice), MAX_TOKENS_NOTIFY);
        assertEq(token1.balanceOf(users.alice), MAX_TOKENS_NOTIFY);
    }
}
