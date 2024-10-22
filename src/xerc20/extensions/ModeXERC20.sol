// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {XERC20} from "../XERC20.sol";
import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";

/// @notice xERC-20 wrapper with fee sharing support
contract ModeXERC20 is XERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _lockbox,
        address _sfs,
        uint256 _tokenId
    ) XERC20(_name, _symbol, _owner, _lockbox) {
        IFeeSharing(_sfs).assign(_tokenId);
    }
}
