// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../IncentiveVotingReward.t.sol";

contract WithdrawIntegrationFuzzTest is IncentiveVotingRewardTest {
    function test_WhenCallerIsNotTheModuleSetOnTheBridge(address _caller) external {
        // It reverts with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;

        vm.assume(_caller != address(leafMessageModule));

        vm.prank(_caller);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafIVR._withdraw({amount: amount, tokenId: tokenId});
    }

    function test_WhenCallerIsTheModuleSetOnTheBridge(uint256 _amount) external {
        // It should update the total supply on the leaf voting contract
        // It should update the balance of the token id on the leaf voting contract
        // It should emit a {Withdraw} event
        _amount = bound(_amount, 1, type(uint256).max);
        uint256 tokenId = 1;

        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({amount: _amount, tokenId: tokenId});

        assertEq(leafIVR.totalSupply(), _amount);
        assertEq(leafIVR.balanceOf(tokenId), _amount);

        vm.expectEmit(address(leafIVR));
        emit IReward.Withdraw({_amount: _amount, _tokenId: tokenId});
        leafIVR._withdraw({amount: _amount, tokenId: tokenId});

        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
    }
}
