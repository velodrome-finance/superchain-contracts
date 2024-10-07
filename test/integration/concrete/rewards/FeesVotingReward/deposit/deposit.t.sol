// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../FeesVotingReward.t.sol";

contract DepositIntegrationConcreteTest is FeesVotingRewardTest {
    function test_WhenCallerIsNotTheModuleSetOnTheBridge() external {
        // It reverts with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        vm.prank(users.charlie);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafFVR._deposit({amount: amount, tokenId: tokenId});
    }

    function test_WhenCallerIsTheModuleSetOnTheBridge() external {
        // It should update the total supply on the leaf fee voting contract
        // It should update the balance of the token id on the leaf fee voting contract
        // It should emit a {Deposit} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;

        vm.prank(address(leafMessageModule));
        vm.expectEmit(address(leafFVR));
        emit IReward.Deposit({_amount: amount, _tokenId: tokenId});
        leafFVR._deposit({amount: amount, tokenId: tokenId});

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
    }
}
