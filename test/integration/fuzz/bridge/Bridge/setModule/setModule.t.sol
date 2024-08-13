// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract SetModuleIntegrationFuzzTest is BridgeTest {
    function testFuzz_WhenCallerIsNotOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootBridge.setModule(address(0));
    }
}
