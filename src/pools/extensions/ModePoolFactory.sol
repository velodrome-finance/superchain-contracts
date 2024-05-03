// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {PoolFactory} from "../PoolFactory.sol";
import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {IModePoolFactory} from "../../interfaces/pools/extensions/IModePoolFactory.sol";

/// @notice Pool factory wrapper with fee sharing support
contract ModePoolFactory is PoolFactory, IModePoolFactory {
    /// @inheritdoc IModePoolFactory
    address public immutable sfs;
    /// @inheritdoc IModePoolFactory
    uint256 public immutable tokenId;

    constructor(
        address _implementation,
        address _poolAdmin,
        address _pauser,
        address _feeManager,
        address _sfs,
        address _recipient
    ) PoolFactory(_implementation, _poolAdmin, _pauser, _feeManager) {
        sfs = _sfs;
        tokenId = IFeeSharing(_sfs).register(_recipient);
    }
}
