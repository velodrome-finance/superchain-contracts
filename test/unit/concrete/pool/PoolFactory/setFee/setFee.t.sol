// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

contract SetFeeTest is BaseFixture {
    Pool public pool;
    uint256 public fee;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with {NotFeeManager}
        vm.prank(users.charlie);
        vm.expectRevert(IPoolFactory.NotFeeManager.selector);
        poolFactory.setFee({_stable: true, _fee: 2});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank(poolFactory.feeManager());
        _;
        vm.stopPrank();
    }

    function test_WhenTheFeeIsGreaterThanMaximumFee() external whenCallerIsFeeManager {
        // It should revert with {FeeTooHigh}
        vm.expectRevert(IPoolFactory.FeeTooHigh.selector);
        poolFactory.setFee({_stable: true, _fee: 301}); // 301 bps = 3.01%
    }

    modifier whenTheFeeIsNotGreaterThanMaximumFee() {
        fee = 69;
        _;
    }

    function test_WhenTheFeeIsEqualTo0() external whenCallerIsFeeManager whenTheFeeIsNotGreaterThanMaximumFee {
        // It should revert with {ZeroFee}
        vm.expectRevert(IPoolFactory.ZeroFee.selector);
        poolFactory.setFee({_stable: true, _fee: 0});
    }

    modifier whenTheFeeIsNotEqualTo0() {
        fee = 69;
        _;
    }

    function test_WhenTheStableIsTrue()
        external
        whenCallerIsFeeManager
        whenTheFeeIsNotGreaterThanMaximumFee
        whenTheFeeIsNotEqualTo0
    {
        // It should set the stable fee
        // It should emit a {SetDefaultFee} event
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetDefaultFee({stable: true, fee: fee});
        poolFactory.setFee({_stable: true, _fee: fee});
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: true}), fee);
    }

    function test_WhenTheStableIsFalse()
        external
        whenCallerIsFeeManager
        whenTheFeeIsNotGreaterThanMaximumFee
        whenTheFeeIsNotEqualTo0
    {
        // It should set the volatile fee
        // It should emit a {SetDefaultFee} event
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetDefaultFee({stable: false, fee: fee});
        poolFactory.setFee({_stable: false, _fee: fee});
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: false}), fee);
    }
}
