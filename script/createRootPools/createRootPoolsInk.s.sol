// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CreateRootPoolsBase.s.sol";

contract CreateRootPoolsInk is CreateRootPoolsBase {
    function setUp() public override {
        chainid = 57073;
    }

    function setUpV2Pools() internal pure override returns (PoolV2[] memory poolsV2) {
        poolsV2 = new PoolV2[](0);
    }

    function setUpCLPools() internal pure override returns (PoolCL[] memory poolsCL) {
        poolsCL = new PoolCL[](2);

        // clAMM100-WETH/USDC 5bps
        poolsCL[0] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //WETH
            tokenB: 0xF1815bd50389c46847f0Bda824eC8da914045D14, //USDC.e
            tickSpacing: 100
        });

        // clAMM200-WETH/XVELO 100bps
        poolsCL[1] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //WETH
            tokenB: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81, //XVELO
            tickSpacing: 200
        });
    }
}
