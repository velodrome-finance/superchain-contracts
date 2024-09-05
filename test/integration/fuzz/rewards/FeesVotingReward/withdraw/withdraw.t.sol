// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../FeesVotingReward.t.sol";

contract WithdrawIntegrationFuzzTest is FeesVotingRewardTest {
    function test_WhenCallerIsNotTheModuleSetOnTheBridge(address _caller) external {
        // It reverts with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);

        vm.assume(_caller != address(leafMessageModule));
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafFVR._withdraw({_payload: payload});
    }

    function test_WhenCallerIsTheModuleSetOnTheBridge(uint256 _amount) external {
        // It should update the total supply on the leaf fee voting contract
        // It should update the balance of the token id on the leaf fee voting contract
        // It should emit a {Withdraw} event
        _amount = bound(_amount, 1, type(uint256).max);
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(_amount, tokenId);

        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({_payload: payload});

        assertEq(leafFVR.totalSupply(), _amount);
        assertEq(leafFVR.balanceOf(tokenId), _amount);

        vm.expectEmit(address(leafFVR));
        emit IReward.Withdraw({_sender: address(leafMessageModule), _amount: _amount, _tokenId: tokenId});
        leafFVR._withdraw({_payload: payload});

        assertEq(leafFVR.totalSupply(), 0);
        assertEq(leafFVR.balanceOf(tokenId), 0);
    }
}
