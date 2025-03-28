// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract WhitelistForSponsorshipIntegrationConcreteTest is RootHLMessageModuleTest {
    function test_WhenTheCallerIsNotWhitelistManager() external {
        // It should revert with {NotBridgeOwner}
        vm.prank(users.charlie);

        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.whitelistForSponsorship({_account: users.alice, _state: true});
    }

    modifier whenTheCallerIsWhitelistManager() {
        vm.startPrank(rootMessageBridge.owner());
        _;
    }

    function test_WhenTheAccountIsTheAddressZero() external whenTheCallerIsWhitelistManager {
        // It should revert with {InvalidAddress}
        vm.expectRevert(IPaymaster.InvalidAddress.selector);
        rootMessageModule.whitelistForSponsorship({_account: address(0), _state: true});
    }

    modifier whenTheAccountIsNotTheAddressZero() {
        _;
    }

    function test_WhenStateIsTrue() external whenTheCallerIsWhitelistManager whenTheAccountIsNotTheAddressZero {
        // It should whitelist the account
        // It should emit a {WhitelistSet} event
        assertFalse(rootMessageModule.isWhitelisted({_account: users.alice}));

        vm.expectEmit(address(rootMessageModule));
        emit IPaymaster.WhitelistSet({_account: users.alice, _state: true});
        rootMessageModule.whitelistForSponsorship({_account: users.alice, _state: true});

        assertTrue(rootMessageModule.isWhitelisted({_account: users.alice}));
        assertEq(rootMessageModule.whitelistLength(), 1);
        address[] memory whitelist = rootMessageModule.whitelist();
        assertEq(whitelist[0], users.alice);
        assertEq(whitelist.length, 1);
    }

    function test_WhenStateIsFalse() external whenTheCallerIsWhitelistManager whenTheAccountIsNotTheAddressZero {
        // It should unwhitelist the account
        // It should emit a {WhitelistSet} event

        rootMessageModule.whitelistForSponsorship({_account: users.alice, _state: true});

        assertTrue(rootMessageModule.isWhitelisted({_account: users.alice}));

        vm.expectEmit(address(rootMessageModule));
        emit IPaymaster.WhitelistSet({_account: users.alice, _state: false});
        rootMessageModule.whitelistForSponsorship({_account: users.alice, _state: false});

        assertFalse(rootMessageModule.isWhitelisted({_account: users.alice}));
        assertEq(rootMessageModule.whitelistLength(), 0);
        address[] memory whitelist = rootMessageModule.whitelist();
        assertEq(whitelist.length, 0);
    }
}
