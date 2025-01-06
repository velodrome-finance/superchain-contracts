// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CreateRootPoolsBase.s.sol";

contract CreateRootPoolsMetal is CreateRootPoolsBase {
    address public constant MTL = 0xBCFc435d8F276585f6431Fc1b9EE9A850B5C00A9;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0xb91CFCcA485C6E40E3bC622f9BFA02a8ACdEeBab;
    address public constant xVELO = 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81;

    function setUp() public override {
        chainid = 1750;
    }

    function setUpV2Pools() internal pure override returns (PoolV2[] memory poolsV2) {
        poolsV2 = new PoolV2[](2);

        // WETH<>USDC -> v2 volatile
        poolsV2[0] = PoolV2({tokenA: WETH, tokenB: USDC, stable: false});

        // MTL<>USDC -> v2 volatile
        poolsV2[1] = PoolV2({tokenA: MTL, tokenB: USDC, stable: false});
    }

    function setUpCLPools() internal pure override returns (PoolCL[] memory poolsCL) {
        poolsCL = new PoolCL[](2);

        // MTL<>WETH -> CL200
        poolsCL[0] = PoolCL({
            tokenA: MTL, //mtl
            tokenB: WETH, //weth
            tickSpacing: 200
        });

        // xVELO<>WETH -> CL200
        poolsCL[1] = PoolCL({
            tokenA: xVELO, //xvelo
            tokenB: WETH, //weth
            tickSpacing: 200
        });
    }
}
