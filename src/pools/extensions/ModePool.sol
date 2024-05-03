// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Pool} from "../Pool.sol";
import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {IModePoolFactory} from "../../interfaces/pools/extensions/IModePoolFactory.sol";

contract ModePool is Pool {
    constructor() Pool() {}

    function initialize(address _token0, address _token1, bool _stable) public virtual override {
        super.initialize({_token0: _token0, _token1: _token1, _stable: _stable});
        address sfs = IModePoolFactory(msg.sender).sfs();
        uint256 tokenId = IModePoolFactory(msg.sender).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
