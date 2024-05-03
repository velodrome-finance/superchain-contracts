// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Router} from "../Router.sol";
import {IFeeSharing} from "../interfaces/IFeeSharing.sol";
import {IModeRouter} from "../interfaces/extensions/IModeRouter.sol";

contract ModeRouter is Router, IModeRouter {
    /// @inheritdoc IModeRouter
    uint256 public immutable tokenId;

    constructor(address _factory, address _weth, address _sfs, address _recipient) Router(_factory, _weth) {
        tokenId = IFeeSharing(_sfs).register(_recipient);
    }
}
