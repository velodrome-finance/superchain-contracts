// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CustomFeeModule.t.sol";

contract GetFeeTest is CustomFeeModuleTest {
    Pool public stablePool;
    Pool public volatilePool;
    uint256 public stableFee;
    uint256 public volatileFee;

    function setUp() public override {
        super.setUp();

        stableFee = poolFactory.stableFee();
        volatileFee = poolFactory.volatileFee();
        stablePool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        volatilePool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false}));
    }

    function test_WhenCustomFeeIsZeroFeeIndicator() external {
        // It should return 0
        vm.prank(poolFactory.feeManager());
        feeModule.setCustomFee(address(stablePool), 420);

        assertEq(feeModule.getFee({_pool: address(stablePool)}), 0);
    }

    modifier whenCustomFeeIsNotZeroFeeIndicator() {
        _;
    }

    modifier whenCustomFeeIsZero() {
        _;
    }

    function test_WhenPoolIsStable() external view whenCustomFeeIsNotZeroFeeIndicator whenCustomFeeIsZero {
        // It should return stable fee
        assertEq(feeModule.getFee({_pool: address(stablePool)}), stableFee);
    }

    function test_WhenPoolIsVolatile() external view whenCustomFeeIsNotZeroFeeIndicator whenCustomFeeIsZero {
        // It should return volatile fee
        assertEq(feeModule.getFee({_pool: address(volatilePool)}), volatileFee);
    }

    function test_WhenCustomFeeIsNotZero() external whenCustomFeeIsNotZeroFeeIndicator {
        // It should return custom fee
        vm.startPrank(poolFactory.feeManager());
        feeModule.setCustomFee(address(stablePool), 100);
        feeModule.setCustomFee(address(volatilePool), 100);
        vm.stopPrank();

        assertEq(feeModule.getFee({_pool: address(stablePool)}), 100);
        assertEq(feeModule.getFee({_pool: address(volatilePool)}), 100);
    }
}
