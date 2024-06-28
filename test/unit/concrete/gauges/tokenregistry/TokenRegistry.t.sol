// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

contract TokenRegistryTest is BaseFixture {
    function test_InitialState() public view {
        assertEq(tokenRegistry.admin(), users.owner);
        assertTrue(tokenRegistry.isWhitelistedToken(address(token0)));
        assertTrue(tokenRegistry.isWhitelistedToken(address(token1)));
    }
}
