// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {Pool} from "../Pool.sol";
import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {IModeFeeSharing} from "../../interfaces/extensions/IModeFeeSharing.sol";

contract ModePool is Pool {
    constructor() Pool() {}

    function initialize(address _token0, address _token1, bool _stable) public virtual override {
        super.initialize({_token0: _token0, _token1: _token1, _stable: _stable});
        address sfs = IModeFeeSharing(msg.sender).sfs();
        uint256 tokenId = IModeFeeSharing(msg.sender).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
