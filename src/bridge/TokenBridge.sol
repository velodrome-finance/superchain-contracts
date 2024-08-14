// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IUserTokenBridge} from "../interfaces/bridge/IUserTokenBridge.sol";
import {ITokenBridge} from "../interfaces/bridge/ITokenBridge.sol";
import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";

/// @title Token Bridge Contract
/// @notice General purpose Token bridge contract
contract TokenBridge is IUserTokenBridge, Ownable {
    /// @inheritdoc IUserTokenBridge
    address public immutable xerc20;
    /// @inheritdoc IUserTokenBridge
    address public module;

    constructor(address _owner, address _xerc20, address _module) Ownable(_owner) {
        xerc20 = _xerc20;
        module = _module;
    }

    /// @inheritdoc IUserTokenBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc IUserTokenBridge
    function mint(address _user, uint256 _amount) external {
        if (msg.sender != module) revert NotModule();
        IXERC20(xerc20).mint({_user: _user, _amount: _amount});
    }

    /// @inheritdoc IUserTokenBridge
    function sendToken(uint256 _amount, uint256 _chainid) external payable {
        if (_amount == 0) revert ZeroAmount();
        if (_chainid == block.chainid) revert InvalidChain();

        IXERC20(xerc20).burn({_user: msg.sender, _amount: _amount});

        ITokenBridge(module).transfer{value: msg.value}({_sender: msg.sender, _amount: _amount, _chainid: _chainid});
    }
}
