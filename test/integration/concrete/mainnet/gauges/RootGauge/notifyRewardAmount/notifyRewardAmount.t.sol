// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract NotifyRewardAmountIntegrationConcreteTest is BaseForkFixture {
    address public rootPool;
    RootGauge public rootGauge;
    address public leafPool;
    LeafGauge public leafGauge;

    function setUp() public override {
        super.setUp();

        vm.prank(users.owner);
        vm.selectFork({forkId: originId});
        rootPool = originRootPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false});
        rootGauge =
            RootGauge(mockVoter.createGauge({_poolFactory: address(originRootPoolFactory), _pool: address(rootPool)}));

        vm.selectFork({forkId: destinationId});
        leafPool = destinationPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false});
        leafGauge = LeafGauge(
            destinationLeafGaugeFactory.createGauge({
                _token0: address(token0),
                _token1: address(token1),
                _stable: false,
                _feesVotingReward: address(11),
                isPool: true
            })
        );

        vm.selectFork({forkId: originId});
    }

    function test_WhenTheCallerIsNotVoter() external {
        // It should revert with NotVoter
    }

    modifier whenTheCallerIsVoter() {
        _;
    }

    function test_WhenTheAmountIsZero() external whenTheCallerIsVoter {
        // It should revert with ZeroAmount
    }

    function test_WhenTheAmountIsGreaterThanZeroAndSmallerThanTheTimeUntilTheNextTimestamp()
        external
        whenTheCallerIsVoter
    {
        // It should revert with ZeroRewardRate
    }

    modifier whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenTheCallerIsVoter
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_originMintingLimit: amount, _destinationMintingLimit: amount});

        deal({token: address(originRewardToken), to: address(mockVoter), give: amount});
        vm.startPrank(address(mockVoter));
        originRewardToken.approve({spender: address(rootGauge), value: amount});

        assertEq(rootGauge.rewardToken(), address(originRewardToken));

        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(originRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(originRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(originXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: destinationId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(destinationBridge), _amount: amount});
        destinationMailbox.processNextInboundMessage();
        assertEq(destinationXVelo.balanceOf(address(leafGauge)), amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(originStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenTheCallerIsVoter
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_originMintingLimit: amount * 2, _destinationMintingLimit: amount * 2});

        deal({token: address(originRewardToken), to: address(mockVoter), give: amount * 2});
        vm.startPrank(address(mockVoter));
        originRewardToken.approve({spender: address(rootGauge), value: amount * 2});

        // inital deposit of partial amount
        rootGauge.notifyRewardAmount({_amount: amount});
        vm.selectFork({forkId: destinationId});
        destinationMailbox.processNextInboundMessage();

        skipTime(WEEK / 7 * 5);

        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(originRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(originRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(originXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: destinationId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(destinationBridge), _amount: amount});
        destinationMailbox.processNextInboundMessage();
        assertEq(destinationXVelo.balanceOf(address(leafGauge)), amount * 2);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = WEEK * 2 / 7;
        uint256 rewardRate = ((amount / WEEK) * timeUntilNext + amount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(originStartTime), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
    }
}
