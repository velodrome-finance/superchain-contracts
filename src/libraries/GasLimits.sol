// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Commands} from "./Commands.sol";

/// @notice Gas limits for commands for x-chain transactions
/// @dev These are 1.2x the amounts captured by forge gas snapshot
/// @dev Must be in sync with Commands.sol
library GasLimits {
    /// @dev Returns 0 if invalid _command
    function gasLimit(uint256 _command) internal pure returns (uint256) {
        if (_command == Commands.DEPOSIT) return 530_000;
        if (_command == Commands.WITHDRAW) return 145_000;
        if (_command == Commands.GET_INCENTIVES) return 710_000;
        if (_command == Commands.GET_FEES) return 325_000;
        if (_command == Commands.CREATE_GAUGE) return 5_800_000;
        if (_command == Commands.NOTIFY) return 282_000;
        if (_command == Commands.NOTIFY_WITHOUT_CLAIM) return 254_000;
        if (_command == Commands.KILL_GAUGE) return 90_000;
        if (_command == Commands.REVIVE_GAUGE) return 187_000;
        return 0;
    }
}
