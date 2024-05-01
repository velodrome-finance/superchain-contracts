// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract PoolFactoryTest is BaseFixture {
    function test_InitialState() public view {
        assertEq(poolFactory.poolAdmin(), users.owner);
        assertEq(poolFactory.pauser(), users.owner);
        assertEq(poolFactory.feeManager(), users.feeManager);
    }
}
