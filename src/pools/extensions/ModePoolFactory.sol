// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {PoolFactory} from "../PoolFactory.sol";
import {ModeFeeSharing} from "../../extensions/ModeFeeSharing.sol";

/// @notice Pool factory wrapper with fee sharing support
contract ModePoolFactory is PoolFactory, ModeFeeSharing {
    constructor(address _implementation, address _poolAdmin, address _pauser, address _feeManager, address _recipient)
        PoolFactory(_implementation, _poolAdmin, _pauser, _feeManager)
        ModeFeeSharing(_recipient)
    {}
}
