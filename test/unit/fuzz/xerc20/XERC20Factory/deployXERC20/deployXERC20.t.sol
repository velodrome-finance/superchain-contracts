// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Factory.t.sol";

contract DeployXERC20UnitFuzzTest is XERC20FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(users.alice);
    }

    modifier givenXERC20NotYetDeployed() {
        _;
    }

    function testFuzz_GivenChainIdIsNot10(uint8 chainId) external givenXERC20NotYetDeployed {
        // It should create a new XERC20 instance
        // It should set the name and symbol of the new XERC20 instance
        // It should set the owner of the new XERC20 instance to the factory
        // It should emit a {DeployXERC20} event
        vm.assume(chainId != 10);
        vm.chainId(chainId);

        bytes32 guardedSalt = keccak256(
            abi.encodePacked(
                uint256(uint160(address(xFactory))),
                CreateXLibrary.calculateSalt({_entropy: XERC20_ENTROPY, _deployer: address(xFactory)})
            )
        );
        address expectedTokenAddress = cx.computeCreate3Address({salt: guardedSalt, deployer: address(cx)});

        vm.expectEmit(address(xFactory));
        emit IXERC20Factory.DeployXERC20({_xerc20: expectedTokenAddress});
        address xerc20 = xFactory.deployXERC20();

        assertEq(xerc20, expectedTokenAddress);
        assertEq(IERC20Metadata(xerc20).name(), "Superchain Velodrome");
        assertEq(IERC20Metadata(xerc20).symbol(), "XVELO");
        assertEq(Ownable(xerc20).owner(), users.owner);
        assertEq(XERC20(xerc20).lockbox(), address(0));
    }
}
