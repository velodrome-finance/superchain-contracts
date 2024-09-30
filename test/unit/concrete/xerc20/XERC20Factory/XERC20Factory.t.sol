// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

abstract contract XERC20FactoryTest is BaseFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.revertToAndDelete(snapshot);
    }

    function test_InitialState() public view {
        assertEq(address(xFactory.createx()), 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);
        assertEq(xFactory.owner(), users.owner);
    }
}
