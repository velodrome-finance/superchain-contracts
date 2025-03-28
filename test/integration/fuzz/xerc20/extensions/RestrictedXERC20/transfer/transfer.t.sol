// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RestrictedXERC20.t.sol";

contract RestrictedXERC20IntegrationFuzzTest is RestrictedXERC20Test {
    function testFuzz_WhenTransferOccursOnTheOriginChain(uint256 _amount) external {
        // It should allow transfer without restrictions
        vm.assume(_amount <= MAX_TOKENS);
        deal({token: address(rootRestrictedRewardToken), to: users.alice, give: _amount});

        vm.prank({msgSender: users.alice});
        rootRestrictedRewardToken.transfer({to: users.bob, value: _amount});

        assertEq(rootRestrictedRewardToken.balanceOf(users.bob), _amount);
    }

    modifier whenTransferOccursOnNon_originChains(uint256 _chainId) {
        vm.assume(_chainId < type(uint64).max); // foundry restriction
        vm.assume(_chainId != root);
        vm.chainId({newChainId: _chainId});
        _;
    }

    function testFuzz_WhenTheSenderIsTheTokenBridge(uint256 _amount, uint256 _chainId, address _recipient)
        external
        whenTransferOccursOnNon_originChains(_chainId)
    {
        // It should whitelist the destination address
        // It should allow the transfer
        vm.assume(_recipient != address(leafRestrictedTokenBridge) && _recipient != address(0));
        vm.assume(_amount <= MAX_TOKENS);
        deal({token: address(leafRestrictedRewardToken), to: address(leafRestrictedTokenBridge), give: _amount});

        vm.startPrank({msgSender: address(leafRestrictedTokenBridge)});
        leafRestrictedRewardToken.transfer({to: _recipient, value: _amount});

        assertEq(leafRestrictedRewardToken.balanceOf(_recipient), _amount);
        address[] memory _whitelistedAddresses = leafRestrictedRewardToken.whitelist();
        assertEq(_whitelistedAddresses[1], _recipient);
    }

    function testFuzz_WhenTheSenderIsAlreadyWhitelisted(uint256 _amount, uint256 _chainId, address _sender)
        external
        whenTransferOccursOnNon_originChains(_chainId)
    {
        // It should allow the transfer
        vm.assume(_sender != address(leafRestrictedTokenBridge) && _sender != address(0));
        vm.assume(_amount <= MAX_TOKENS);
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

    function testFuzz_WhenTheSenderIsNotWhitelisted(uint256 _amount, uint256 _chainId, address _sender)
        external
        whenTransferOccursOnNon_originChains(_chainId)
    {
        // It should revert with {NotWhitelisted}
        vm.assume(_sender != address(leafRestrictedTokenBridge) && _sender != address(0));
        vm.assume(_amount <= MAX_TOKENS);
        deal({token: address(leafRestrictedRewardToken), to: _sender, give: _amount});

        vm.prank({msgSender: _sender});
        vm.expectRevert(IRestrictedXERC20.NotWhitelisted.selector);
        leafRestrictedRewardToken.transfer({to: users.bob, value: _amount});
    }
}
