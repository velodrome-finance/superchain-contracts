// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../BribeVotingReward.t.sol";

contract DepositIntegrationConcreteTest is BribeVotingRewardTest {
    function test_WhenCallerIsNotTheModuleSetOnTheBridge() external {
        // It reverts with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);

        vm.prank(users.charlie);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafIVR._deposit({_payload: payload});
    }

    function test_WhenCallerIsTheModuleSetOnTheBridge() external {
        // It should update the total supply on the leaf incentive voting contract
        // It should update the balance of the token id on the leaf incentive voting contract
        // It should emit a {Deposit} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);

        vm.prank(address(leafMessageModule));
        vm.expectEmit(address(leafIVR));
        emit IReward.Deposit({_sender: address(leafMessageModule), _amount: amount, _tokenId: tokenId});
        leafIVR._deposit({_payload: payload});

        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }
}
