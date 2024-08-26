// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract RootPoolFactoryTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(rootPoolFactory.implementation(), address(rootPoolImplementation));
        assertEq(rootPoolFactory.chainId(), leaf);
    }
}
