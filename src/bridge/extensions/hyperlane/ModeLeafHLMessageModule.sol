// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {LeafHLMessageModule} from "../../hyperlane/LeafHLMessageModule.sol";
import {IModeFeeSharing} from "../../../interfaces/extensions/IModeFeeSharing.sol";
import {IFeeSharing} from "../../../interfaces/IFeeSharing.sol";

/// @notice Hyperlane Message Module wrapper with fee sharing support
contract ModeLeafHLMessageModule is LeafHLMessageModule {
    constructor(address _owner, address _bridge, address _mailbox, address _ism)
        LeafHLMessageModule(_owner, _bridge, _mailbox, _ism)
    {
        address sfs = IModeFeeSharing(_bridge).sfs();
        uint256 tokenId = IModeFeeSharing(_bridge).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
