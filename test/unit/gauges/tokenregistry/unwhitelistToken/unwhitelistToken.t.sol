// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../TokenRegistry.t.sol";

contract UnwhitelistTokenTest is TokenRegistryTest {
    function test_WhenCallerIsNotAdmin() external {
        // It should revert with NotAdmin
        vm.prank(users.alice);
        vm.expectRevert(ITokenRegistry.NotAdmin.selector);
        tokenRegistry.whitelistToken({_token: address(rewardToken), _state: false});
    }

    modifier whenCallerIsAdmin() {
        vm.startPrank(tokenRegistry.admin());
        _;
    }

    function test_WhenTokenToWhitelistIsTheZeroAddress() external whenCallerIsAdmin {
        // It should revert with ZeroAddress
        vm.expectRevert(ITokenRegistry.ZeroAddress.selector);
        tokenRegistry.whitelistToken({_token: address(0), _state: false});
    }

    function test_WhenTokenToWhitelistIsNotTheZeroAddress() external whenCallerIsAdmin {
        // It should set the token's whitelist state to false
        // It should emit a {WhitelistToken} event
        assertFalse(tokenRegistry.isWhitelistedToken(address(rewardToken)));

        tokenRegistry.whitelistToken({_token: address(rewardToken), _state: true});

        assertTrue(tokenRegistry.isWhitelistedToken(address(rewardToken)));

        vm.expectEmit(true, true, true, true, address(tokenRegistry));
        emit ITokenRegistry.WhitelistToken({
            whitelister: tokenRegistry.admin(),
            token: address(rewardToken),
            state: false
        });
        tokenRegistry.whitelistToken({_token: address(rewardToken), _state: false});

        assertFalse(tokenRegistry.isWhitelistedToken(address(rewardToken)));
    }
}
