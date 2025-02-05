// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PaymasterVault.t.sol";

contract ReceiveIntegrationFuzzTest is PaymasterVaultTest {
    function testFuzz_WhenTheCallerIsAnyone(address _caller, uint256 _amount) external {
        // It receives the ETH amount
        vm.assume(_caller != address(0) && _caller != address(rootModuleVault));
        _amount = bound(_amount, 1, MAX_TOKENS);
        vm.deal(_caller, _amount);

        uint256 oldBal = address(rootModuleVault).balance;

        vm.startPrank(_caller);
        (bool success,) = payable(rootModuleVault).call{value: _amount}("");

        assertTrue(success);
        assertEq(address(rootModuleVault).balance, oldBal + _amount);
        assertEq(_caller.balance, 0);
    }
}
