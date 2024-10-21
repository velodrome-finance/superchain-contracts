// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CustomFeeModule.t.sol";

contract SetCustomFeeTest is CustomFeeModuleTest {
    Pool public stablePool;
    Pool public volatilePool;
    uint24 public fee;

    function setUp() public override {
        super.setUp();

        stablePool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        volatilePool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false}));
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with {NotFeeManager}
        vm.prank(users.charlie);
        vm.expectRevert(ICustomFeeModule.NotFeeManager.selector);
        feeModule.setCustomFee(address(stablePool), 5);
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank(poolFactory.feeManager());
        _;
        vm.stopPrank();
    }

    function test_WhenTheFeeIsGreaterThanMaximumFeeAndDoesNotEqualZeroFeeIndicator() external whenCallerIsFeeManager {
        // It should revert with {FeeTooHigh}
        vm.expectRevert(ICustomFeeModule.FeeTooHigh.selector);
        feeModule.setCustomFee(address(stablePool), 301); // 301 bps = 3.01%
    }

    modifier whenTheFeeIsLowerThanOrEqualToMaximumFeeOrEqualsZeroFeeIndicator() {
        fee = 69;
        _;
    }

    function test_WhenThePoolIsNotAValidPool()
        external
        whenCallerIsFeeManager
        whenTheFeeIsLowerThanOrEqualToMaximumFeeOrEqualsZeroFeeIndicator
    {
        // It should revert with {InvalidPool}
        vm.expectRevert(ICustomFeeModule.InvalidPool.selector);
        feeModule.setCustomFee(address(1), fee);
    }

    function test_WhenThePoolIsAValidPool()
        external
        whenCallerIsFeeManager
        whenTheFeeIsLowerThanOrEqualToMaximumFeeOrEqualsZeroFeeIndicator
    {
        // It should set the custom fee for the pool
        // It should emit a {SetCustomFee} event

        // differentiate fees for stable / non-stable
        poolFactory.setFee(true, 42);
        poolFactory.setFee(false, 69);

        // pool does not have custom fees- return fee correlating to boolean
        assertEq(feeModule.getFee(address(stablePool)), 42);
        assertEq(feeModule.getFee(address(volatilePool)), 69);

        // set custom fees in pools
        vm.expectEmit(address(feeModule));
        emit ICustomFeeModule.SetCustomFee({pool: address(stablePool), fee: fee});
        feeModule.setCustomFee(address(stablePool), fee);
        assertEq(feeModule.customFee(address(stablePool)), fee);
        assertEq(feeModule.getFee(address(stablePool)), fee);

        vm.expectEmit(address(feeModule));
        emit ICustomFeeModule.SetCustomFee({pool: address(volatilePool), fee: fee});
        feeModule.setCustomFee(address(volatilePool), fee);
        assertEq(feeModule.customFee(address(volatilePool)), fee);
        assertEq(feeModule.getFee(address(volatilePool)), fee);

        // setting custom fee back to 0 gives default stable / non-stable fees
        vm.expectEmit(address(feeModule));
        emit ICustomFeeModule.SetCustomFee({pool: address(stablePool), fee: 0});
        feeModule.setCustomFee(address(stablePool), 0);
        assertEq(feeModule.customFee(address(stablePool)), 0);
        assertEq(feeModule.getFee(address(stablePool)), 42);

        vm.expectEmit(address(feeModule));
        emit ICustomFeeModule.SetCustomFee({pool: address(volatilePool), fee: 0});
        feeModule.setCustomFee(address(volatilePool), 0);
        assertEq(feeModule.customFee(address(volatilePool)), 0);
        assertEq(feeModule.getFee(address(volatilePool)), 69);

        // setting custom fee to 420 indicates there is 0% fee for the pool
        vm.expectEmit(address(feeModule));
        emit ICustomFeeModule.SetCustomFee({pool: address(stablePool), fee: 420});
        feeModule.setCustomFee(address(stablePool), 420);
        assertEq(feeModule.customFee(address(stablePool)), 420);
        assertEq(feeModule.getFee(address(stablePool)), 0);

        vm.expectEmit(address(feeModule));
        emit ICustomFeeModule.SetCustomFee({pool: address(volatilePool), fee: 420});
        feeModule.setCustomFee(address(volatilePool), 420);
        assertEq(feeModule.customFee(address(volatilePool)), 420);
        assertEq(feeModule.getFee(address(volatilePool)), 0);
    }
}
