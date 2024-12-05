// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../CreateRootPoolsBase.s.sol";

contract CreateRootPoolsFraxtal is CreateRootPoolsBase {
    address public constant FRAX = 0xFc00000000000000000000000000000000000001;
    address public constant wfrxETH = 0xFC00000000000000000000000000000000000006;
    address public constant sfrxETH = 0xFC00000000000000000000000000000000000005;
    address public constant FXS = 0xFc00000000000000000000000000000000000002;
    address public constant FXB2025 = 0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA;
    address public constant FXB2026 = 0x8e9C334afc76106F08E0383907F4Fca9bB10BA3e;
    address public constant FXB2029 = 0xF1e2b576aF4C6a7eE966b14C810b772391e92153;
    address public constant FXB2055 = 0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83;
    address public constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address public constant sUSDe = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2;
    address public constant USDC = 0xDcc0F2D8F90FDe85b10aC1c8Ab57dc0AE946A543;
    address public constant wstETH = 0x748e54072189Ec8540cD58A078404ebFDc2aACeA;
    address public constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address public constant VELO = 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81;
    address public constant BAL = 0x2FC7447F6cF71f9aa9E7FF8814B37E55b268Ec91;
    address public constant AURA = 0x1509706a6c66CA549ff0cB464de88231DDBe213B;
    address public constant CVX = 0x3a562a8CEB9866BcF39bB5EdA32F282d619e08E0;
    address public constant CRV = 0x331B9182088e2A7d6D3Fe4742AbA1fB231aEcc56;

    function setUp() public override {
        chainid = 252;
    }

    function setUpV2Pools() internal pure override returns (PoolV2[] memory poolsV2) {
        poolsV2 = new PoolV2[](4);
        // 100% = 10_000
        // Default Stable Fee: 5
        // Default Volatile Fee: 30

        // sAMM FRAX-USDC 1 -- Needs custom fee set to 1
        poolsV2[0] = PoolV2({tokenA: FRAX, tokenB: USDC, stable: true});
        // sAMM FRAX-USDe 5
        poolsV2[1] = PoolV2({tokenA: FRAX, tokenB: USDe, stable: true});
        // vAMM wfrxETH-AURA 100 -- Needs custom fee set to 100
        poolsV2[2] = PoolV2({tokenA: wfrxETH, tokenB: AURA, stable: false});
        // vAMM wfrxETH-CRV 100 -- Needs custom fee set to 100
        poolsV2[3] = PoolV2({tokenA: wfrxETH, tokenB: CRV, stable: false});
        // // vAMM wfrxETH-BAL 100 -- Needs custom fee set to 100
        // poolsV2[4] = PoolV2({tokenA: wfrxETH, tokenB: BAL, stable: false});
        // // vAMM wfrxETH-CVX 100 -- Needs custom fee set to 100
        // poolsV2[5] = PoolV2({tokenA: wfrxETH, tokenB: CVX, stable: false});
    }

    function setUpCLPools() internal pure override returns (PoolCL[] memory poolsCL) {
        poolsCL = new PoolCL[](10);
        // 100% = 1_000_000
        // TickSpacing 1 => Fee: 100
        // TickSpacing 50 => Fee: 500
        // TickSpacing 100 => Fee: 500
        // TickSpacing 200 => Fee: 3_000
        // TickSpacing 2000 => Fee: 10_000

        // CL1 sfrxETH-wstETH 5 -- Need to set custom fee to 500
        poolsCL[0] = PoolCL({tokenA: sfrxETH, tokenB: wstETH, tickSpacing: 1});
        // CL1 sfrxETH-ezETH 5 -- Need to set custom fee to 500
        poolsCL[1] = PoolCL({tokenA: sfrxETH, tokenB: ezETH, tickSpacing: 1});
        // CL50 FRAX-sUSDe 15 -- Need to set custom fee to 1500
        poolsCL[2] = PoolCL({tokenA: FRAX, tokenB: sUSDe, tickSpacing: 50});
        // CL50 FRAX-FXB2025 15 -- Need to set custom fee to 1500
        poolsCL[3] = PoolCL({tokenA: FRAX, tokenB: FXB2025, tickSpacing: 50});
        // CL50 FRAX-FXB2026 15 -- Need to set custom fee to 1500
        poolsCL[4] = PoolCL({tokenA: FRAX, tokenB: FXB2026, tickSpacing: 50});
        // CL50 FRAX-FXB2029 15 -- Need to set custom fee to 1500
        poolsCL[5] = PoolCL({tokenA: FRAX, tokenB: FXB2029, tickSpacing: 50});
        // CL50 FRAX-FXB2055 15 -- Need to set custom fee to 1500
        poolsCL[6] = PoolCL({tokenA: FRAX, tokenB: FXB2055, tickSpacing: 50});
        // CL100 FRAX-wfrxETH 5
        poolsCL[7] = PoolCL({tokenA: FRAX, tokenB: wfrxETH, tickSpacing: 100});
        // CL200 wfrxETH-FXS 30
        poolsCL[8] = PoolCL({tokenA: wfrxETH, tokenB: FXS, tickSpacing: 200});
        // CL200 wfrxETH-VELO 100 -- Need to set custom fee to 10_000
        poolsCL[9] = PoolCL({tokenA: wfrxETH, tokenB: VELO, tickSpacing: 200});
        // // CL200 FRAX-PEPE 30
        // poolsCL[10] = PoolCL({tokenA: FRAX, tokenB: PEPE, tickSpacing: 200});
        // // CL200 FRAX-WIF 30
        // poolsCL[11] = PoolCL({tokenA: FRAX, tokenB: WIF, tickSpacing: 200});
    }
}
