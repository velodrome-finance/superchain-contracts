// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IMessageBridge} from "../interfaces/bridge/IMessageBridge.sol";
import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";

/// @title Message Bridge Contract
/// @notice General purpose message bridge contract
contract MessageBridge is IMessageBridge, Ownable {
    /// @inheritdoc IMessageBridge
    address public immutable xerc20;
    /// @inheritdoc IMessageBridge
    address public immutable voter;
    /// @inheritdoc IMessageBridge
    address public immutable poolFactory;
    /// @inheritdoc IMessageBridge
    address public module;

    constructor(address _owner, address _xerc20, address _voter, address _module, address _poolFactory)
        Ownable(_owner)
    {
        xerc20 = _xerc20;
        voter = _voter;
        module = _module;
        poolFactory = _poolFactory;
    }

    /// @inheritdoc IMessageBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc IMessageBridge
    function mint(address _recipient, uint256 _amount) external {
        if (msg.sender != module) revert NotModule();
        IXERC20(xerc20).mint({_user: _recipient, _amount: _amount});
    }
}
