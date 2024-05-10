// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract ConverterTest is BaseFixture {
    Pool public pool;
    Converter public feeConverter;
    StakingRewards public stakingRewards;

    function setUp() public virtual override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        stakingRewards = StakingRewards(
            stakingRewardsFactory.createStakingRewards({_pool: address(pool), _rewardToken: address(rewardToken)})
        );
        feeConverter = Converter(stakingRewards.feeConverter());

        skipToNextEpoch(0);

        vm.prank(stakingRewardsFactory.owner());
        stakingRewardsFactory.approveKeeper(users.bob); // approve bob as a keeper

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN_1 * 10_000, USDC_1 * 10_000);

        vm.label(address(pool), "Pool");
        vm.label(address(feeConverter), "Converter");
        vm.label(address(stakingRewards), "Staking Rewards");

        vm.startPrank(users.alice);
    }

    function test_InitialState() public view {
        assertTrue(stakingRewardsFactory.isKeeper(users.bob));
        assertEq(feeConverter.gauge(), address(stakingRewards));
        assertEq(feeConverter.targetToken(), stakingRewards.rewardToken());
        assertEq(address(feeConverter.poolFactory()), address(poolFactory));
        assertEq(address(feeConverter.router()), stakingRewardsFactory.router());
        assertEq(poolFactory.getPool(address(token0), address(token1), true), address(pool));
    }
}
