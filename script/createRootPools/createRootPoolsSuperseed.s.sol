// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CreateRootPoolsBase.s.sol";

contract CreateRootPoolsSuperseed is CreateRootPoolsBase {
    function setUp() public override {
        chainid = 5330;
    }

    function setUpV2Pools() internal pure override returns (PoolV2[] memory poolsV2) {
        poolsV2 = new PoolV2[](0);
    }

    function setUpCLPools() internal pure override returns (PoolCL[] memory poolsCL) {
        poolsCL = new PoolCL[](6);

        // WETH-USDC (CL100 0.05%)
        poolsCL[0] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //weth
            tokenB: 0xC316C8252B5F2176d0135Ebb0999E99296998F2e, //usdc
            tickSpacing: 100
        });

        // WETH-USDT (CL100 0.05%)
        poolsCL[1] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //weth
            tokenB: 0xc5068BB6803ADbe5600DE5189fe27A4dAcE31170, //usdt
            tickSpacing: 100
        });

        // cbBTC-USDC (CL100 0.05%)
        poolsCL[2] = PoolCL({
            tokenA: 0x6f36DBD829DE9b7e077DB8A35b480d4329ceB331, //cbBTC
            tokenB: 0xC316C8252B5F2176d0135Ebb0999E99296998F2e, //usdc
            tickSpacing: 100
        });

        // WETH-cbBTC (CL100 0.05%)
        poolsCL[3] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //weth
            tokenB: 0x6f36DBD829DE9b7e077DB8A35b480d4329ceB331, //cbBTC
            tickSpacing: 100
        });

        // USDC-USDT (CL1 0.01%)
        poolsCL[4] = PoolCL({
            tokenA: 0xC316C8252B5F2176d0135Ebb0999E99296998F2e, //usdc
            tokenB: 0xc5068BB6803ADbe5600DE5189fe27A4dAcE31170, //usdt
            tickSpacing: 1
        });

        // xVELO-WETH (CL200 1%)
        poolsCL[5] = PoolCL({
            tokenA: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81, //xVELO
            tokenB: 0x4200000000000000000000000000000000000006, //weth
            tickSpacing: 200
        });
    }
}
