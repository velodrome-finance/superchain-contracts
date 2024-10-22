// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {LeafMessageBridge} from "../LeafMessageBridge.sol";
import {ModeFeeSharing} from "../../extensions/ModeFeeSharing.sol";

/// @notice Message Bridge wrapper with fee sharing support
contract ModeLeafMessageBridge is LeafMessageBridge, ModeFeeSharing {
    constructor(address _owner, address _xerc20, address _voter, address _module, address _recipient)
        LeafMessageBridge(_owner, _xerc20, _voter, _module)
        ModeFeeSharing(_recipient)
    {}
}
