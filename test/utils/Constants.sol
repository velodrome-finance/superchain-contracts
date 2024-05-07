// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";

abstract contract Constants {
    uint256 public constant TOKEN_1 = 1e18;
    uint256 public constant USDC_1 = 1e6;
    uint256 public constant POOL_1 = 1e9;

    uint256 public constant WEEK = VelodromeTimeLibrary.WEEK;

    bytes11 public constant POOL_ENTROPY = 0x0000000000000000000001;
    bytes11 public constant POOL_FACTORY_ENTROPY = 0x0000000000000000000002;
    bytes11 public constant ROUTER_ENTROPY = 0x0000000000000000000003;
}
