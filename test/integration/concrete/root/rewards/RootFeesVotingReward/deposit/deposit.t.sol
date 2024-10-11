// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootFeesVotingReward.t.sol";

contract DepositIntegrationConcreteTest is RootFeesVotingRewardTest {
    function test_WhenCallerIsNotVoter() external {
        // It should revert with NotAuthorized
        vm.prank(users.charlie);
        vm.expectRevert(IRootFeesVotingReward.NotAuthorized.selector);
        rootFVR._deposit({_amount: 1, _tokenId: 1});
    }

    modifier whenCallerIsVoter() {
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});
        vm.startPrank({msgSender: address(mockVoter), txOrigin: users.alice});
        _;
    }

    modifier whenOwnerOfTokenIdIsAContract() {
        vm.mockCall(
            address(mockEscrow), abi.encodeWithSelector(IERC721.ownerOf.selector, 1), abi.encode(address(mockVoter))
        );
        _;
    }

    function test_WhenRecipientIsNotSetOnTheFactory() external whenCallerIsVoter whenOwnerOfTokenIdIsAContract {
        // It should revert with RecipientNotSet
        vm.expectRevert(IRootFeesVotingReward.RecipientNotSet.selector);
        rootFVR._deposit({_amount: 1, _tokenId: 1});
    }

    function test_WhenRecipientIsSetOnTheFactory() external whenCallerIsVoter whenOwnerOfTokenIdIsAContract {
        // It should encode the deposit amount and token id
        // It should forward the message to the corresponding rewards contract on the leaf chain
        // It should update the total supply on the leaf fee + incentive voting contracts
        // It should update the balance of the token id on the leaf fee + incentive voting contracts
        // It should emit a {Deposit} event

        rootVotingRewardsFactory.setRecipient({_chainid: leaf, _recipient: users.alice});

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;

        rootFVR._deposit({_amount: amount, _tokenId: tokenId});

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafFVR));
        emit IReward.Deposit({_amount: amount, _tokenId: tokenId});
        vm.expectEmit(address(leafIVR));
        emit IReward.Deposit({_amount: amount, _tokenId: tokenId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }

    function test_WhenOwnerOfTokenIdIsAnEOA() external whenCallerIsVoter {
        // It should encode the deposit amount and token id
        // It should forward the message to the corresponding rewards contract on the leaf chain
        // It should update the total supply on the leaf fee + incentive voting contracts
        // It should update the balance of the token id on the leaf fee + incentive voting contracts
        // It should emit a {Deposit} event
        uint256 tokenId = 1;
        uint256 amount = TOKEN_1 * 1000;
        vm.mockCall(
            address(mockEscrow),
            abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId),
            abi.encode(address(users.alice))
        );

        rootFVR._deposit({_amount: amount, _tokenId: tokenId});

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafFVR));
        emit IReward.Deposit({_amount: amount, _tokenId: tokenId});
        vm.expectEmit(address(leafIVR));
        emit IReward.Deposit({_amount: amount, _tokenId: tokenId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }

    function testGas_WhenRecipientIsSetOnTheFactory() external whenCallerIsVoter whenOwnerOfTokenIdIsAContract {
        rootVotingRewardsFactory.setRecipient({_chainid: leaf, _recipient: users.alice});

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;

        rootFVR._deposit({_amount: amount, _tokenId: tokenId});
        snapLastCall("RootFeesVotingReward_deposit");
    }
}
