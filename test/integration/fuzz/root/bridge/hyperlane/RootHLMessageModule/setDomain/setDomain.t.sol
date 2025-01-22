// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetDomainIntegrationFuzzTest is RootHLMessageModuleTest {
    uint256 public chainid;
    uint32 public domain;
    uint32 public oldDomain;

    function testFuzz_WhenTheCallerIsNotBridgeOwner(address _caller) external {
        // It should revert with {NotBridgeOwner}
        vm.assume(_caller != rootMessageBridge.owner());

        vm.prank(_caller);
        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.setDomain({_chainid: chainid, _domain: leafDomain});
    }

    modifier whenTheCallerIsBridgeOwner() {
        vm.startPrank(rootMessageBridge.owner());
        _;
    }

    modifier whenChainidIsGreaterThanZero(uint256 _chainid, uint32 _oldDomain) {
        vm.assume(_chainid != 0);
        vm.assume(_oldDomain != 0 && _oldDomain != leafDomain);
        chainid = _chainid;
        oldDomain = _oldDomain;

        // Preassign an old domain, to ensure it is removed
        rootMessageModule.setDomain({_chainid: chainid, _domain: oldDomain});
        assertEq(rootMessageModule.domains(chainid), oldDomain);
        assertEq(rootMessageModule.chains(oldDomain), chainid);
        _;
    }

    function testFuzz_WhenDomainIsAlreadyAssignedToAChainid(uint256 _chainid, uint256 _chainid2, uint32 _oldDomain)
        external
        whenTheCallerIsBridgeOwner
        whenChainidIsGreaterThanZero(_chainid, _oldDomain)
    {
        // It should revert with {DomainAlreadyAssigned}
        vm.assume(_chainid2 != 0);

        vm.expectRevert(IRootHLMessageModule.DomainAlreadyAssigned.selector);
        rootMessageModule.setDomain({_chainid: _chainid2, _domain: oldDomain});
    }

    modifier whenDomainIsNotAssignedToAChainid() {
        _;
    }

    function testFuzz_WhenDomainIsZero(uint256 _chainid, uint32 _oldDomain)
        external
        whenTheCallerIsBridgeOwner
        whenChainidIsGreaterThanZero(_chainid, _oldDomain)
        whenDomainIsNotAssignedToAChainid
    {
        // It should remove the old chainid associated with the previous domain of chainid
        // It should remove the domain for chainid
        // It emits a {DomainSet} event
        vm.expectEmit(address(rootMessageModule));
        emit IRootHLMessageModule.DomainSet({_chainid: chainid, _domain: 0});
        rootMessageModule.setDomain({_chainid: chainid, _domain: 0});
        assertEq(rootMessageModule.domains(chainid), 0);
        assertEq(rootMessageModule.chains(domain), 0);
        assertEq(rootMessageModule.chains(oldDomain), 0);
    }

    function testFuzz_WhenDomainIsGreaterThanZero(uint256 _chainid, uint32 _domain, uint32 _oldDomain)
        external
        whenTheCallerIsBridgeOwner
        whenChainidIsGreaterThanZero(_chainid, _oldDomain)
        whenDomainIsNotAssignedToAChainid
    {
        // It should remove the old chainid associated with the previous domain of chainid
        // It should set a new domain for chainid
        // It should set a new chainid for domain
        // It emits a {DomainSet} event
        vm.assume(_domain != 0 && _domain != oldDomain && _domain != leafDomain);

        vm.expectEmit(address(rootMessageModule));
        emit IRootHLMessageModule.DomainSet({_chainid: chainid, _domain: _domain});
        rootMessageModule.setDomain({_chainid: chainid, _domain: _domain});
        assertEq(rootMessageModule.domains(chainid), _domain);
        assertEq(rootMessageModule.chains(_domain), chainid);
        assertEq(rootMessageModule.chains(oldDomain), 0);
    }

    function testFuzz_SetMultipleDomains(
        uint256 _chainid,
        uint256 _chainid2,
        uint256 _chainid3,
        uint32 _domain,
        uint32 _domain2,
        uint32 _domain3
    ) external whenTheCallerIsBridgeOwner whenDomainIsNotAssignedToAChainid {
        vm.assume(_chainid != 0 && _chainid2 != 0 && _chainid3 != 0);

        bool success;
        uint32 prevDomain = rootMessageModule.domains(_chainid);
        try rootMessageModule.setDomain({_chainid: _chainid, _domain: _domain}) {
            _checkChainDomain({_chainid: _chainid, _domain: _domain});
            assertEq(rootMessageModule.chains(prevDomain), 0);
            success = true;
        } catch (bytes memory reason) {
            if (_domain == leafDomain) {
                assertEq(reason, abi.encodeWithSelector(IRootHLMessageModule.DomainAlreadyAssigned.selector));
            } else {
                revert();
            }
        }

        bool success2;
        prevDomain = rootMessageModule.domains(_chainid2);
        try rootMessageModule.setDomain({_chainid: _chainid2, _domain: _domain2}) {
            _checkChainDomain({_chainid: _chainid2, _domain: _domain2});
            assertEq(rootMessageModule.chains(prevDomain), 0);
            success2 = true;

            // @dev check previous domain if first call was successful and domain was not overwritten
            if (_chainid != _chainid2 && success) {
                _checkChainDomain({_chainid: _chainid, _domain: _domain});
            }
        } catch (bytes memory reason) {
            if (_domain2 == leafDomain || _domain2 == _domain) {
                assertEq(reason, abi.encodeWithSelector(IRootHLMessageModule.DomainAlreadyAssigned.selector));
            } else {
                revert();
            }
        }

        prevDomain = rootMessageModule.domains(_chainid3);
        try rootMessageModule.setDomain({_chainid: _chainid3, _domain: _domain3}) {
            _checkChainDomain({_chainid: _chainid3, _domain: _domain3});
            assertEq(rootMessageModule.chains(prevDomain), 0);

            // @dev check first domain if first call was successful and domain was not overwritten
            if ((_chainid != _chainid2 && success) && (_chainid != _chainid3 && success)) {
                _checkChainDomain({_chainid: _chainid, _domain: _domain});
            }
            // @dev check second domain if second call was successful and domain was not overwritten
            if (_chainid2 != _chainid3 && success2) {
                _checkChainDomain({_chainid: _chainid2, _domain: _domain2});
            }
        } catch (bytes memory reason) {
            if (_domain3 == leafDomain || _domain3 == _domain || _domain3 == _domain2) {
                assertEq(reason, abi.encodeWithSelector(IRootHLMessageModule.DomainAlreadyAssigned.selector));
            } else {
                revert();
            }
        }
    }

    /// @dev Helper function to assert domain & chainid mapping updates
    function _checkChainDomain(uint256 _chainid, uint32 _domain) internal view {
        assertEq(rootMessageModule.domains(_chainid), _domain);
        if (_domain != 0) {
            assertEq(rootMessageModule.chains(_domain), _chainid);
        }
    }
}
