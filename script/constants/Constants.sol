// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

/// @notice Constants used by Create3 deployment scripts
abstract contract Constants {
    bytes11 public constant POOL_ENTROPY = 0x0000000000000000000001;
    bytes11 public constant POOL_FACTORY_ENTROPY = 0x0000000000000000000002;
    bytes11 public constant ROUTER_ENTROPY = 0x0000000000000000000003;
    bytes11 public constant VOTER_ENTROPY = 0x0000000000000000000004;
    bytes11 public constant GAUGE_FACTORY_ENTROPY = 0x0000000000000000000005;
    bytes11 public constant REWARDS_FACTORY_ENTROPY = 0x0000000000000000000006;

    bytes11 public constant XERC20_FACTORY_ENTROPY = 0x0000000000000000000011;
    bytes11 public constant MESSAGE_BRIDGE_ENTROPY = 0x0000000000000000000013;
    bytes11 public constant HL_MESSAGE_BRIDGE_ENTROPY_V2 = 0x0020000000000000000023;
    bytes11 public constant TOKEN_BRIDGE_ENTROPY_V2 = 0x0020000000000000000014;

    // 40 - 50 is reserved for use by slipstream contracts

    bytes11 public constant XOP_FACTORY_ENTROPY = 0x0000000000000000000051;
    bytes11 public constant XOP_TOKEN_BRIDGE_ENTROPY = 0x0000000000000000000052;

    // used by factory
    bytes11 public constant XERC20_ENTROPY = 0x0000000000000000000000;
    bytes11 public constant LOCKBOX_ENTROPY = 0x0000000000000000000001;

    // used previously, no longer usable
    bytes11 public constant TOKEN_BRIDGE_ENTROPY = 0x0000000000000000000014;
    bytes11 public constant HL_MESSAGE_BRIDGE_ENTROPY = 0x0000000000000000000023;
    bytes11 public constant HL_MESSAGE_BRIDGE_ENTROPY_V1_5 = 0x0010000000000000000023;
}
