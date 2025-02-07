// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IGasRouter} from "../../../interfaces/root/bridge/hyperlane/IGasRouter.sol";

/// @title Velodrome Superchain Gas Router
/// @notice Gas Router for commands for x-chain transactions
abstract contract GasRouter is IGasRouter, Ownable {
    /// @inheritdoc IGasRouter
    mapping(uint256 _command => uint256 _gas) public gasLimit;

    constructor(address _owner, uint256[] memory _commands, uint256[] memory _gasLimits) Ownable(_owner) {
        _setGasLimits(_commands, _gasLimits);
    }

    /// @inheritdoc IGasRouter
    function setGasLimit(uint256 _command, uint256 _gasLimit) external onlyOwner {
        _setGasLimit(_command, _gasLimit);
    }

    /// @inheritdoc IGasRouter
    function setGasLimits(uint256[] memory _commands, uint256[] memory _gasLimits) external onlyOwner {
        _setGasLimits(_commands, _gasLimits);
    }

    function _setGasLimits(uint256[] memory _commands, uint256[] memory _gasLimits) internal {
        uint256 length = _commands.length;
        if (length != _gasLimits.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < length; i++) {
            _setGasLimit(_commands[i], _gasLimits[i]);
        }
    }

    function _setGasLimit(uint256 _command, uint256 _gasLimit) internal {
        gasLimit[_command] = _gasLimit;
        emit GasLimitSet({_command: _command, _gasLimit: _gasLimit});
    }
}
