// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetGasLimitIntegrationConcreteTest is RootHLMessageModuleTest {
    uint256 _command = 1;
    uint256 _gasLimit = 1000;

    function test_WhenTheCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootMessageModule.setGasLimit({_command: _command, _gasLimit: _gasLimit});
    }

    function test_WhenTheCallerIsOwner() external {
        // It should set the gas limit for the given command
        // It should emit a {GasLimitSet} event
        vm.startPrank(users.owner);
        vm.expectEmit(address(rootMessageModule));
        emit IGasRouter.GasLimitSet({_command: _command, _gasLimit: _gasLimit});
        rootMessageModule.setGasLimit({_command: _command, _gasLimit: _gasLimit});

        assertEq(rootMessageModule.gasLimit(_command), _gasLimit);
    }
}
