// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract CalculateMaxEmissionsIntegrationConcreteTest is RootGaugeFactoryTest {
    using stdStorage for StdStorage;

    uint256 public WEEKLY_DECAY;
    uint256 public TAIL_START_TIMESTAMP;

    function setUp() public override {
        super.setUp();

        WEEKLY_DECAY = rootGaugeFactory.WEEKLY_DECAY();
        TAIL_START_TIMESTAMP = rootGaugeFactory.TAIL_START_TIMESTAMP();

        /// @dev Overwrite `totalSupply` to be identical to VELO supply at fork timestamp
        uint256 totalSupply = IERC20(minter.velo()).totalSupply();
        stdstore.target(address(rootRewardToken)).sig("totalSupply()").checked_write(totalSupply);
    }

    modifier whenActivePeriodIsNotEqualToActivePeriodInMinter() {
        assertNotEq(rootGaugeFactory.activePeriod(), minter.activePeriod());
        _;
    }

    function test_WhenTailEmissionsHaveStarted() external whenActivePeriodIsNotEqualToActivePeriodInMinter {
        // It should calculate tail emissions
        // It should cache the current minter active period
        // It should cache the weekly emissions for this epoch
        // It should return max amount based on weekly emissions and gauge emission cap

        /// @dev `weekly` on first week of tail emissions is approximately 5_950_167 tokens
        stdstore.target(address(minter)).sig("weekly()").checked_write(5_950_167 * TOKEN_1);
        stdstore.target(address(minter)).sig("activePeriod()").checked_write(rootGaugeFactory.TAIL_START_TIMESTAMP());

        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * minter.tailEmissionRate()) / MAX_BPS;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 expectedMaxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;

        uint256 maxAmount = rootGaugeFactory.calculateMaxEmissions({_gauge: address(rootGauge)});

        assertEq(rootGaugeFactory.activePeriod(), minter.activePeriod());
        assertEq(rootGaugeFactory.weeklyEmissions(), weeklyEmissions);
        assertEq(maxAmount, expectedMaxAmount);
    }

    function test_WhenTailEmissionsHaveNotStarted() external whenActivePeriodIsNotEqualToActivePeriodInMinter {
        // It should weekly emissions before decay
        // It should cache the current minter active period
        // It should cache the weekly emissions for this epoch
        // It should return max amount based on weekly emissions and gauge emission cap
        uint256 weeklyEmissions = (minter.weekly() * MAX_BPS) / WEEKLY_DECAY;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 expectedMaxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;

        uint256 maxAmount = rootGaugeFactory.calculateMaxEmissions({_gauge: address(rootGauge)});

        assertEq(rootGaugeFactory.activePeriod(), minter.activePeriod());
        assertEq(rootGaugeFactory.weeklyEmissions(), weeklyEmissions);
        assertEq(maxAmount, expectedMaxAmount);
    }

    function test_WhenActivePeriodIsEqualToActivePeriodInMinter() external {
        // It should return max amount based on cached weekly emissions and gauge emission cap
        rootGaugeFactory.calculateMaxEmissions({_gauge: address(rootGauge)});
        assertEq(rootGaugeFactory.activePeriod(), minter.activePeriod());

        uint256 weeklyEmissions = rootGaugeFactory.weeklyEmissions();
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 expectedMaxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;

        uint256 maxAmount = rootGaugeFactory.calculateMaxEmissions({_gauge: address(rootGauge)});

        assertEq(rootGaugeFactory.activePeriod(), minter.activePeriod());
        assertEq(rootGaugeFactory.weeklyEmissions(), weeklyEmissions);
        assertEq(maxAmount, expectedMaxAmount);
    }
}
