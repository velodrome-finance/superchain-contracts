// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract RootGaugeFactoryTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(originRootGaugeFactory.voter(), address(mockVoter));
        assertEq(originRootGaugeFactory.xerc20(), address(originXVelo));
        assertEq(originRootGaugeFactory.lockbox(), address(originLockbox));
        assertEq(originRootGaugeFactory.bridge(), address(originBridge));
    }
}
