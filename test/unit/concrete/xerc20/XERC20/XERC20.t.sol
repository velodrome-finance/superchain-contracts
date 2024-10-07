// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

abstract contract XERC20Test is BaseFixture {
    function test_InitialState() public view {
        assertEq(xVelo.name(), "Superchain Velodrome");
        assertEq(xVelo.symbol(), "XVELO");
        assertEq(xVelo.owner(), users.owner);
        assertEq(xVelo.lockbox(), address(lockbox));
        assertEq(xVelo.SUPERCHAIN_ERC20_BRIDGE(), SUPERCHAIN_ERC20_BRIDGE);
    }
}
