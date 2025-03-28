// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract ReceiveIntegrationConcreteTest is RootHLMessageModuleTest {
    function test_WhenTheCallerIsNotVault() external {
        // It reverts with {NotPaymasterVault}
        vm.deal({account: users.charlie, newBalance: 1 ether});

        vm.prank(users.charlie);
        vm.expectRevert(IPaymaster.NotPaymasterVault.selector);
        (bool success,) = payable(rootMessageModule).call{value: 1 ether}("");

        assertTrue(success);
    }

    function test_WhenTheCallerIsVault() external {
        // It receives ETH
        vm.deal({account: address(rootModuleVault), newBalance: 1 ether});

        vm.startPrank(address(rootModuleVault));
        (bool success,) = payable(rootMessageModule).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(rootMessageModule).balance, 1 ether);
    }
}
