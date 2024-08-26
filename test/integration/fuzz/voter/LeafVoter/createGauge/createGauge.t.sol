// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract CreateGaugeIntegrationFuzzTest is LeafVoterTest {
    function setUp() public override {
        super.setUp();

        // we use stable = true to avoid collision with existing pool
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function testFuzz_WhenCallerIsNotBridgeModule(address _caller) external {
        // It should revert with NotAuthorized
        vm.assume(_caller != address(leafMessageModule));
        vm.prank(_caller);
        vm.expectRevert(ILeafVoter.NotAuthorized.selector);
        leafGauge = LeafGauge(leafVoter.createGauge({_poolFactory: address(leafPoolFactory), _pool: address(leafPool)}));
    }
}
