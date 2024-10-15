// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract CalculateMaxEmissionsIntegrationFuzzTest is RootGaugeFactoryTest {
    using stdStorage for StdStorage;

    uint256 public WEEKLY_DECAY;
    uint256 public TAIL_START_TIMESTAMP;
    uint256 public constant MINIMUM_TAIL_RATE = 1;
    uint256 public constant MAXIMUM_TAIL_RATE = 100;

    function setUp() public override {
        super.setUp();

        WEEKLY_DECAY = rootGaugeFactory.WEEKLY_DECAY();
        TAIL_START_TIMESTAMP = rootGaugeFactory.TAIL_START_TIMESTAMP();

        /// @dev Overwrite `totalSupply` to be identical to VELO supply at fork timestamp
        rootRewardToken = IERC20(minter.velo());
        uint256 totalSupply = rootRewardToken.totalSupply();
        stdstore.target(address(rootRewardToken)).sig("totalSupply()").checked_write(totalSupply);
    }

    modifier whenActivePeriodIsNotEqualToActivePeriodInMinter() {
        assertNotEq(rootGaugeFactory.activePeriod(), minter.activePeriod());
        _;
    }

    function testFuzz_WhenTailEmissionsHaveStarted(uint256 _emissionCap, uint256 _tailRate, uint256 _totalSupply)
        external
        whenActivePeriodIsNotEqualToActivePeriodInMinter
    {
        // It should calculate tail emissions
        // It should cache the current minter active period
        // It should cache the weekly emissions for this epoch
        // It should return max amount based on weekly emissions and gauge emission cap
        _emissionCap = bound(_emissionCap, 1, MAX_BPS);
        _tailRate = bound(_tailRate, MINIMUM_TAIL_RATE, MAXIMUM_TAIL_RATE);
        _totalSupply = bound(_totalSupply, rootRewardToken.totalSupply(), MAX_TOKENS);

        /// @dev `weekly` on first week of tail emissions is approximately 5_950_167 tokens
        stdstore.target(address(minter)).sig("weekly()").checked_write(5_950_167 * TOKEN_1);
        stdstore.target(address(minter)).sig("tailEmissionRate()").checked_write(_tailRate);
        stdstore.target(address(minter)).sig("activePeriod()").checked_write(rootGaugeFactory.TAIL_START_TIMESTAMP());
        stdstore.target(address(rootRewardToken)).sig("totalSupply()").checked_write(_totalSupply);

        vm.prank(rootGaugeFactory.emissionAdmin());
        rootGaugeFactory.setEmissionCap({_gauge: address(rootGauge), _emissionCap: _emissionCap});

        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * minter.tailEmissionRate()) / MAX_BPS;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 expectedMaxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;

        uint256 maxAmount = rootGaugeFactory.calculateMaxEmissions({_gauge: address(rootGauge)});

        assertEq(rootGaugeFactory.activePeriod(), minter.activePeriod());
        assertEq(rootGaugeFactory.weeklyEmissions(), weeklyEmissions);
        assertEq(maxAmount, expectedMaxAmount);
    }

    function testFuzz_WhenTailEmissionsHaveNotStarted(uint256 _emissionCap, uint256 _weekly)
        external
        whenActivePeriodIsNotEqualToActivePeriodInMinter
    {
        // It should calculate weekly emissions before decay
        // It should cache the current minter active period
        // It should cache the weekly emissions for this epoch
        // It should return max amount based on weekly emissions and gauge emission cap
        _emissionCap = bound(_emissionCap, 1, MAX_BPS);
        _weekly = bound(_weekly, 6_000_000 * TOKEN_1, MAX_TOKENS);

        vm.prank(rootGaugeFactory.emissionAdmin());
        rootGaugeFactory.setEmissionCap({_gauge: address(rootGauge), _emissionCap: _emissionCap});
        stdstore.target(address(minter)).sig("weekly()").checked_write(_weekly);

        uint256 weeklyEmissions = (minter.weekly() * MAX_BPS) / WEEKLY_DECAY;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 expectedMaxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;

        uint256 maxAmount = rootGaugeFactory.calculateMaxEmissions({_gauge: address(rootGauge)});

        assertEq(rootGaugeFactory.activePeriod(), minter.activePeriod());
        assertEq(rootGaugeFactory.weeklyEmissions(), weeklyEmissions);
        assertEq(maxAmount, expectedMaxAmount);
    }
}
