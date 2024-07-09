// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Factory.t.sol";

contract DeployXERC20UnitConcreteTest is XERC20FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
    }

    function test_GivenXERC20AlreadyDeployed() external {
        // It should revert with {XERC20AlreadyDeployed}
        xFactory.deployXERC20();

        vm.expectRevert(abi.encodeWithSelector(CreateX.FailedContractCreation.selector, address(cx)));
        xFactory.deployXERC20();
    }

    modifier givenXERC20NotYetDeployed() {
        _;
    }

    function test_GivenChainIdIs10() external givenXERC20NotYetDeployed {
        // It should revert with {InvalidChainId}
        vm.chainId(10);

        vm.expectRevert(IXERC20Factory.InvalidChainId.selector);
        xFactory.deployXERC20();
    }

    function test_GivenChainIdIsNot10() external givenXERC20NotYetDeployed {
        // It should create a new XERC20 instance
        // It should set the name and symbol of the new XERC20 instance
        // It should set the owner of the new XERC20 instance to the factory
        // It should emit a {DeployXERC20} event
        bytes32 guardedSalt = keccak256(
            abi.encodePacked(
                uint256(uint160(address(xFactory))),
                calculateSalt({deployer: address(xFactory), entropy: XERC20_ENTROPY})
            )
        );
        address expectedTokenAddress = cx.computeCreate3Address({salt: guardedSalt, deployer: address(cx)});

        vm.expectEmit(address(xFactory));
        emit IXERC20Factory.DeployXERC20({_xerc20: expectedTokenAddress});
        address xerc20 = xFactory.deployXERC20();

        assertEq(xerc20, expectedTokenAddress);
        assertEq(IERC20Metadata(xerc20).name(), "Superchain Velodrome");
        assertEq(IERC20Metadata(xerc20).symbol(), "XVELO");
        assertEq(Ownable(xerc20).owner(), address(xFactory));
    }
}
