// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RestrictedXERC20.t.sol";

contract TransferIntegrationConcreteTest is RestrictedXERC20Test {
    function test_WhenTransferOccursOnTheOriginChain() external {
        // It should allow transfer without restrictions
        uint256 _amount = TOKEN_1;
        vm.chainId({newChainId: root});
        deal({token: address(rootRestrictedRewardToken), to: users.alice, give: _amount});

        vm.prank({msgSender: users.alice});
        rootRestrictedRewardToken.transfer({to: users.bob, value: _amount});

        assertEq(rootRestrictedRewardToken.balanceOf(users.bob), _amount);
    }

    modifier whenTransferOccursOnNon_originChains() {
        vm.chainId({newChainId: 1});
        _;
    }

    function test_WhenTheSenderIsTheTokenBridge() external whenTransferOccursOnNon_originChains {
        // It should whitelist the destination address
        // It should allow the transfer
        uint256 _amount = TOKEN_1;
        address _recipient = users.bob;
        deal({token: address(leafRestrictedRewardToken), to: address(leafRestrictedTokenBridge), give: _amount});

        vm.startPrank({msgSender: address(leafRestrictedTokenBridge)});
        leafRestrictedRewardToken.transfer({to: _recipient, value: _amount});

        assertEq(leafRestrictedRewardToken.balanceOf(_recipient), _amount);
        address[] memory _whitelistedAddresses = leafRestrictedRewardToken.whitelist();
        assertEq(_whitelistedAddresses[1], _recipient);
    }

    function test_WhenTheSenderIsAlreadyWhitelisted() external whenTransferOccursOnNon_originChains {
        // It should allow the transfer
        uint256 _amount = TOKEN_1;
        address _sender = users.alice;
        deal({token: address(leafRestrictedRewardToken), to: address(leafRestrictedTokenBridge), give: _amount});

        vm.prank({msgSender: address(leafRestrictedTokenBridge)});
        leafRestrictedRewardToken.transfer({to: _sender, value: _amount});

        assertEq(leafRestrictedRewardToken.balanceOf(_sender), _amount);
        address[] memory _whitelistedAddresses = leafRestrictedRewardToken.whitelist();
        assertEq(_whitelistedAddresses[1], _sender);

        vm.prank({msgSender: _sender});
        leafRestrictedRewardToken.transfer({to: users.bob, value: _amount});

        assertEq(leafRestrictedRewardToken.balanceOf(users.bob), _amount);
    }

    function test_WhenTheSenderIsNotWhitelisted() external whenTransferOccursOnNon_originChains {
        // It should revert with {NotWhitelisted}
        uint256 _amount = TOKEN_1;
        address _sender = users.charlie;
        deal({token: address(leafRestrictedRewardToken), to: _sender, give: _amount});

        vm.prank({msgSender: _sender});
        vm.expectRevert(IRestrictedXERC20.NotWhitelisted.selector);
        leafRestrictedRewardToken.transfer({to: users.bob, value: _amount});
    }

    function testGas_transfer() external {
        // Setup a basic transfer from token bridge on non-origin chain
        uint256 _amount = TOKEN_1;
        vm.chainId({newChainId: 1}); // non-origin chain
        deal({token: address(leafRestrictedRewardToken), to: address(leafRestrictedTokenBridge), give: _amount});

        vm.prank({msgSender: address(leafRestrictedTokenBridge)});
        leafRestrictedRewardToken.transfer({to: users.bob, value: _amount});
        vm.snapshotGasLastCall("RestrictedXERC20_transfer");
    }
}
