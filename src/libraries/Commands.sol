// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

/// @notice Commands for x-chain interactions
/// @dev Existing commands cannot be modified but new commands can be added
library Commands {
    // reward deposit & withdraw commands are kept early as these _must_ be sequential
    uint256 public constant DEPOSIT = 0x00;
    uint256 public constant WITHDRAW = 0x01;

    uint256 public constant GET_INCENTIVES = 0x10;
    uint256 public constant GET_FEES = 0x11;
    uint256 public constant CREATE_GAUGE = 0x12;
    uint256 public constant NOTIFY = 0x13;
    uint256 public constant NOTIFY_WITHOUT_CLAIM = 0x14;
    uint256 public constant KILL_GAUGE = 0x15;
    uint256 public constant REVIVE_GAUGE = 0x16;
}
