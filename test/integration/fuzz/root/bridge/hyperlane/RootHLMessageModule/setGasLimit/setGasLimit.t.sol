// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetGasLimitIntegrationFuzzTest is RootHLMessageModuleTest {
    function testFuzz_WhenTheCallerIsNotOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        uint256 _command = 1;
        uint256 _gasLimit = 1000;
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootMessageModule.setGasLimit({_command: _command, _gasLimit: _gasLimit});
    }

    function testFuzz_WhenTheCallerIsOwner(uint256 _command, uint256 _gasLimit) external {
        // It should set the gas limit for the given command
        // It should emit a {GasLimitSet} event
        vm.startPrank(users.owner);
        vm.expectEmit(address(rootMessageModule));
        emit IGasRouter.GasLimitSet({_command: _command, _gasLimit: _gasLimit});
        rootMessageModule.setGasLimit({_command: _command, _gasLimit: _gasLimit});

        assertEq(rootMessageModule.gasLimit(_command), _gasLimit);
    }
}
