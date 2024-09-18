// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {ILeafMessageBridge} from "../interfaces/bridge/ILeafMessageBridge.sol";
import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";

/// @title Message Bridge Contract
/// @notice General purpose message bridge contract
contract LeafMessageBridge is ILeafMessageBridge, Ownable {
    /// @inheritdoc ILeafMessageBridge
    address public immutable xerc20;
    /// @inheritdoc ILeafMessageBridge
    address public immutable voter;
    /// @inheritdoc ILeafMessageBridge
    address public module;

    constructor(address _owner, address _xerc20, address _voter, address _module) Ownable(_owner) {
        xerc20 = _xerc20;
        voter = _voter;
        module = _module;
    }

    /// @inheritdoc ILeafMessageBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc ILeafMessageBridge
    function mint(address _recipient, uint256 _amount) external {
        if (msg.sender != module) revert NotModule();
        IXERC20(xerc20).mint({_user: _recipient, _amount: _amount});
    }
}
