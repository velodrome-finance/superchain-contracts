// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CreateRootPoolsBase.s.sol";

contract CreateRootPoolsLisk is CreateRootPoolsBase {
    function setUp() public override {
        chainid = 1135;
    }

    function setUpV2Pools() internal pure override returns (PoolV2[] memory poolsV2) {
        poolsV2 = new PoolV2[](3);

        // vAMM-LSK/WETH .3%
        poolsV2[0] = PoolV2({
            tokenA: 0xac485391EB2d7D88253a7F1eF18C37f4242D1A24, //LSK
            tokenB: 0x4200000000000000000000000000000000000006, //WETH
            stable: false
        });

        // vAMM-WETH/USDC .3%
        poolsV2[1] = PoolV2({
            tokenA: 0xF242275d3a6527d877f2c927a82D9b057609cc71, //USDC
            tokenB: 0x4200000000000000000000000000000000000006, //WETH
            stable: false
        });

        // sAMM-USDC/USDT .05%
        poolsV2[2] = PoolV2({
            tokenA: 0xF242275d3a6527d877f2c927a82D9b057609cc71, //USDC
            tokenB: 0x05D032ac25d322df992303dCa074EE7392C117b9, //USDT
            stable: true
        });
    }

    function setUpCLPools() internal pure override returns (PoolCL[] memory poolsCL) {
        poolsCL = new PoolCL[](1);
        // clAMM200-WETH/XVELO 1%
        poolsCL[0] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //WETH
            tokenB: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81, //XVELO
            tickSpacing: 200
        });
    }
}
