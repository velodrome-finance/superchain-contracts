// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {LeafVoter} from "../LeafVoter.sol";
import {ModeFeeSharing} from "../../extensions/ModeFeeSharing.sol";

/// @notice Leaf Voter wrapper with fee sharing support
contract ModeLeafVoter is LeafVoter, ModeFeeSharing {
    constructor(address _bridge, address _recipient) LeafVoter(_bridge) ModeFeeSharing(_recipient) {}
}
