// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

abstract contract XERC20Test is BaseFixture {
    function test_InitialState() public view {
        assertEq(xVelo.name(), "Superchain Velodrome");
        assertEq(xVelo.symbol(), "XVELO");
        assertEq(xVelo.FACTORY(), address(this));
        assertEq(xVelo.owner(), address(this));
    }
}
