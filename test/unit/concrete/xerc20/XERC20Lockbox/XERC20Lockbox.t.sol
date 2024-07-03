// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

abstract contract XERC20LockboxTest is BaseFixture {
    function testInitialState() public view {
        assertEq(address(lockbox.ERC20()), address(rewardToken));
        assertEq(address(lockbox.XERC20()), address(xVelo));
    }
}
