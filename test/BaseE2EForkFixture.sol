// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";
import {IRouterV2} from "src/interfaces/external/IRouterV2.sol";

abstract contract BaseE2EForkFixture is BaseForkFixture {
    string public addresses;
    IRouterV2 public v2Router;
    IPoolFactory public v2Factory;

    uint256 public aliceLock;
    uint256 public bobLock;

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
        rootIncentiveToken = new TestERC20("Incentive Token", "INCNT", 18);
        vm.stopPrank();

        rootRewardToken = IERC20(vm.parseJsonAddress(addresses, ".Velo"));
        mockFactoryRegistry = IFactoryRegistry(vm.parseJsonAddress(addresses, ".FactoryRegistry"));
        mockEscrow = IVotingEscrow(vm.parseJsonAddress(addresses, ".VotingEscrow"));
        v2Factory = IPoolFactory(vm.parseJsonAddress(addresses, ".PoolFactory"));
        mockVoter = IVoter(vm.parseJsonAddress(addresses, ".Voter"));
    }

    /// @dev Helper function to seed User with WETH to pay for gas in x-chain transactions
    function _depositGas(address _user, uint256 _amount) internal {
        deal({token: address(weth), to: _user, give: _amount});
        vm.prank(_user);
        weth.approve({spender: address(rootMessageBridge), value: _amount});
    }

    function checkVotingRewards(
        uint256 _tokenId,
        address _tokenA,
        address _tokenB,
        uint256 _expectedBalanceA,
        uint256 _expectedBalanceB
    ) internal {
        vm.selectFork({forkId: rootId});
        // skip distribute window
        vm.warp({newTimestamp: VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1});
        uint256 rootTimestamp = block.timestamp;

        address owner = mockEscrow.ownerOf(_tokenId);
        address[] memory tokens = new address[](2);
        tokens[0] = _tokenA;
        tokens[1] = _tokenB;
        _depositGas({_user: owner, _amount: MESSAGE_FEE * 2});
        vm.startPrank({msgSender: owner, txOrigin: owner});
        rootIVR.getReward(_tokenId, tokens);
        rootFVR.getReward(_tokenId, tokens);
        vm.stopPrank();

        // process both claims on leaf chain
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: rootTimestamp});
        leafMailbox.processNextInboundMessage();
        leafMailbox.processNextInboundMessage();

        // fees and incentives are lagged by 1 week
        assertApproxEqAbs(IERC20(_tokenA).balanceOf(owner), _expectedBalanceA, 1e6);
        assertApproxEqAbs(IERC20(_tokenB).balanceOf(owner), _expectedBalanceB, 1e6);
    }
}
