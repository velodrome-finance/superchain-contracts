// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract MintIntegrationFuzzTest is BridgeTest {
    function test_WhenTheCallerIsNotTheModule(address _caller) external {
        // It reverts with NotModule
        vm.assume(_caller != address(rootModule));
        vm.prank(_caller);
        vm.expectRevert(IBridge.NotModule.selector);
        rootBridge.mint({_user: _caller, _amount: 1});
    }

    modifier whenTheCallerIsTheModule() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit(uint256 _mintingLimit, uint256 _amount)
        external
        whenTheCallerIsTheModule
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2 - 1);
        _amount = bound(_amount, _mintingLimit + 1, type(uint256).max / 2);

        vm.prank(users.owner);
        rootXVelo.setLimits({_bridge: address(rootBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.prank(address(rootModule));
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootBridge.mint({_user: address(rootBridge), _amount: _amount});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(
        uint256 _mintingLimit,
        uint256 _amount
    ) external whenTheCallerIsTheModule {
        // It should mint tokens to the user
        // It should deposit the tokens into the gauge
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        _amount = bound(_amount, WEEK, _mintingLimit);

        vm.prank(users.owner);
        rootXVelo.setLimits({_bridge: address(rootBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.prank(address(rootModule));
        rootBridge.mint({_user: users.alice, _amount: _amount});

        assertEq(rootXVelo.balanceOf(users.alice), _amount);
    }
}
