// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PaymasterVault.t.sol";

contract ReceiveIntegrationConcreteTest is PaymasterVaultTest {
    function test_WhenTheCallerIsAnyone() external {
        // It receives the ETH amount
        uint256 amount = 1 ether;
        vm.deal(users.alice, amount);

        uint256 oldBal = address(rootModuleVault).balance;

        vm.startPrank(users.alice);
        (bool success,) = payable(rootModuleVault).call{value: amount}("");

        assertTrue(success);
        assertEq(address(rootModuleVault).balance, oldBal + amount);
        assertEq(users.alice.balance, 0);
    }
}
