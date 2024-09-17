// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseE2EForkFixture.sol";

contract GaugeFlowE2EFuzzTest is BaseE2EForkFixture {
    uint256 constant MAX_TIME = 4 * 365 * 86400;
    uint256 constant PRECISION = 10 ** 18;

    uint256 public aliceLock;
    uint256 public bobLock;
    Pool public v2Pool;
    ILeafGauge public v2Gauge;
    IERC20 public v2Token0;
    IERC20 public v2Token1;
    address public v2IVR;
    address public v2FVR;

    function setUp() public virtual override {
        super.setUp();

        // setup test contracts from mainnet deployment
        v2Token0 = rootRewardToken;
        v2Token1 = IERC20(address(weth));
        v2Pool = Pool(v2Factory.getPool(address(v2Token0), address(v2Token1), false));
        v2Gauge = ILeafGauge(mockVoter.gauges(address(v2Pool)));
        v2IVR = mockVoter.gaugeToBribe(address(v2Gauge));
        v2FVR = mockVoter.gaugeToFees(address(v2Gauge));

        skipToNextEpoch(0); // warp to start of next epoch

        // Create Lock for Alice & Bob
        vm.stopPrank();
        vm.startPrank(users.alice);
        uint256 amount = TOKEN_1 * 100;
        deal(address(rootRewardToken), users.alice, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        aliceLock = mockEscrow.createLock(amount, MAX_TIME);

        vm.startPrank(users.bob);
        amount = TOKEN_1 * 50;
        deal(address(rootRewardToken), users.bob, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        bobLock = mockEscrow.createLock(amount, MAX_TIME);
        vm.stopPrank();

        setLimits({_rootMintingLimit: TOKEN_1 * 1_000_000, _leafMintingLimit: TOKEN_1 * 1_000_000});

        vm.selectFork({forkId: leafId});
        leafStartTime = block.timestamp;
        vm.selectFork({forkId: rootId});
        rootStartTime = block.timestamp;
    }

    function testFuzz_GaugeFlow(uint256 timeskip1, uint256 timeskip2, uint256 timeskip3, uint256 timeskip4)
        public
        syncForkTimestamps
    {
        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                         EPOCH X                            */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        // In this Epoch:
        // Pool and Gauge are created on Leaf Chain
        // Alice deposits Liquidity into Pools, Stakes into Gauges and Votes
        // No emissions are claimable after deposit

        // Create Root Pool & Gauge
        // using stable = true to avoid collision with existing pool
        rootPool =
            RootPool(rootPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        _depositGas({_user: users.alice, _amount: MESSAGE_FEE});
        vm.prank({msgSender: mockVoter.governor(), txOrigin: users.alice});
        rootGauge = RootGauge(mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(rootPool)}));
        rootFVR = RootFeesVotingReward(mockVoter.gaugeToFees(address(rootGauge)));
        rootIVR = RootBribeVotingReward(mockVoter.gaugeToBribe(address(rootGauge)));

        // set up leaf pool & gauge by processing pending `createGauge` message in mailbox
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        leafPool = Pool(leafPoolFactory.getPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        leafGauge = LeafGauge(leafVoter.gauges(address(leafPool)));
        leafFVR = FeesVotingReward(leafVoter.gaugeToFees(address(leafGauge)));
        leafIVR = BribeVotingReward(leafVoter.gaugeToBribe(address(leafGauge)));

        // Alice Provides Liquidity and Stakes into Leaf Gauge
        _addLiquidityToPool(
            users.alice,
            address(leafRouter),
            address(token0),
            address(token1),
            true,
            TOKEN_1 * 1_000_000,
            USDC_1 * 1_000_000
        );
        _stakeLiquidity({_owner: users.alice, _pool: address(leafPool), _gauge: address(leafGauge)});
        checkEmissions(users.alice, address(leafGauge), 0); // No emissions on deposit

        // Alice Provides Liquidity and Stakes into Mainnet Gauge
        vm.selectFork({forkId: rootId});
        _addLiquidityToPool(
            users.alice,
            address(v2Router),
            address(v2Token0),
            address(v2Token1),
            false,
            TOKEN_1 * 10_000_000,
            TOKEN_1 * 1_000
        );
        _stakeLiquidity({_owner: users.alice, _pool: address(v2Pool), _gauge: address(v2Gauge)});
        checkEmissions(users.alice, address(v2Gauge), 0); // No emissions on deposit

        // Skip Distribute Window
        skipTime(1 hours + 1);

        // Alice Votes in Pools
        vm.selectFork({forkId: rootId});
        address[] memory pools = new address[](2);
        pools[0] = address(rootPool);
        pools[1] = address(v2Pool);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 7500;
        weights[1] = 2500;

        _depositGas({_user: users.alice, _amount: MESSAGE_FEE});
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        mockVoter.vote(aliceLock, pools, weights);
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage(); // Process Vote on Leaf Chain

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                       EPOCH X + 1                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        // In this Epoch:
        // First Gauge Notification
        // First Incentive Deposit and Swap Simulations;
        // Alice has no tokens claimable because Rewards are lagged by 1 week

        // Skip to next Epoch & Distribute to both Gauges
        skipToNextEpoch(0);

        assertEq(leafGauge.earned(users.alice), 0);
        vm.selectFork({forkId: rootId});
        assertEq(v2Gauge.earned(users.alice), 0);

        address[] memory gauges = new address[](2);
        gauges[0] = address(rootGauge);
        gauges[1] = address(v2Gauge);
        _depositGas({_user: users.alice, _amount: MESSAGE_FEE});
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        mockVoter.distribute(gauges);

        // No accrued Emissions as these are lagged by 1 week
        checkEmissions(users.alice, address(v2Gauge), 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage(); // Process pending Distribute on Leaf Chain
        checkEmissions(users.alice, address(leafGauge), 0);

        // Accrue Incentives & Fees in Reward Contracts on Leaf & Mainnet
        vm.selectFork({forkId: leafId});
        _depositIncentivesAndSimulateSwaps({
            _ivr: address(leafIVR),
            _tokenA: address(token0),
            _tokenB: address(token1),
            _stable: true,
            _amountA: TOKEN_1 * 50,
            _amountB: USDC_1 * 50
        });
        vm.selectFork({forkId: rootId});
        _depositIncentivesAndSimulateSwaps({
            _ivr: address(v2IVR),
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _stable: false,
            _amountA: TOKEN_1 * 1000,
            _amountB: TOKEN_1
        });

        // Check claimable Voter Rewards on Leaf & Mainnet Pool
        checkVotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: 0,
            _expectedBalanceB: 0
        });
        checkV2VotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: 0,
            _expectedBalanceB: 0
        });

        // Timeskip and check accrued Rewards
        timeskip1 = bound(timeskip1, 0, WEEK - 1);
        skipTime(timeskip1);

        // Check Emissions accrued after timeskip
        uint256 ratePerToken = (v2Gauge.rewardRate() * timeskip1 * PRECISION) / v2Gauge.totalSupply();
        uint256 expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(v2Gauge), expectedEmissions);

        vm.selectFork({forkId: leafId});
        ratePerToken = (leafGauge.rewardRate() * timeskip1 * PRECISION) / leafGauge.totalSupply();
        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(leafGauge), expectedEmissions);

        // No Voter Rewards accrued after Timeskip
        checkVotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: 0,
            _expectedBalanceB: 0
        });
        vm.selectFork({forkId: rootId});
        checkV2VotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: rootRewardToken.balanceOf(users.alice), // reward token balance remains the same
            _expectedBalanceB: 0
        });

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                       EPOCH X + 2                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        // In this Epoch:
        // Second Gauge Notification
        // Second Incentive Deposit and Swap Simulations;
        // Alice has claimable Emissions and Incentives from Epoch X + 1
        // Fees only claimable next epoch, as they are only deposited during Notify in this Epoch
        // Bob LPs, Stakes and Votes on same Gauges and Pools

        // Skip to next Epoch
        skipToNextEpoch(0);

        // Check Alice's emissions on Leaf & Mainnet
        vm.selectFork({forkId: leafId});
        ratePerToken = (leafGauge.rewardRate() * WEEK * PRECISION) / leafGauge.totalSupply();
        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(leafGauge), expectedEmissions);

        vm.selectFork({forkId: rootId});
        ratePerToken = (v2Gauge.rewardRate() * WEEK * PRECISION) / v2Gauge.totalSupply();
        expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(v2Gauge), expectedEmissions);

        // Distribute to Gauges
        _depositGas({_user: users.alice, _amount: MESSAGE_FEE});
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        mockVoter.distribute(gauges);
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage(); // Process pending Distribute on Leaf Chain

        // No earned after distribute
        assertEq(leafGauge.earned(users.alice), 0);
        vm.selectFork({forkId: rootId});
        assertEq(v2Gauge.earned(users.alice), 0);

        // Check claimable Voter Rewards on Leaf & Mainnet Pool
        checkVotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: TOKEN_1 * 50,
            _expectedBalanceB: USDC_1 * 50
        });

        vm.selectFork({forkId: rootId});
        (uint256 expectedBalanceA, uint256 expectedBalanceB) = _calculateVotingRewards({
            _tokenId: aliceLock,
            _ivr: v2IVR,
            _fvr: v2FVR,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1)
        });
        checkV2VotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: rootRewardToken.balanceOf(users.alice) + expectedBalanceA,
            _expectedBalanceB: expectedBalanceB
        });

        // Accrue Incentives & Fees in Reward Contracts on Leaf & Mainnet
        vm.selectFork({forkId: leafId});
        _depositIncentivesAndSimulateSwaps({
            _ivr: address(leafIVR),
            _tokenA: address(token0),
            _tokenB: address(token1),
            _stable: true,
            _amountA: TOKEN_1 * 100,
            _amountB: USDC_1 * 100
        });
        vm.selectFork({forkId: rootId});
        _depositIncentivesAndSimulateSwaps({
            _ivr: address(v2IVR),
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _stable: false,
            _amountA: TOKEN_1 * 1000,
            _amountB: TOKEN_1
        });

        // Bob Provides Liquidity and Stakes into Leaf Gauge
        vm.selectFork({forkId: leafId});
        _addLiquidityToPool(
            users.bob, address(leafRouter), address(token0), address(token1), true, TOKEN_1 * 500_000, USDC_1 * 500_000
        );
        _stakeLiquidity({_owner: users.bob, _pool: address(leafPool), _gauge: address(leafGauge)});
        checkEmissions(users.bob, address(leafGauge), 0); // No emissions on deposit

        // Bob Provides Liquidity and Stakes into Mainnet Gauge
        vm.selectFork({forkId: rootId});
        _addLiquidityToPool(
            users.bob, address(v2Router), address(v2Token0), address(v2Token1), false, TOKEN_1 * 500_000, TOKEN_1 * 500
        );
        _stakeLiquidity({_owner: users.bob, _pool: address(v2Pool), _gauge: address(v2Gauge)});
        checkEmissions(users.bob, address(v2Gauge), 0); // No emissions on deposit

        // Skip Distribute Window
        skipTime(1 hours + 1);

        // Bob Votes in same Pools
        vm.selectFork({forkId: rootId});
        _depositGas({_user: users.bob, _amount: MESSAGE_FEE});
        vm.prank({msgSender: users.bob, txOrigin: users.bob});
        mockVoter.vote(bobLock, pools, weights);
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage(); // Process Vote on Leaf Chain

        // Timeskip and check accrued Rewards
        timeskip2 = bound(timeskip2, 0, WEEK - (1 hours + 2));
        skipTime(timeskip2);

        // Check Alice & Bob emissions on Leaf
        timeskip2 = timeskip2 + 1 hours + 1; // account for Distribute Window
        ratePerToken = (leafGauge.rewardRate() * timeskip2 * PRECISION) / leafGauge.totalSupply();

        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(leafGauge), leafXVelo.balanceOf(users.alice) + expectedEmissions);
        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.bob)) / PRECISION;
        checkEmissions(users.bob, address(leafGauge), leafXVelo.balanceOf(users.bob) + expectedEmissions);

        // No additional Voter Rewards after timeskip
        checkVotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: token0.balanceOf(users.alice),
            _expectedBalanceB: token1.balanceOf(users.alice)
        });
        checkVotingRewards({
            _tokenId: bobLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: token0.balanceOf(users.bob),
            _expectedBalanceB: token1.balanceOf(users.bob)
        });
        vm.selectFork({forkId: rootId});
        checkV2VotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: v2Token0.balanceOf(users.alice),
            _expectedBalanceB: v2Token1.balanceOf(users.alice)
        });
        vm.selectFork({forkId: rootId});
        checkV2VotingRewards({
            _tokenId: bobLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: v2Token0.balanceOf(users.bob),
            _expectedBalanceB: v2Token1.balanceOf(users.bob)
        });

        // Check Alice & Bob emissions on Root
        vm.selectFork({forkId: rootId});
        ratePerToken = (v2Gauge.rewardRate() * timeskip2 * PRECISION) / v2Gauge.totalSupply();

        expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(v2Gauge), rootRewardToken.balanceOf(users.alice) + expectedEmissions);
        expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.bob)) / PRECISION;
        checkEmissions(users.bob, address(v2Gauge), rootRewardToken.balanceOf(users.bob) + expectedEmissions);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                       EPOCH X + 3                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        // In this Epoch:
        // Third Gauge Notification
        // Alice & Bob can claim outstanding Emissions, Incentives and Fees

        // Skip to next Epoch & Distribute
        skipToNextEpoch(0);

        // Check Alice & Bob emissions on Root
        ratePerToken = (v2Gauge.rewardRate() * (WEEK - timeskip2) * PRECISION) / v2Gauge.totalSupply();

        expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(v2Gauge), rootRewardToken.balanceOf(users.alice) + expectedEmissions);
        expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.bob)) / PRECISION;
        checkEmissions(users.bob, address(v2Gauge), rootRewardToken.balanceOf(users.bob) + expectedEmissions);

        // Check Alice & Bob emissions on Leaf
        vm.selectFork({forkId: leafId});
        ratePerToken = (leafGauge.rewardRate() * (WEEK - timeskip2) * PRECISION) / leafGauge.totalSupply();

        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(leafGauge), leafXVelo.balanceOf(users.alice) + expectedEmissions);
        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.bob)) / PRECISION;
        checkEmissions(users.bob, address(leafGauge), leafXVelo.balanceOf(users.bob) + expectedEmissions);

        // Skip in time for Delayed Distribute
        timeskip3 = bound(timeskip3, 0, 1 hours);
        skipTime(timeskip3);

        // Distribute to Gauges
        vm.selectFork({forkId: rootId});
        _depositGas({_user: users.alice, _amount: MESSAGE_FEE});
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        mockVoter.distribute(gauges);
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage(); // Process pending Distribute on Leaf Chain

        // No earned after distribute
        assertEq(leafGauge.earned(users.alice), 0);
        vm.selectFork({forkId: rootId});
        assertEq(v2Gauge.earned(users.alice), 0);

        // Check claimable Voter Rewards for Alice on Leaf
        vm.selectFork({forkId: leafId});
        (expectedBalanceA, expectedBalanceB) = _calculateVotingRewards({
            _tokenId: aliceLock,
            _ivr: address(leafIVR),
            _fvr: address(leafFVR),
            _tokenA: address(token0),
            _tokenB: address(token1)
        });
        checkVotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: token0.balanceOf(users.alice) + expectedBalanceA,
            _expectedBalanceB: token1.balanceOf(users.alice) + expectedBalanceB
        });

        // Check claimable Voter Rewards for Bob on Leaf
        (expectedBalanceA, expectedBalanceB) = _calculateVotingRewards({
            _tokenId: bobLock,
            _ivr: address(leafIVR),
            _fvr: address(leafFVR),
            _tokenA: address(token0),
            _tokenB: address(token1)
        });
        checkVotingRewards({
            _tokenId: bobLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: token0.balanceOf(users.bob) + expectedBalanceA,
            _expectedBalanceB: token1.balanceOf(users.bob) + expectedBalanceB
        });

        // Check claimable Voter Rewards for Alice on Root
        vm.selectFork({forkId: rootId});
        (expectedBalanceA, expectedBalanceB) = _calculateVotingRewards({
            _tokenId: aliceLock,
            _ivr: v2IVR,
            _fvr: v2FVR,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1)
        });
        checkV2VotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: v2Token0.balanceOf(users.alice) + expectedBalanceA,
            _expectedBalanceB: v2Token1.balanceOf(users.alice) + expectedBalanceB
        });

        // Check claimable Voter Rewards for Bob on Root
        vm.selectFork({forkId: rootId});
        (expectedBalanceA, expectedBalanceB) = _calculateVotingRewards({
            _tokenId: bobLock,
            _ivr: v2IVR,
            _fvr: v2FVR,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1)
        });
        checkV2VotingRewards({
            _tokenId: bobLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: v2Token0.balanceOf(users.bob) + expectedBalanceA,
            _expectedBalanceB: v2Token1.balanceOf(users.bob) + expectedBalanceB
        });

        // Timeskip and check accrued Rewards
        timeskip4 = bound(timeskip4, 0, WEEK - timeskip3);
        skipTime(timeskip4);

        // Check Alice & Bob emissions on Root
        ratePerToken = (v2Gauge.rewardRate() * timeskip4 * PRECISION) / v2Gauge.totalSupply();

        expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(v2Gauge), rootRewardToken.balanceOf(users.alice) + expectedEmissions);
        expectedEmissions = (ratePerToken * v2Gauge.balanceOf(users.bob)) / PRECISION;
        checkEmissions(users.bob, address(v2Gauge), rootRewardToken.balanceOf(users.bob) + expectedEmissions);

        // Check Alice & Bob emissions on Leaf
        vm.selectFork({forkId: leafId});
        ratePerToken = (leafGauge.rewardRate() * timeskip4 * PRECISION) / leafGauge.totalSupply();

        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.alice)) / PRECISION;
        checkEmissions(users.alice, address(leafGauge), leafXVelo.balanceOf(users.alice) + expectedEmissions);
        expectedEmissions = (ratePerToken * leafGauge.balanceOf(users.bob)) / PRECISION;
        checkEmissions(users.bob, address(leafGauge), leafXVelo.balanceOf(users.bob) + expectedEmissions);

        // Check claimable Voter Rewards for Bob on Leaf
        uint256 timeElapsed = timeskip3 + timeskip4;
        (expectedBalanceA, expectedBalanceB) = timeElapsed < WEEK
            ? (0, 0) // No additional rewards within the same epoch
            : _calculateVotingRewards({
                _tokenId: aliceLock,
                _ivr: address(leafIVR),
                _fvr: address(leafFVR),
                _tokenA: address(token0),
                _tokenB: address(token1)
            });
        checkVotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: token0.balanceOf(users.alice) + expectedBalanceA,
            _expectedBalanceB: token1.balanceOf(users.alice) + expectedBalanceB
        });

        // Check claimable Voter Rewards for Bob on Leaf
        (expectedBalanceA, expectedBalanceB) = timeElapsed < WEEK
            ? (0, 0) // No additional rewards within the same epoch
            : _calculateVotingRewards({
                _tokenId: bobLock,
                _ivr: address(leafIVR),
                _fvr: address(leafFVR),
                _tokenA: address(token0),
                _tokenB: address(token1)
            });
        checkVotingRewards({
            _tokenId: bobLock,
            _tokenA: address(token0),
            _tokenB: address(token1),
            _expectedBalanceA: token0.balanceOf(users.bob) + expectedBalanceA,
            _expectedBalanceB: token1.balanceOf(users.bob) + expectedBalanceB
        });

        // Check claimable Voter Rewards for Alice on Root
        vm.selectFork({forkId: rootId});
        (expectedBalanceA, expectedBalanceB) = timeElapsed < WEEK
            ? (0, 0) // No additional rewards within the same epoch
            : _calculateVotingRewards({
                _tokenId: aliceLock,
                _ivr: v2IVR,
                _fvr: v2FVR,
                _tokenA: address(v2Token0),
                _tokenB: address(v2Token1)
            });
        checkV2VotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: v2Token0.balanceOf(users.alice) + expectedBalanceA,
            _expectedBalanceB: v2Token1.balanceOf(users.alice) + expectedBalanceB
        });

        // Check claimable Voter Rewards for Bob on Root
        vm.selectFork({forkId: rootId});
        (expectedBalanceA, expectedBalanceB) = timeElapsed < WEEK
            ? (0, 0) // No additional rewards within the same epoch
            : _calculateVotingRewards({
                _tokenId: bobLock,
                _ivr: v2IVR,
                _fvr: v2FVR,
                _tokenA: address(v2Token0),
                _tokenB: address(v2Token1)
            });
        checkV2VotingRewards({
            _tokenId: bobLock,
            _tokenA: address(v2Token0),
            _tokenB: address(v2Token1),
            _expectedBalanceA: v2Token0.balanceOf(users.bob) + expectedBalanceA,
            _expectedBalanceB: v2Token1.balanceOf(users.bob) + expectedBalanceB
        });
    }

    modifier syncForkTimestamps() {
        uint256 fork = vm.activeFork();
        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: rootStartTime});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        vm.selectFork({forkId: fork});
        _;
    }

    function checkEmissions(address user, address gauge, uint256 expectedBalance) internal {
        vm.startPrank(user);
        ILeafGauge(gauge).getReward(user);
        IERC20 rewardToken = IERC20(ILeafGauge(gauge).rewardToken());
        assertApproxEqAbs(rewardToken.balanceOf(user), expectedBalance, 1e5);
        vm.stopPrank();
    }

    function checkVotingRewards(
        uint256 _tokenId,
        address _tokenA,
        address _tokenB,
        uint256 _expectedBalanceA,
        uint256 _expectedBalanceB
    ) internal {
        vm.selectFork({forkId: rootId});
        address owner = mockEscrow.ownerOf(_tokenId);
        address[] memory tokens = new address[](2);
        tokens[0] = _tokenA;
        tokens[1] = _tokenB;
        _depositGas({_user: owner, _amount: MESSAGE_FEE * 2});
        vm.startPrank({msgSender: owner, txOrigin: owner});
        rootIVR.getReward(_tokenId, tokens);
        rootFVR.getReward(_tokenId, tokens);
        vm.stopPrank();

        // Process both Claims on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        leafMailbox.processNextInboundMessage();

        // Fees and Incentives are lagged by 1 week
        assertApproxEqAbs(IERC20(_tokenA).balanceOf(owner), _expectedBalanceA, 1e6);
        assertApproxEqAbs(IERC20(_tokenB).balanceOf(owner), _expectedBalanceB, 1e6);
    }

    function checkV2VotingRewards(
        uint256 _tokenId,
        address _tokenA,
        address _tokenB,
        uint256 _expectedBalanceA,
        uint256 _expectedBalanceB
    ) internal {
        vm.selectFork({forkId: rootId});
        address owner = mockEscrow.ownerOf(_tokenId);
        address[] memory tokens = new address[](2);
        tokens[0] = _tokenA;
        tokens[1] = _tokenB;
        vm.startPrank(owner);
        IRootFeesVotingReward(v2FVR).getReward(_tokenId, tokens);
        IRootBribeVotingReward(v2IVR).getReward(_tokenId, tokens);
        vm.stopPrank();

        // Fees and Incentives are lagged by 1 week
        assertApproxEqAbs(IERC20(_tokenA).balanceOf(owner), _expectedBalanceA, 1e6);
        assertApproxEqAbs(IERC20(_tokenB).balanceOf(owner), _expectedBalanceB, 1e6);
    }

    function _calculateVotingRewards(uint256 _tokenId, address _ivr, address _fvr, address _tokenA, address _tokenB)
        internal
        view
        returns (uint256 expectedBalanceA, uint256 expectedBalanceB)
    {
        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        // calculate expected rewards for tokenA
        uint256 balance = IReward(_ivr).balanceOf(_tokenId);
        uint256 rewardsLastEpoch = IReward(_ivr).tokenRewardsPerEpoch(_tokenA, epochStart - WEEK);
        expectedBalanceA = rewardsLastEpoch * balance / IReward(_ivr).totalSupply();

        rewardsLastEpoch = IReward(_fvr).tokenRewardsPerEpoch(_tokenA, epochStart - WEEK);
        expectedBalanceA = expectedBalanceA + rewardsLastEpoch * balance / IReward(_fvr).totalSupply();

        // calculate expected rewards for tokenB
        balance = IReward(_ivr).balanceOf(_tokenId);
        rewardsLastEpoch = IReward(_ivr).tokenRewardsPerEpoch(_tokenB, epochStart - WEEK);
        expectedBalanceB = rewardsLastEpoch * balance / IReward(_ivr).totalSupply();

        rewardsLastEpoch = IReward(_fvr).tokenRewardsPerEpoch(_tokenB, epochStart - WEEK);
        expectedBalanceB = expectedBalanceB + rewardsLastEpoch * balance / IReward(_fvr).totalSupply();
    }

    /// @dev Helper function to seed User with WETH to pay for gas in x-chain transactions
    function _depositGas(address _user, uint256 _amount) internal {
        deal({token: address(weth), to: _user, give: _amount});
        vm.prank(_user);
        weth.approve({spender: address(rootMessageBridge), value: _amount});
    }

    /// @dev Helper function to stake existing liquidity into Gauge
    function _stakeLiquidity(address _owner, address _pool, address _gauge) internal {
        vm.startPrank(_owner);
        uint256 liquidity = Pool(_pool).balanceOf(_owner);
        Pool(_pool).approve(_gauge, liquidity);
        ILeafGauge(_gauge).deposit(liquidity);
        vm.stopPrank();
    }

    /// @dev Helper function to deposit liquidity into pool
    function _addLiquidityToPool(
        address _owner,
        address _router,
        address _token0,
        address _token1,
        bool _stable,
        uint256 _amount0,
        uint256 _amount1
    ) internal {
        vm.startPrank(_owner);
        deal(_token0, _owner, _amount0);
        deal(_token1, _owner, _amount1);
        IERC20(_token0).approve(address(_router), _amount0);
        IERC20(_token1).approve(address(_router), _amount1);
        Router(payable(_router)).addLiquidity(
            _token0, _token1, _stable, _amount0, _amount1, 0, 0, _owner, block.timestamp
        );
        vm.stopPrank();
        // Set token balances to 0 after LPing
        deal(_token0, _owner, 0);
        deal(_token1, _owner, 0);
    }

    /// @dev Helper function to generate Fees and Incentives
    function _depositIncentivesAndSimulateSwaps(
        address _ivr,
        address _tokenA,
        address _tokenB,
        bool _stable,
        uint256 _amountA,
        uint256 _amountB
    ) internal {
        // Deposit Incentives in Rewards Contract
        deal(_tokenA, address(this), _amountA);
        deal(_tokenB, address(this), _amountB);
        IERC20(_tokenA).approve(_ivr, _amountA);
        IERC20(_tokenB).approve(_ivr, _amountB);
        BribeVotingReward(_ivr).notifyRewardAmount(_tokenA, _amountA);
        BribeVotingReward(_ivr).notifyRewardAmount(_tokenB, _amountB);

        // Simulate Swaps to accrue Fees
        _simulateMultipleSwaps({
            _tokenA: _tokenA,
            _tokenB: _tokenB,
            _stable: _stable,
            _amountA: _amountA,
            _amountB: _amountB,
            _swapCount: 150
        });
    }

    /// @dev Helper to Simulate Multiple Swaps
    function _simulateMultipleSwaps(
        address _tokenA,
        address _tokenB,
        bool _stable,
        uint256 _amountA,
        uint256 _amountB,
        uint256 _swapCount
    ) internal {
        vm.startPrank(users.owner);
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        bool isV2Swap = _tokenA == address(v2Token0);
        for (uint256 i = 0; i < _swapCount; i++) {
            (tokenIn, tokenOut, amountIn) = i % 2 == 0 ? (_tokenA, _tokenB, _amountA) : (_tokenB, _tokenA, _amountB);
            if (isV2Swap) {
                _simulateV2Swap({_tokenIn: tokenIn, _tokenOut: tokenOut, _stable: _stable, _amount: amountIn});
            } else {
                _simulateSwap({_tokenIn: tokenIn, _tokenOut: tokenOut, _stable: _stable, _amount: amountIn});
            }
        }
        vm.stopPrank();
    }

    /// @dev Helper to Simulate a single Swap on Leaf Chain
    function _simulateSwap(address _tokenIn, address _tokenOut, bool _stable, uint256 _amount) internal {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(_tokenIn, _tokenOut, _stable);

        address _pool = leafPoolFactory.getPool(_tokenIn, _tokenOut, _stable);

        assertEq(leafRouter.getAmountsOut(_amount, routes)[1], IPool(_pool).getAmountOut(_amount, _tokenIn));

        uint256[] memory assertedOutput = leafRouter.getAmountsOut(_amount, routes);
        deal(_tokenIn, users.owner, _amount);
        IERC20(_tokenIn).approve(address(leafRouter), _amount);
        leafRouter.swapExactTokensForTokens({
            amountIn: _amount,
            amountOutMin: assertedOutput[1],
            routes: routes,
            to: address(users.owner),
            deadline: block.timestamp
        });
    }

    /// @dev Helper to Simulate a single Swap on Mainnet
    function _simulateV2Swap(address _tokenIn, address _tokenOut, bool _stable, uint256 _amount) internal {
        IRouterV2.Route[] memory routes = new IRouterV2.Route[](1);
        routes[0] = IRouterV2.Route(_tokenIn, _tokenOut, _stable, address(v2Factory));

        address _pool = v2Factory.getPool(_tokenIn, _tokenOut, _stable);

        assertEq(v2Router.getAmountsOut(_amount, routes)[1], IPool(_pool).getAmountOut(_amount, _tokenIn));

        uint256[] memory assertedOutput = v2Router.getAmountsOut(_amount, routes);
        deal(_tokenIn, users.owner, _amount);
        IERC20(_tokenIn).approve(address(v2Router), _amount);
        v2Router.swapExactTokensForTokens({
            amountIn: _amount,
            amountOutMin: assertedOutput[1],
            routes: routes,
            to: address(users.owner),
            deadline: block.timestamp
        });
    }
}
