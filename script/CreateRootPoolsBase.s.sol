// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import "src/root/pools/RootPoolFactory.sol";

interface IRootCLFactory {
    function createPool(uint256 chainid, address tokenA, address tokenB, int24 tickSpacing)
        external
        returns (address);
    function getPool(uint256 chainid, address tokenA, address tokenB, int24 tickSpacing)
        external
        view
        returns (address pool);
}

abstract contract CreateRootPoolsBase is Script {
    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployer = vm.addr(deployPrivateKey);

    struct PoolV2 {
        address tokenA;
        address tokenB;
        bool stable;
    }

    struct PoolCL {
        address tokenA;
        address tokenB;
        int24 tickSpacing;
    }

    RootPoolFactory factoryV2 = RootPoolFactory(0x31832f2a97Fd20664D76Cc421207669b55CE4BC0);
    IRootCLFactory clfactory = IRootCLFactory(0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F);
    uint256 chainid;

    function setUp() public virtual;

    function run() external virtual {
        PoolV2[] memory poolsV2 = setUpV2Pools();
        PoolCL[] memory poolsCL = setUpCLPools();

        vm.startBroadcast(deployer);
        deployV2Pools(poolsV2);
        deployCLPools(poolsCL);
        vm.stopBroadcast();
    }

    function deployV2Pools(PoolV2[] memory poolsV2) internal {
        for (uint256 i = 0; i < poolsV2.length; i++) {
            address existingPool = factoryV2.getPool({
                chainid: chainid,
                tokenA: poolsV2[i].tokenA,
                tokenB: poolsV2[i].tokenB,
                stable: poolsV2[i].stable
            });
            if (existingPool == address(0)) {
                address newPool = factoryV2.createPool({
                    chainid: chainid,
                    tokenA: poolsV2[i].tokenA,
                    tokenB: poolsV2[i].tokenB,
                    stable: poolsV2[i].stable
                });
                console.log("PoolCreated: ", newPool);
                console.log("tokenA: ", poolsV2[i].tokenA);
                console.log("tokenB: ", poolsV2[i].tokenB);
                console.log("stable: ", poolsV2[i].stable);
                console.log();
            } else {
                console.log("POOL ALREADY EXISTS: ", existingPool);
                console.log("tokenA: ", poolsV2[i].tokenA);
                console.log("tokenB: ", poolsV2[i].tokenB);
                console.log("stable: ", poolsV2[i].stable);
                console.log();
            }
        }
    }

    function deployCLPools(PoolCL[] memory poolsCL) internal {
        for (uint256 i = 0; i < poolsCL.length; i++) {
            address existingPool = clfactory.getPool({
                chainid: chainid,
                tokenA: poolsCL[i].tokenA,
                tokenB: poolsCL[i].tokenB,
                tickSpacing: poolsCL[i].tickSpacing
            });
            if (existingPool == address(0)) {
                address newPool = clfactory.createPool({
                    chainid: chainid,
                    tokenA: poolsCL[i].tokenA,
                    tokenB: poolsCL[i].tokenB,
                    tickSpacing: poolsCL[i].tickSpacing
                });
                console.log("PoolCreated: ", newPool);
                console.log("tokenA: ", poolsCL[i].tokenA);
                console.log("tokenB: ", poolsCL[i].tokenB);
                console.log("tickSpacing: ", poolsCL[i].tickSpacing);
                console.log();
            } else {
                console.log("POOL ALREADY EXISTS: ", existingPool);
                console.log("tokenA: ", poolsCL[i].tokenA);
                console.log("tokenB: ", poolsCL[i].tokenB);
                console.log("tickSpacing: ", poolsCL[i].tickSpacing);
                console.log();
            }
        }
    }

    function setUpV2Pools() internal virtual returns (PoolV2[] memory poolsV2);

    function setUpCLPools() internal virtual returns (PoolCL[] memory poolsCL);
}
