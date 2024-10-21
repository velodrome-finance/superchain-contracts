// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PoolFactory.t.sol";

contract GetFeeTest is PoolFactoryTest {
    Pool public pool;
    uint256 public stableFee;
    uint256 public volatileFee;

    function setUp() public override {
        super.setUp();

        stableFee = poolFactory.stableFee();
        volatileFee = poolFactory.volatileFee();
        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    modifier whenFeeModuleIsAddressZero() {
        _;
    }

    function test_WhenPoolIsStable() external view whenFeeModuleIsAddressZero {
        // It should return stable fee
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: true}), stableFee);
    }

    function test_WhenPoolIsVolatile() external view whenFeeModuleIsAddressZero {
        // It should return volatile fee
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: false}), volatileFee);
    }

    modifier whenFeeModuleIsNotAddressZero() {
        vm.prank(poolFactory.feeManager());
        poolFactory.setFeeModule({_feeModule: address(feeModule)});
        _;
    }

    modifier whenSafeCallSucceeds() {
        _;
    }

    function test_WhenFeeIsSmallerThanOrEqualToMax() external whenFeeModuleIsNotAddressZero whenSafeCallSucceeds {
        // It should return custom fee
        vm.startPrank(poolFactory.feeManager());
        feeModule.setCustomFee(address(pool), 200);
        feeModule.setCustomFee(address(pool), 200);
        vm.stopPrank();

        assertEq(poolFactory.getFee({_pool: address(pool), _stable: true}), 200);
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: false}), 200);
    }

    modifier whenFeeIsGreaterThanMax() {
        /// @dev Simulate malicious fee module with fee too large
        vm.mockCall({
            callee: address(feeModule),
            data: abi.encodeWithSelector(IFeeModule.getFee.selector),
            returnData: abi.encode(1_001)
        });
        _;
    }

    function test_WhenPoolIsStable_()
        external
        whenFeeModuleIsNotAddressZero
        whenSafeCallSucceeds
        whenFeeIsGreaterThanMax
    {
        // It should return stable fee
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: true}), stableFee);
    }

    function test_WhenPoolIsVolatile_()
        external
        whenFeeModuleIsNotAddressZero
        whenSafeCallSucceeds
        whenFeeIsGreaterThanMax
    {
        // It should return volatile fee
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: false}), volatileFee);
    }

    modifier whenSafeCallFails() {
        vm.startPrank(poolFactory.feeManager());
        feeModule.setCustomFee(address(pool), 200);
        feeModule.setCustomFee(address(pool), 200);
        vm.stopPrank();

        /// @dev Simulate revert for safecall to fail
        vm.mockCallRevert({
            callee: address(feeModule),
            data: abi.encodeWithSelector(IFeeModule.getFee.selector),
            revertData: ""
        });
        _;
    }

    function test_WhenPoolIsStable__() external whenFeeModuleIsNotAddressZero whenSafeCallFails {
        // It should return stable fee
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: true}), stableFee);
    }

    function test_WhenPoolIsVolatile__() external whenFeeModuleIsNotAddressZero whenSafeCallFails {
        // It should return volatile fee
        assertEq(poolFactory.getFee({_pool: address(pool), _stable: false}), volatileFee);
    }
}
