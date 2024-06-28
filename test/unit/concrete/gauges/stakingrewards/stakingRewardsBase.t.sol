// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

contract StakingRewardsBaseTest is BaseFixture {
    Pool public pool;
    StakingRewards public stakingRewards;

    function setUp() public virtual override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        stakingRewards = StakingRewards(stakingRewardsFactory.createStakingRewards({_pool: address(pool)}));

        skipToNextEpoch(0);

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN_1, USDC_1);

        vm.label(address(pool), "Pool");
        vm.label(address(stakingRewards), "Staking Rewards");

        vm.startPrank(users.alice);
    }
}
