// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafGauge.t.sol";

contract NotifyRewardWithoutClaimIntegrationFuzzTest is LeafGaugeTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function testFuzz_WhenTheCallerIsNotTheModule(address _caller) external {
        // It should revert with {NotModule}
        vm.assume(_caller != address(leafMessageModule));

        vm.prank(_caller);
        vm.expectRevert(ILeafGauge.NotModule.selector);
        leafGauge.notifyRewardWithoutClaim({_amount: TOKEN_1 * 1000});
    }

    modifier whenTheCallerIsTheModule() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function testFuzz_WhenTheAmountIsGreaterThanZeroAndSmallerThanTheTimeUntilTheNextTimestamp(uint256 _amount)
        external
        whenTheCallerIsTheModule
    {
        // It should revert with {ZeroRewardRate}
        _amount = bound(_amount, 1, WEEK - 1);
        deal({token: address(leafXVelo), to: address(leafMessageModule), give: _amount});
        leafXVelo.approve({spender: address(leafGauge), value: _amount});

        vm.expectRevert(ILeafGauge.ZeroRewardRate.selector);
        leafGauge.notifyRewardWithoutClaim({_amount: _amount});
    }

    modifier whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish(uint256 _amount)
        external
        whenTheCallerIsTheModule
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should update rewardPerTokenStored
        // It should deposit the amount of reward token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        _amount = bound(_amount, WEEK, MAX_TOKENS);
        deal({token: address(leafXVelo), to: address(leafMessageModule), give: _amount});
        leafXVelo.approve({spender: address(leafGauge), value: _amount});

        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        leafGauge.notifyRewardWithoutClaim({_amount: _amount});

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), _amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(leafStartTime), _amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function testFuzz_WhenTheCurrentTimestampIsLessThanPeriodFinish(
        uint256 _initialAmount,
        uint256 _amount,
        uint256 _timeskip
    )
        external
        whenTheCallerIsTheModule
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should update rewardPerTokenStored
        // It should deposit the amount of reward token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        _timeskip = bound(_timeskip, 1, WEEK - 1);
        _initialAmount = bound(_amount, WEEK, MAX_TOKENS);
        _amount = bound(_amount, WEEK - _timeskip, MAX_TOKENS);

        // inital deposit of partial amount
        deal({token: address(leafXVelo), to: address(leafMessageModule), give: _initialAmount});
        leafXVelo.approve({spender: address(leafGauge), value: _initialAmount});
        leafGauge.notifyRewardWithoutClaim({_amount: _initialAmount});

        skipTime(_timeskip);

        deal({token: address(leafXVelo), to: address(leafMessageModule), give: _amount});
        leafXVelo.approve({spender: address(leafGauge), value: _amount});

        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        leafGauge.notifyRewardWithoutClaim({_amount: _amount});

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount + _initialAmount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = WEEK - _timeskip;
        uint256 rewardRate = ((_initialAmount / WEEK) * timeUntilNext + _amount) / timeUntilNext;
        assertApproxEqAbs(leafGauge.rewardRate(), rewardRate, 1);
        assertApproxEqAbs(leafGauge.rewardRateByEpoch(leafStartTime), rewardRate, 1);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }
}
