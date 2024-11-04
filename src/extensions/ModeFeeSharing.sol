// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {IModeFeeSharing} from "../interfaces/extensions/IModeFeeSharing.sol";
import {IFeeSharing} from "../interfaces/IFeeSharing.sol";

/// @notice Wrapper to include fee sharing support in Superchain contracts
abstract contract ModeFeeSharing is IModeFeeSharing {
    /// @inheritdoc IModeFeeSharing
    address public constant sfs = 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020;
    /// @inheritdoc IModeFeeSharing
    uint256 public immutable tokenId;

    constructor(address _recipient) {
        tokenId = IFeeSharing(sfs).register(_recipient);
    }
}
