// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootFeesVotingReward.t.sol";

contract WithdrawIntegrationConcreteTest is RootFeesVotingRewardTest {
    function test_WhenCallerIsNotVoter() external {
        // It should revert with NotAuthorized
        vm.prank(users.charlie);
        vm.expectRevert(IRootFeesVotingReward.NotAuthorized.selector);
        rootFVR._withdraw({_amount: 1, _tokenId: 1});
    }

    function test_WhenCallerIsVoter() external {
        // It should encode the deposit amount and token id
        // It should forward the message to the corresponding rewards contract on the leaf chain
        // It should update the total supply on the leaf fee + voting contracts
        // It should update the balance of the token id on the leaf + fee voting contracts
        // It should emit a {Deposit} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;

        vm.startPrank(address(mockVoter));
        rootFVR._deposit({_amount: amount, _tokenId: tokenId});

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);

        vm.selectFork({forkId: rootId});
        rootFVR._withdraw({_amount: amount, _tokenId: tokenId});

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafFVR));
        emit IReward.Withdraw({_sender: address(leafMessageModule), _amount: amount, _tokenId: tokenId});
        vm.expectEmit(address(leafIVR));
        emit IReward.Withdraw({_sender: address(leafMessageModule), _amount: amount, _tokenId: tokenId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), 0);
        assertEq(leafFVR.balanceOf(tokenId), 0);
        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
    }
}
