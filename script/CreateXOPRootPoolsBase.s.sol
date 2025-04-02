// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import "src/root/pools/RootPoolFactory.sol";

abstract contract CreateXOPRootPoolsBase is Script {
    struct PoolV2 {
        uint256 chainid;
        address tokenA;
        address tokenB;
        bool stable;
    }

    RootPoolFactory factoryV2 = RootPoolFactory(0x31832f2a97Fd20664D76Cc421207669b55CE4BC0);

    function setUp() public virtual {}

    function run() external virtual {
        PoolV2[] memory poolsV2 = setUpV2Pools();

        vm.startBroadcast();
        deployV2Pools(poolsV2);
        vm.stopBroadcast();
    }

    function deployV2Pools(PoolV2[] memory poolsV2) internal {
        for (uint256 i = 0; i < poolsV2.length; i++) {
            address existingPool = factoryV2.getPool({
                chainid: poolsV2[i].chainid,
                tokenA: poolsV2[i].tokenA,
                tokenB: poolsV2[i].tokenB,
                stable: poolsV2[i].stable
            });
            if (existingPool == address(0)) {
                address newPool = factoryV2.createPool({
                    chainid: poolsV2[i].chainid,
                    tokenA: poolsV2[i].tokenA,
                    tokenB: poolsV2[i].tokenB,
                    stable: poolsV2[i].stable
                });
                console.log("PoolCreated: ", newPool);
                console.log("chainid: ", poolsV2[i].chainid);
                console.log("tokenA: ", poolsV2[i].tokenA);
                console.log("tokenB: ", poolsV2[i].tokenB);
                console.log("stable: ", poolsV2[i].stable);
                console.log();
            } else {
                console.log("POOL ALREADY EXISTS: ", existingPool);
                console.log("chainid: ", poolsV2[i].chainid);
                console.log("tokenA: ", poolsV2[i].tokenA);
                console.log("tokenB: ", poolsV2[i].tokenB);
                console.log("stable: ", poolsV2[i].stable);
                console.log();
            }
        }
    }

    function setUpV2Pools() internal virtual returns (PoolV2[] memory poolsV2);
}
