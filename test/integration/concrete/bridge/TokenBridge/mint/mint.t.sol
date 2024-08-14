// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract MintIntegrationConcreteTest is TokenBridgeTest {
    function test_WhenTheCallerIsNotTheModule() external {
        // It reverts with NotModule
        vm.prank(users.charlie);
        vm.expectRevert(IBridge.NotModule.selector);
        rootTokenBridge.mint({_user: users.charlie, _amount: 0});
    }

    modifier whenTheCallerIsTheModule() {
        vm.startPrank(address(rootTokenModule));
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit() external whenTheCallerIsTheModule {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = 1;

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootTokenBridge.mint({_user: address(rootTokenBridge), _amount: amount});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() external whenTheCallerIsTheModule {
        // It should mint tokens to the user
        uint256 amount = TOKEN_1 * 1000;
        setLimits({_rootMintingLimit: amount, _leafMintingLimit: 0});

        vm.prank(address(rootTokenModule));
        rootTokenBridge.mint({_user: users.alice, _amount: amount});

        assertEq(rootXVelo.balanceOf(users.alice), amount);
    }
}
