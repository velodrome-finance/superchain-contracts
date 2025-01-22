// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetDomainIntegrationConcreteTest is RootHLMessageModuleTest {
    uint256 public chainid;
    uint32 public domain;
    uint32 public oldDomain;

    function test_WhenTheCallerIsNotBridgeOwner() external {
        // It should revert with {NotBridgeOwner}
        vm.prank(users.charlie);
        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.setDomain({_chainid: chainid, _domain: domain});
    }

    modifier whenTheCallerIsBridgeOwner() {
        vm.startPrank(rootMessageBridge.owner());
        _;
    }

    function test_WhenChainidIsZero() external whenTheCallerIsBridgeOwner {
        // It should revert with {InvalidChainID}
        vm.expectRevert(IRootHLMessageModule.InvalidChainID.selector);
        rootMessageModule.setDomain({_chainid: chainid, _domain: domain});
    }

    modifier whenChainidIsGreaterThanZero() {
        chainid = 1;

        // Preassign an old domain, to ensure it is removed
        oldDomain = 1337;
        rootMessageModule.setDomain({_chainid: chainid, _domain: oldDomain});
        assertEq(rootMessageModule.domains(chainid), oldDomain);
        assertEq(rootMessageModule.chains(oldDomain), chainid);
        _;
    }

    function test_WhenDomainIsAlreadyAssignedToAChainid()
        external
        whenTheCallerIsBridgeOwner
        whenChainidIsGreaterThanZero
    {
        // It should revert with {DomainAlreadyAssigned}
        domain = leafDomain;
        vm.expectRevert(IRootHLMessageModule.DomainAlreadyAssigned.selector);
        rootMessageModule.setDomain({_chainid: chainid, _domain: domain});
    }

    modifier whenDomainIsNotAssignedToAChainid() {
        _;
    }

    function test_WhenDomainIsZero()
        external
        whenTheCallerIsBridgeOwner
        whenChainidIsGreaterThanZero
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

    function test_WhenDomainIsGreaterThanZero()
        external
        whenTheCallerIsBridgeOwner
        whenChainidIsGreaterThanZero
        whenDomainIsNotAssignedToAChainid
    {
        // It should remove the old chainid associated with the previous domain of chainid
        // It should set a new domain for chainid
        // It should set a new chainid for domain
        // It emits a {DomainSet} event
        domain = 1001;
        vm.expectEmit(address(rootMessageModule));
        emit IRootHLMessageModule.DomainSet({_chainid: chainid, _domain: domain});
        rootMessageModule.setDomain({_chainid: chainid, _domain: domain});
        assertEq(rootMessageModule.domains(chainid), domain);
        assertEq(rootMessageModule.chains(domain), chainid);
        assertEq(rootMessageModule.chains(oldDomain), 0);
    }

    function testGas_setDomain()
        external
        whenTheCallerIsBridgeOwner
        whenChainidIsGreaterThanZero
        whenDomainIsNotAssignedToAChainid
    {
        domain = 1001;
        rootMessageModule.setDomain({_chainid: chainid, _domain: domain});
        vm.snapshotGasLastCall("RootHLMessageModule_setDomain");
    }
}
