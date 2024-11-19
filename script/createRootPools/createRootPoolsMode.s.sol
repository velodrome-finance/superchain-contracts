// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CreateRootPoolsBase.s.sol";

contract CreateRootPoolsMode is CreateRootPoolsBase {
    function setUp() public override {
        chainid = 34443;
    }

    function setUpV2Pools() internal pure override returns (PoolV2[] memory poolsV2) {
        poolsV2 = new PoolV2[](6);

        // sAMM-iUSD/USDC .05% Fee
        poolsV2[0] = PoolV2({
            tokenA: 0xA70266C8F8Cf33647dcFEE763961aFf418D9E1E4, //iUSD
            tokenB: 0xd988097fb8612cc24eeC14542bC03424c656005f, //USDC
            stable: true
        });

        // vAMM-BMX/wMLT 1% Fee
        poolsV2[1] = PoolV2({
            tokenA: 0x66eEd5FF1701E6ed8470DC391F05e27B1d0657eb, //bmx
            tokenB: 0x8b2EeA0999876AAB1E7955fe01A5D261b570452C, //wMLT
            stable: false
        });

        // vAMM-wMLT/USDC .3% Fee
        poolsV2[2] = PoolV2({
            tokenA: 0x8b2EeA0999876AAB1E7955fe01A5D261b570452C, //wMLT
            tokenB: 0xd988097fb8612cc24eeC14542bC03424c656005f, //usdc
            stable: false
        });

        // vAMM-WETH/MODE .3% Fee
        poolsV2[3] = PoolV2({
            tokenA: 0x4200000000000000000000000000000000000006, //weth
            tokenB: 0xDfc7C877a950e49D2610114102175A06C2e3167a, //mode
            stable: false
        });

        // vAMM-USDC/MODE .3% Fee
        poolsV2[4] = PoolV2({
            tokenA: 0xd988097fb8612cc24eeC14542bC03424c656005f, //usdc
            tokenB: 0xDfc7C877a950e49D2610114102175A06C2e3167a, //mode
            stable: false
        });

        // vAMM-WETH/USDC .3% fee
        poolsV2[5] = PoolV2({
            tokenA: 0x4200000000000000000000000000000000000006, //weth
            tokenB: 0xd988097fb8612cc24eeC14542bC03424c656005f, //usdc
            stable: false
        });
    }

    function setUpCLPools() internal pure override returns (PoolCL[] memory poolsCL) {
        poolsCL = new PoolCL[](5);
        // clAMM1-USDC/USDT .01% Fee
        poolsCL[0] = PoolCL({
            tokenA: 0xd988097fb8612cc24eeC14542bC03424c656005f, //usdc
            tokenB: 0xf0F161fDA2712DB8b566946122a5af183995e2eD, //usdt
            tickSpacing: 1
        });

        // clAMM1-weETH.mode/WETH .01% fee
        poolsCL[1] = PoolCL({
            tokenA: 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A, //weETH.mode
            tokenB: 0x4200000000000000000000000000000000000006, //weth
            tickSpacing: 1
        });

        // clAMM1-ezETH/WETH .01% fee
        poolsCL[2] = PoolCL({
            tokenA: 0x2416092f143378750bb29b79eD961ab195CcEea5, //ezETH
            tokenB: 0x4200000000000000000000000000000000000006, //weth
            tickSpacing: 1
        });

        // clAMM100-WETH/USDC .05% Fee
        poolsCL[3] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //weth
            tokenB: 0xd988097fb8612cc24eeC14542bC03424c656005f, //usdc
            tickSpacing: 100
        });

        // clAMM200-WETH/XVELO 1% fee
        poolsCL[4] = PoolCL({
            tokenA: 0x4200000000000000000000000000000000000006, //weth
            tokenB: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81, //xvelo
            tickSpacing: 200
        });
    }
}
