// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract PoolTest is BaseFixture {
    function test_RevertIf_SyncPoolIfNoLiquidity() external {
        address token1 = address(new TestERC20("", "", 18));
        address token2 = address(new TestERC20("", "", 18));
        address newPool = poolFactory.createPool(token1, token2, true);

        vm.expectRevert(IPool.InsufficientLiquidity.selector);
        IPool(newPool).sync();
    }
}
