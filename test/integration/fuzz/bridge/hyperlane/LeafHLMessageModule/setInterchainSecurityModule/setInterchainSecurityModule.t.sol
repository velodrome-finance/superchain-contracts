// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafHLMessageModule.t.sol";

contract SetInterchainSecurityModuleIntegrationFuzzTest is LeafHLMessageModuleTest {
    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function testFuzz_WhenTheCallerIsNotTheOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        leafMessageModule.setInterchainSecurityModule({_ism: address(0)});
    }

    function testFuzz_WhenTheCallerIsTheOwner(address _ism) external {
        // It sets the new InterchainSecurityModule
        // It emits the {InterchainSecurityModuleSet} event
        vm.startPrank(users.owner);

        vm.expectEmit(address(leafMessageModule));
        emit ISpecifiesInterchainSecurityModule.InterchainSecurityModuleSet({_new: _ism});
        leafMessageModule.setInterchainSecurityModule({_ism: _ism});

        assertEq(address(leafMessageModule.securityModule()), _ism);
    }

    function testGas_setInterchainSecurityModule() external {
        vm.prank(users.owner);
        leafMessageModule.setInterchainSecurityModule({_ism: address(1)});
        vm.snapshotGasLastCall("LeafHLMessageModule_setInterchainSecurityModule");
    }
}
