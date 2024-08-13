// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

/// @notice Constants used by Create3 deployment scripts
abstract contract Constants {
    bytes11 public constant POOL_ENTROPY = 0x0000000000000000000001;
    bytes11 public constant POOL_FACTORY_ENTROPY = 0x0000000000000000000002;
    bytes11 public constant ROUTER_ENTROPY = 0x0000000000000000000003;

    bytes11 public constant GAUGE_FACTORY_ENTROPY = 0x0000000000000000000005;

    bytes11 public constant XERC20_FACTORY_ENTROPY = 0x0000000000000000000011;
    bytes11 public constant BRIDGE_ENTROPY = 0x0000000000000000000012;
    bytes11 public constant MESSAGE_BRIDGE_ENTROPY = 0x0000000000000000000013;

    bytes11 public constant HL_TOKEN_BRIDGE_ENTROPY = 0x0000000000000000000022;
    bytes11 public constant HL_MESSAGE_BRIDGE_ENTROPY = 0x0000000000000000000023;

    // 40 - 50 is reserved for use by slipstream contracts

    // used by factory
    bytes11 public constant XERC20_ENTROPY = 0x0000000000000000000000;
    bytes11 public constant LOCKBOX_ENTROPY = 0x0000000000000000000001;
}
