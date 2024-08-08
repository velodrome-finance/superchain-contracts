// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";

abstract contract Constants {
    uint256 public constant TOKEN_1 = 1e18;
    uint256 public constant USDC_1 = 1e6;
    uint256 public constant POOL_1 = 1e9;

    // maximum number of tokens, used in fuzzing
    uint256 public constant MAX_TOKENS = 1e40;

    uint256 public constant DAY = 1 days;
    uint256 public constant WEEK = VelodromeTimeLibrary.WEEK;

    bytes11 public constant POOL_ENTROPY = 0x0000000000000000000001;
    bytes11 public constant POOL_FACTORY_ENTROPY = 0x0000000000000000000002;
    bytes11 public constant ROUTER_ENTROPY = 0x0000000000000000000003;

    bytes11 public constant GAUGE_FACTORY_ENTROPY = 0x0000000000000000000005;

    bytes11 public constant XERC20_FACTORY_ENTROPY = 0x0000000000000000000011;
    bytes11 public constant BRIDGE_ENTROPY = 0x0000000000000000000012;

    bytes11 public constant HL_TOKEN_BRIDGE_ENTROPY = 0x0000000000000000000022;

    // used by factory
    bytes11 public constant XERC20_ENTROPY = 0x0000000000000000000000;
    bytes11 public constant LOCKBOX_ENTROPY = 0x0000000000000000000001;
}
