// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract MintIntegrationConcreteTest is BridgeTest {
    function test_WhenTheCallerIsNotTheModule() external {
        // It reverts with NotModule
        vm.prank(users.charlie);
        vm.expectRevert(IBridge.NotModule.selector);
        rootBridge.mint({_user: users.charlie, _amount: 1});
    }

    modifier whenTheCallerIsTheModule() {
        vm.startPrank(address(rootModule));
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit() external whenTheCallerIsTheModule {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = 1;

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootBridge.mint({_user: address(rootBridge), _amount: amount});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() external whenTheCallerIsTheModule {
        // It should mint tokens to the user
        uint256 amount = TOKEN_1 * 1000;
        setLimits({_rootMintingLimit: amount, _leafMintingLimit: 0});

        vm.prank(address(rootModule));
        rootBridge.mint({_user: users.alice, _amount: amount});

        assertEq(rootXVelo.balanceOf(users.alice), amount);
    }
}
