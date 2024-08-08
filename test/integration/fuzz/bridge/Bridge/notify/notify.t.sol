// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract NotifyIntegrationFuzzTest is BridgeTest {
    function setUp() public override {
        super.setUp();

        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotTheModule(address _caller) external {
        // It reverts with NotModule
        vm.assume(_caller != address(leafModule));

        vm.prank(_caller);
        vm.expectRevert(IBridge.NotModule.selector);
        leafBridge.notify({_recipient: _caller, _amount: 1});
    }

    function test_WhenTheCallerIsTheModule(uint256 _mintingLimit, uint256 _amount) external {
        // It calls notify reward amount on the recipient
        // minimum limit is 1 week as notify needs to be at least WEEK
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        uint256 amount = bound(_amount, WEEK, _mintingLimit);

        vm.prank(users.owner);
        leafXVelo.setLimits({_bridge: address(leafBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.startPrank(address(leafModule));
        leafBridge.mint({_user: address(leafBridge), _amount: amount});

        assertEq(leafXVelo.balanceOf(address(leafBridge)), amount);

        leafBridge.notify({_recipient: address(leafGauge), _amount: amount});

        assertEq(leafXVelo.balanceOf(address(leafBridge)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(rootStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }
}
