// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Factory.t.sol";

contract DeployXERC20WithLockboxUnitFuzzTest is XERC20FactoryTest {
    function setUp() public override {
        super.setUp();

        // chain is already optimism

        vm.startPrank(users.alice);
    }

    modifier givenXERC20NotYetDeployed() {
        _;
    }

    function testFuzz_GivenChainIdIsNot10(uint8 chainId) external givenXERC20NotYetDeployed {
        // It should revert with {InvalidChainId}
        vm.assume(chainId != 10);
        vm.chainId(chainId);

        vm.expectRevert(IXERC20Factory.InvalidChainId.selector);
        xFactory.deployXERC20WithLockbox();
    }
}
