// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract NotifyIntegrationConcreteTest is BridgeTest {
    function setUp() public override {
        super.setUp();

        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotTheModule() external {
        // It reverts with NotModule
        vm.prank(users.charlie);
        vm.expectRevert(IBridge.NotModule.selector);
        leafBridge.notify({_recipient: users.charlie, _amount: 1});
    }

    function test_WhenTheCallerIsTheModule() external {
        // It calls notify reward amount on the recipient
        uint256 amount = TOKEN_1 * 1000;
        setLimits({_rootMintingLimit: 0, _leafMintingLimit: amount});

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
