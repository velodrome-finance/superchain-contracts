// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";
import {IRouterV2} from "src/interfaces/external/IRouterV2.sol";

abstract contract BaseE2EForkFixture is BaseForkFixture {
    string public addresses;
    IRouterV2 public v2Router;
    IPoolFactory public v2Factory;

    function setUp() public virtual override {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/test/e2e/addresses.json"));
        addresses = vm.readFile(path);

        super.setUp();

        v2Router = IRouterV2(payable(vm.parseJsonAddress(addresses, ".Router")));
        weth = IWETH(vm.parseJsonAddress(addresses, ".WETH"));
    }

    function deployRootDependencies() public virtual override {
        // set up root v2 dependencies
        vm.startPrank(users.owner);
        rootMailbox = new MultichainMockMailbox(rootDomain);
        rootIsm = new TestIsm();
        vm.stopPrank();

        rootRewardToken = IERC20(vm.parseJsonAddress(addresses, ".Velo"));
        mockFactoryRegistry = IFactoryRegistry(vm.parseJsonAddress(addresses, ".FactoryRegistry"));
        mockEscrow = IVotingEscrow(vm.parseJsonAddress(addresses, ".VotingEscrow"));
        v2Factory = IPoolFactory(vm.parseJsonAddress(addresses, ".PoolFactory"));
        mockVoter = IVoter(vm.parseJsonAddress(addresses, ".Voter"));
    }
}
