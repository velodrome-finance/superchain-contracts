// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {RootTokenBridge} from "./RootTokenBridge.sol";

/// @title Velodrome Superchain Root Restricted Token Bridge
/// @notice Token Bridge for Restricted XERC20 tokens
contract RootRestrictedTokenBridge is RootTokenBridge {
    constructor(address _owner, address _xerc20, address _module, address _ism)
        RootTokenBridge(_owner, _xerc20, _module, _ism)
    {}
}
