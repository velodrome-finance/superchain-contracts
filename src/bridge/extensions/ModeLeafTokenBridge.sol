// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {LeafTokenBridge} from "../LeafTokenBridge.sol";
import {ModeFeeSharing} from "../../extensions/ModeFeeSharing.sol";

/// @notice Token Bridge wrapper with fee sharing support
contract ModeLeafTokenBridge is LeafTokenBridge, ModeFeeSharing {
    constructor(address _owner, address _xerc20, address _mailbox, address _ism, address _recipient)
        LeafTokenBridge(_owner, _xerc20, _mailbox, _ism)
        ModeFeeSharing(_recipient)
    {}
}
