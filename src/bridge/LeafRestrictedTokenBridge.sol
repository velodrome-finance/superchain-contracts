// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {LeafTokenBridge} from "./LeafTokenBridge.sol";

/// @title Velodrome Superchain Leaf Restricted Token Bridge
/// @notice Token Bridge for Restricted XERC20 tokens on leaf chains
contract LeafRestrictedTokenBridge is LeafTokenBridge {
    constructor(address _owner, address _xerc20, address _mailbox, address _ism)
        LeafTokenBridge(_owner, _xerc20, _mailbox, _ism)
    {}
}
