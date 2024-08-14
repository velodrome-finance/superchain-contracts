// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract MintIntegrationFuzzTest is TokenBridgeTest {
    function testFuzz_WhenTheCallerIsNotTheModule(address _caller) external {
        // It reverts with NotModule
        vm.assume(_caller != address(rootTokenModule));
        vm.prank(_caller);
        vm.expectRevert(IBridge.NotModule.selector);
        rootTokenBridge.mint({_user: _caller, _amount: 0});
    }

    modifier whenTheCallerIsTheModule() {
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit(uint256 _mintingLimit, uint256 _amount)
        external
        whenTheCallerIsTheModule
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2 - 1);
        _amount = bound(_amount, _mintingLimit + 1, type(uint256).max / 2);

        vm.prank(users.owner);
        rootXVelo.setLimits({_bridge: address(rootTokenBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.prank(address(rootTokenModule));
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootTokenBridge.mint({_user: address(rootTokenBridge), _amount: _amount});
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(
        uint256 _mintingLimit,
        uint256 _amount
    ) external whenTheCallerIsTheModule {
        // It should mint tokens to the user
        // It should deposit the tokens into the gauge
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        _amount = bound(_amount, WEEK, _mintingLimit);

        vm.prank(users.owner);
        rootXVelo.setLimits({_bridge: address(rootTokenBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.prank(address(rootTokenModule));
        rootTokenBridge.mint({_user: users.alice, _amount: _amount});

        assertEq(rootXVelo.balanceOf(users.alice), _amount);
    }
}
