// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../IncentiveVotingReward.t.sol";

contract WithdrawIntegrationFuzzTest is IncentiveVotingRewardTest {
    function testFuzz_WhenCallerIsNotTheModuleSetOnTheBridge(address _caller) external {
        // It reverts with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;

        vm.assume(_caller != address(leafMessageModule));

        vm.prank(_caller);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafIVR._withdraw({amount: amount, tokenId: tokenId, timestamp: block.timestamp});
    }

    function testFuzz_WhenCallerIsTheModuleSetOnTheBridge(uint256 _amount, uint40 _timestamp) external {
        // It should update the total supply on the leaf voting contract
        // It should update the balance of the token id on the leaf voting contract
        // It should emit a {Withdraw} event
        _amount = bound(_amount, 1, type(uint256).max);
        uint256 tokenId = 1;

        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({amount: _amount, tokenId: tokenId, timestamp: _timestamp});

        assertEq(leafIVR.totalSupply(), _amount);
        assertEq(leafIVR.balanceOf(tokenId), _amount);

        vm.expectEmit(address(leafIVR));
        emit IReward.Withdraw({_amount: _amount, _tokenId: tokenId});
        leafIVR._withdraw({amount: _amount, tokenId: tokenId, timestamp: _timestamp});

        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
        (uint256 checkpointTs, uint256 checkpointAmount) =
            leafIVR.checkpoints(tokenId, leafIVR.numCheckpoints(tokenId) - 1);
        assertEq(checkpointTs, _timestamp);
        assertEq(checkpointAmount, 0);
    }
}
