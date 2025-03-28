// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {RootTokenBridge, BaseTokenBridge} from "./RootTokenBridge.sol";
import {ITokenBridge} from "../../interfaces/bridge/ITokenBridge.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";
import {IRootGauge} from "../../interfaces/root/gauges/IRootGauge.sol";
import {IRootHLMessageModule} from "../../interfaces/root/bridge/hyperlane/IRootHLMessageModule.sol";
import {IRootRestrictedTokenBridge} from "../../interfaces/root/bridge/IRootRestrictedTokenBridge.sol";

/// @title Velodrome Superchain Root Restricted Token Bridge
/// @notice Token Bridge for Restricted XERC20 tokens
contract RootRestrictedTokenBridge is RootTokenBridge, IRootRestrictedTokenBridge {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @inheritdoc IRootRestrictedTokenBridge
    uint256 public constant BASE_CHAIN_ID = 8453;
    /// @inheritdoc IRootRestrictedTokenBridge
    address public immutable voter;

    constructor(address _owner, address _xerc20, address _module, address _paymasterVault, address _ism)
        RootTokenBridge(_owner, _xerc20, _module, _paymasterVault, _ism)
    {
        voter = IRootHLMessageModule(_module).voter();
    }

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint256 _chainid)
        external
        payable
        override(RootTokenBridge, ITokenBridge)
    {
        if (_amount == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert ZeroAddress();
        if (!_chainids.contains({value: _chainid})) revert NotRegistered();

        if (_chainid != BASE_CHAIN_ID) {
            // for superchain gauges, check gauge exists on the leaf chain
            if (IVoter(voter).gaugeToBribe({_gauge: _recipient}) == address(0)) revert InvalidGauge();
            if (!IVoter(voter).isAlive({_gauge: _recipient})) revert GaugeNotAlive();
            if (IRootGauge(_recipient).chainid() != _chainid) revert InvalidChainId();
        }

        _send({_amount: _amount, _recipient: _recipient, _chainid: _chainid});
    }

    /// @inheritdoc ITokenBridge
    function GAS_LIMIT() public pure override(BaseTokenBridge, ITokenBridge) returns (uint256) {
        return 272_000;
    }
}
