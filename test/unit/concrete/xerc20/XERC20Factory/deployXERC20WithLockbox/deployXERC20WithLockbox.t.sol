// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Factory.t.sol";

contract DeployXERC20WithLockboxUnitConcreteTest is XERC20FactoryTest {
    function setUp() public override {
        super.setUp();

        // chain is already optimism

        vm.startPrank(users.alice);
    }

    function test_GivenXERC20AlreadyDeployed() external {
        // It should revert with {FailedContractCreation}
        xFactory.deployXERC20WithLockbox({_erc20: address(rewardToken)});

        vm.expectRevert(abi.encodeWithSelector(CreateX.FailedContractCreation.selector, address(cx)));
        xFactory.deployXERC20WithLockbox({_erc20: address(rewardToken)});
    }

    modifier givenXERC20NotYetDeployed() {
        _;
    }

    function test_GivenChainIdIsNot10() external givenXERC20NotYetDeployed {
        // It should revert with {InvalidChainId}
        vm.chainId(31337);

        vm.expectRevert(IXERC20Factory.InvalidChainId.selector);
        xFactory.deployXERC20WithLockbox({_erc20: address(rewardToken)});
    }

    function test_GivenChainIdIs10() external givenXERC20NotYetDeployed {
        // It should create a new XERC20 instance
        // It should create a new XERC20Lockbox instance
        // It should set the name and symbol of the new XERC20 instance
        // It should set the owner of the new XERC20 instance to the factory
        // It should emit a {DeployXERC20WithLockbox} event
        bytes32 lockboxSalt = keccak256(
            abi.encodePacked(
                uint256(uint160(address(xFactory))),
                CreateXLibrary.calculateSalt({_entropy: LOCKBOX_ENTROPY, _deployer: address(xFactory)})
            )
        );
        address expectedLockboxAddress = cx.computeCreate3Address({salt: lockboxSalt, deployer: address(cx)});

        bytes32 guardedSalt = keccak256(
            abi.encodePacked(
                uint256(uint160(address(xFactory))),
                CreateXLibrary.calculateSalt({_entropy: XERC20_ENTROPY, _deployer: address(xFactory)})
            )
        );
        address expectedTokenAddress = cx.computeCreate3Address({salt: guardedSalt, deployer: address(cx)});

        vm.expectEmit(address(xFactory));
        emit IXERC20Factory.DeployXERC20WithLockbox({_xerc20: expectedTokenAddress, _lockbox: expectedLockboxAddress});
        (address xerc20, address lockbox) = xFactory.deployXERC20WithLockbox({_erc20: address(rewardToken)});

        assertEq(xerc20, expectedTokenAddress);
        assertEq(IERC20Metadata(xerc20).name(), "Superchain Velodrome");
        assertEq(IERC20Metadata(xerc20).symbol(), "XVELO");
        assertEq(Ownable(xerc20).owner(), users.owner);
        assertEq(XERC20(xerc20).lockbox(), address(lockbox));

        assertEq(lockbox, expectedLockboxAddress);
        assertEq(address(XERC20Lockbox(lockbox).XERC20()), address(expectedTokenAddress));
        assertEq(address(XERC20Lockbox(lockbox).ERC20()), address(rewardToken));
    }

    function testGas_deployXERC20WithLockbox() external givenXERC20NotYetDeployed {
        xFactory.deployXERC20WithLockbox({_erc20: address(rewardToken)});
        snapLastCall("XERC20Factory_deployXERC20WithLockbox");
    }
}
