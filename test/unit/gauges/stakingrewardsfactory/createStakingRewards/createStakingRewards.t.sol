// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../StakingRewardsFactory.t.sol";

contract CreateStakingRewardsTest is StakingRewardsFactoryTest {
    address public pool;

    function setUp() public override {
        super.setUp();

        pool = poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true});
    }

    function test_WhenGaugeExistsForGivenPool() external {
        address stakingRewards =
            stakingRewardsFactory.createStakingRewards({_pool: pool, _rewardToken: address(rewardToken)});
        assertEq(stakingRewardsFactory.gauges(pool), stakingRewards);

        // It should revert with GaugeExists
        vm.expectRevert(IStakingRewardsFactory.GaugeExists.selector);
        stakingRewardsFactory.createStakingRewards({_pool: pool, _rewardToken: address(rewardToken)});
    }

    modifier whenGaugeDoesNotExistForGivenPool() {
        _;
    }

    function test_WhenRewardTokenIsZeroAddress() external whenGaugeDoesNotExistForGivenPool {
        // It should revert with ZeroAddress
        vm.expectRevert(IStakingRewardsFactory.ZeroAddress.selector);
        stakingRewardsFactory.createStakingRewards({_pool: pool, _rewardToken: address(0)});
    }

    modifier whenRewardTokenIsNotZeroAddress() {
        _;
    }

    function test_WhenOneOfTheTokensIsNotWhitelistedInRegistry()
        external
        whenGaugeDoesNotExistForGivenPool
        whenRewardTokenIsNotZeroAddress
    {
        /// @dev Store initial state
        uint256 snapshot = vm.snapshot();

        // Testing with token0 not Whitelisted
        // Remove token0 from whitelist
        vm.prank(tokenRegistry.admin());
        tokenRegistry.whitelistToken({_token: address(token0), _state: false});

        // It should revert with NotWhitelisted
        vm.expectRevert(IStakingRewardsFactory.NotWhitelistedToken.selector);
        stakingRewardsFactory.createStakingRewards({_pool: pool, _rewardToken: address(rewardToken)});

        /// @dev Restore initial state
        vm.revertTo(snapshot);

        // Testing with token1 not Whitelisted
        // Remove token1 from whitelist
        vm.prank(tokenRegistry.admin());
        tokenRegistry.whitelistToken({_token: address(token1), _state: false});

        // It should revert with NotWhitelisted
        vm.expectRevert(IStakingRewardsFactory.NotWhitelistedToken.selector);
        stakingRewardsFactory.createStakingRewards({_pool: pool, _rewardToken: address(rewardToken)});
    }

    function test_WhenBothTokensAreWhitelistedInRegistry()
        external
        whenGaugeDoesNotExistForGivenPool
        whenRewardTokenIsNotZeroAddress
    {
        // It should deploy new StakingRewards contract
        // It should store new staking rewards contract in gauges mapping
        // It should store pool for new staking rewards contract in poolForGauge mapping
        // It should set isAlive to true for new staking rewards contract
        // It should emit a {StakingRewardsCreated} event
        assertEq(stakingRewardsFactory.gauges(pool), address(0));

        vm.expectEmit(true, true, false, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.StakingRewardsCreated({
            pool: pool,
            rewardToken: address(rewardToken),
            stakingRewards: address(0),
            creator: users.alice
        });
        vm.prank(users.alice);
        address stakingRewards =
            stakingRewardsFactory.createStakingRewards({_pool: pool, _rewardToken: address(rewardToken)});

        assertEq(stakingRewardsFactory.gauges(pool), stakingRewards);
        assertEq(stakingRewardsFactory.poolForGauge(stakingRewards), pool);
        assertEq(stakingRewardsFactory.isAlive(stakingRewards), true);
    }
}
