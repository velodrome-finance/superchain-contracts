// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "../IRouter.sol";

interface IModeRouter is IRouter {
    /// @notice Token Id that sequencer fees are sent to.
    /// @return Token Id
    function tokenId() external view returns (uint256);
}
