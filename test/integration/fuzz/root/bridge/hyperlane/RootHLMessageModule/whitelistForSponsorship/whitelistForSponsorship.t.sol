// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract WhitelistForSponsorshipIntegrationFuzzTest is RootHLMessageModuleTest {
    function testFuzz_WhenTheCallerIsNotWhitelistManager(address _caller) external {
        // It should revert with {NotBridgeOwner}
        vm.assume(_caller != rootMessageBridge.owner());

        vm.prank(_caller);
        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.whitelistForSponsorship({_account: _caller, _state: true});
    }

    modifier whenTheCallerIsWhitelistManager() {
        vm.startPrank(rootMessageBridge.owner());
        _;
    }

    modifier whenTheAccountIsNotTheAddressZero(address _account) {
        vm.assume(_account != address(0));
        _;
    }

    function testFuzz_WhenStateIsTrue(address _account)
        external
        whenTheCallerIsWhitelistManager
        whenTheAccountIsNotTheAddressZero(_account)
    {
        // It should whitelist the account
        // It should emit a {WhitelistSet} event
        assertFalse(rootMessageModule.isWhitelisted({_account: _account}));

        vm.expectEmit(address(rootMessageModule));
        emit IPaymaster.WhitelistSet({_account: _account, _state: true});
        rootMessageModule.whitelistForSponsorship({_account: _account, _state: true});

        assertTrue(rootMessageModule.isWhitelisted({_account: _account}));
        assertEq(rootMessageModule.whitelistLength(), 1);
        address[] memory whitelist = rootMessageModule.whitelist();
        assertEq(whitelist[0], _account);
        assertEq(whitelist.length, 1);
    }

    function testFuzz_WhenStateIsFalse(address _account)
        external
        whenTheCallerIsWhitelistManager
        whenTheAccountIsNotTheAddressZero(_account)
    {
        // It should unwhitelist the account
        // It should emit a {WhitelistSet} event

        rootMessageModule.whitelistForSponsorship({_account: _account, _state: true});

        assertTrue(rootMessageModule.isWhitelisted({_account: _account}));

        vm.expectEmit(address(rootMessageModule));
        emit IPaymaster.WhitelistSet({_account: _account, _state: false});
        rootMessageModule.whitelistForSponsorship({_account: _account, _state: false});

        assertFalse(rootMessageModule.isWhitelisted({_account: _account}));
        assertEq(rootMessageModule.whitelistLength(), 0);
        address[] memory whitelist = rootMessageModule.whitelist();
        assertEq(whitelist.length, 0);
    }
}
