// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVotingEscrow} from "../../external/IVotingEscrow.sol";
import {IRootTokenBridge} from "./IRootTokenBridge.sol";

interface IRootEscrowTokenBridge is IRootTokenBridge {
    error InvalidCommand();

    /// @notice The voting escrow contract used to lock velo
    function escrow() external view returns (IVotingEscrow);
}
