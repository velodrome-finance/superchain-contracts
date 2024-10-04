// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is RootGaugeFactoryTest {
    function setUp() public override {
        super.setUp();

        // we use stable = true to avoid collision with existing pool
        rootPool = RootPool(
            rootPoolFactory.createPool({chainid: leaf, tokenA: address(token0), tokenB: address(token1), stable: true})
        );

        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});
    }

    function test_WhenTheCallerIsNotVoter() external {
        // It reverts with NotVoter
        vm.prank(users.charlie);
        vm.expectRevert(IRootGaugeFactory.NotVoter.selector);
        rootGaugeFactory.createGauge(address(0), address(rootPool), address(0), address(rootRewardToken), true);
    }

    function test_WhenTheCallerIsVoter() external {
        // It creates a new gauge on root chain
        // It should encode the root pool configuration
        // It should create new pool on leaf chain with same config
        // It should emit a {PoolCreated} event
        // It should call createGauge with leaf pool and factory on corresponding leaf voter
        // It should create a new gauge on leaf chain with same address as root gauge
        // It should emit a {GaugeCreated} event
        vm.prank(address(mockVoter));
        (address rootFVR,) = rootVotingRewardsFactory.createRewards(address(0), new address[](0));
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        RootGauge rootGauge = RootGauge(
            rootGaugeFactory.createGauge(
                address(0), address(rootPool), address(rootFVR), address(rootRewardToken), true
            )
        );

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));
        assertEq(rootGauge.xerc20(), address(rootXVelo));
        assertEq(rootGauge.lockbox(), address(rootLockbox));
        assertEq(rootGauge.bridge(), address(rootMessageBridge));
        assertEq(rootGauge.chainid(), leaf);

        vm.selectFork({forkId: leafId});

        address pool = Clones.predictDeterministicAddress({
            deployer: address(leafPoolFactory),
            implementation: leafPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        });
        assertFalse(leafPoolFactory.isPool(pool));

        vm.expectEmit(address(leafPoolFactory));
        emit IPoolFactory.PoolCreated(
            address(token0), address(token1), true, pool, leafPoolFactory.allPoolsLength() + 1
        );
        vm.expectEmit(true, true, true, false, address(leafVoter));
        emit ILeafVoter.GaugeCreated({
            poolFactory: address(leafPoolFactory),
            votingRewardsFactory: address(leafVotingRewardsFactory),
            gaugeFactory: address(leafGaugeFactory),
            pool: pool,
            bribeVotingReward: address(13),
            feeVotingReward: address(12),
            gauge: address(11)
        });
        leafMailbox.processNextInboundMessage();

        assertTrue(leafPoolFactory.isPool(pool));

        leafPool = Pool(pool);
        assertEq(leafPool.token0(), address(token0));
        assertEq(leafPool.token1(), address(token1));
        assertTrue(leafPool.stable());

        leafGauge = LeafGauge(leafVoter.gauges(pool));
        assertEq(leafGauge.stakingToken(), pool);
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));

        assertEq(address(leafGauge), address(rootGauge));
    }
}
