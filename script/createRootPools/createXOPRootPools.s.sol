// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CreateXOPRootPoolsBase.s.sol";

contract CreateXOPRootPools is CreateXOPRootPoolsBase {
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant WETH_CELO = 0xD221812de1BD094f35587EE8E174B07B6167D9Af;
    address public constant WETH_FRAXTAL = 0xFC00000000000000000000000000000000000006;
    address public constant xOP = 0xafcc6AE807187A31E84138F3860D4CE27973e01b;

    function setUpV2Pools() internal pure override returns (PoolV2[] memory poolsV2) {
        poolsV2 = new PoolV2[](10);

        // Fraxtal WETH<>xOP -> v2 volatile
        poolsV2[0] = PoolV2({chainid: 252, tokenA: WETH_FRAXTAL, tokenB: xOP, stable: false});

        // Ink WETH<>xOP -> v2 volatile
        poolsV2[1] = PoolV2({chainid: 57073, tokenA: WETH, tokenB: xOP, stable: false});

        // Lisk WETH<>xOP -> v2 volatile
        poolsV2[2] = PoolV2({chainid: 1135, tokenA: WETH, tokenB: xOP, stable: false});

        // Mode WETH<>xOP -> v2 volatile
        poolsV2[3] = PoolV2({chainid: 34443, tokenA: WETH, tokenB: xOP, stable: false});

        // Soneium WETH<>xOP -> v2 volatile
        poolsV2[4] = PoolV2({chainid: 1868, tokenA: WETH, tokenB: xOP, stable: false});

        // Superseed WETH<>xOP -> v2 volatile
        poolsV2[5] = PoolV2({chainid: 5330, tokenA: WETH, tokenB: xOP, stable: false});

        // Swell WETH<>xOP -> v2 volatile
        poolsV2[6] = PoolV2({chainid: 1923, tokenA: WETH, tokenB: xOP, stable: false});

        // Unichain WETH<>xOP -> v2 volatile
        poolsV2[7] = PoolV2({chainid: 130, tokenA: WETH, tokenB: xOP, stable: false});

        // Metal WETH<>xOP -> v2 volatile
        poolsV2[8] = PoolV2({chainid: 1750, tokenA: WETH, tokenB: xOP, stable: false});

        // Celo WETH<>xOP -> v2 volatile
        poolsV2[9] = PoolV2({chainid: 42220, tokenA: WETH_CELO, tokenB: xOP, stable: false});
    }
}
