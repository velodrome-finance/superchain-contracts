// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract LeafVoterTest is BaseForkFixture {
    LeafGauge public incentiveGauge;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: leafId});
        address incentivePool = leafPoolFactory.getPool({tokenA: address(token0), tokenB: address(weth), stable: false});
        incentiveGauge = LeafGauge(leafVoter.gauges(incentivePool));
    }
}
