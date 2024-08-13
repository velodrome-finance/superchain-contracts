// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IMessageReceiver} from "src/interfaces/bridge/IMessageReceiver.sol";

contract MockMessageReceiver is IMessageReceiver {
    uint256 public amount;

    function receiveMessage(bytes calldata _message) external override {
        amount = abi.decode(_message, (uint256));
    }
}
