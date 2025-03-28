// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";
import {Constants} from "script/constants/Constants.sol";

abstract contract TestConstants is Constants {
    uint256 public constant TOKEN_1 = 1e18;
    uint256 public constant USDC_1 = 1e6;
    uint256 public constant POOL_1 = 1e9;

    // maximum number of tokens, used in fuzzing
    uint256 public constant MAX_TOKENS = 1e40;
    uint256 public constant MAX_BPS = 10_000;
    uint112 public constant MAX_BUFFER_CAP = type(uint112).max;

    uint256 constant MAX_TIME = 4 * 365 * 86400;
    uint256 constant PRECISION = 10 ** 18;

    uint256 public constant DAY = 1 days;
    uint256 public constant WEEK = VelodromeTimeLibrary.WEEK;

    address public constant SUPERCHAIN_ERC20_BRIDGE = 0x4200000000000000000000000000000000000028;
}
