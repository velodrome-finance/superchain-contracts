// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {Router} from "../Router.sol";
import {ModeFeeSharing} from "./ModeFeeSharing.sol";

contract ModeRouter is Router, ModeFeeSharing {
    constructor(address _factory, address _weth, address _recipient)
        Router(_factory, _weth)
        ModeFeeSharing(_recipient)
    {}
}
