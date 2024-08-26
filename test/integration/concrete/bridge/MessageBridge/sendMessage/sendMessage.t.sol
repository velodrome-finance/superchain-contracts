// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../MessageBridge.t.sol";

contract SendMessageIntegrationConcreteTest is MessageBridgeTest {
    modifier whenTheCommandIsCreateGauge() {
        _;
    }

    function test_WhenTheCallerIsNotRootGaugeFactory() external whenTheCommandIsCreateGauge {
        // It should revert with NotAuthorized
        uint256 ethAmount = TOKEN_1;
        vm.deal({account: users.charlie, newBalance: ethAmount});

        bytes memory payload = abi.encode(address(token0), address(token1), true);
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, payload);

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IMessageBridge.NotAuthorized.selector, Commands.CREATE_GAUGE));
        rootMessageBridge.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    function test_WhenTheCallerIsRootGaugeFactory() external whenTheCommandIsCreateGauge {
        // It dispatches the create gauge message to the message module
        uint256 ethAmount = TOKEN_1;
        vm.deal({account: address(rootGaugeFactory), newBalance: ethAmount});

        bytes memory payload = abi.encode(address(token0), address(token1), true);
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, payload);

        vm.prank(address(rootGaugeFactory));
        rootMessageBridge.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        address pool = Clones.predictDeterministicAddress({
            deployer: address(leafPoolFactory),
            implementation: leafPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        });

        leafGauge = LeafGauge(leafVoter.gauges(pool));
        assertEq(leafGauge.stakingToken(), pool);
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafBridge));
        assertEq(leafGauge.gaugeFactory(), address(leafGaugeFactory));
    }

    function test_WhenTheCommandIsNotCreateGauge() external {
        // It dispatches the message to the message module
        uint256 ethAmount = TOKEN_1;
        vm.deal({account: users.alice, newBalance: ethAmount});

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        vm.prank(users.alice);
        rootMessageBridge.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        assertEq(address(rootMessageModule).balance, 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }
}
