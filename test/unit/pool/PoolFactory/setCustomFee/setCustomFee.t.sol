// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../../BaseFixture.sol";

contract SetCustomFeeTest is BaseFixture {
    Pool public pool;
    uint256 fee;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with NotFeeManager
        vm.prank(users.charlie);
        vm.expectRevert(IPoolFactory.NotFeeManager.selector);
        poolFactory.setCustomFee(address(pool), 5);
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank(poolFactory.feeManager());
        _;
        vm.stopPrank();
    }

    function test_WhenTheFeeIsGreaterThanMaximumFeeAndDoesNotEqualZeroFeeIndicator() external whenCallerIsFeeManager {
        // It should revert with FeeTooHigh
        vm.expectRevert(IPoolFactory.FeeTooHigh.selector);
        poolFactory.setCustomFee(address(pool), 301); // 301 bps = 3.01%
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
        // It should revert with InvalidPool
        vm.expectRevert(IPoolFactory.InvalidPool.selector);
        poolFactory.setCustomFee(address(1), fee);
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
        assertEq(poolFactory.getFee(address(pool), true), 42);
        assertEq(poolFactory.getFee(address(pool), false), 69);

        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetCustomFee({pool: address(pool), fee: fee});
        poolFactory.setCustomFee(address(pool), fee);
        assertEq(poolFactory.getFee(address(pool), true), fee);
        assertEq(poolFactory.getFee(address(pool), false), fee);

        // setting custom fee back to 0 gives default stable / non-stable fees
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetCustomFee({pool: address(pool), fee: 0});
        poolFactory.setCustomFee(address(pool), 0);
        assertEq(poolFactory.getFee(address(pool), true), 42);
        assertEq(poolFactory.getFee(address(pool), false), 69);

        // setting custom fee to 420 indicates there is 0% fee for the pool
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetCustomFee({pool: address(pool), fee: 420});
        poolFactory.setCustomFee(address(pool), 420);
        assertEq(poolFactory.getFee(address(pool), true), 0);
        assertEq(poolFactory.getFee(address(pool), false), 0);
    }
}
