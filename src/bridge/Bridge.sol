// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";
import {IBridge} from "../interfaces/bridge/IBridge.sol";
import {ITokenBridge} from "../interfaces/bridge/ITokenBridge.sol";
import {ILeafGauge} from "../interfaces/gauges/ILeafGauge.sol";
import {IVoter} from "../interfaces/external/IVoter.sol";

/// @notice Bridge contract for use only by Velodrome contracts
contract Bridge is IBridge, Ownable {
    using SafeERC20 for IERC20;

    /// @inheritdoc IBridge
    address public immutable xerc20;
    /// @inheritdoc IBridge
    address public immutable voter;
    /// @inheritdoc IBridge
    address public module;

    constructor(address _owner, address _xerc20, address _module, address _voter) Ownable(_owner) {
        xerc20 = _xerc20;
        module = _module;
        voter = _voter;
    }

    /// @inheritdoc IBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc IBridge
    function mint(address _user, uint256 _amount) external {
        if (msg.sender != module) revert NotModule();
        IXERC20(xerc20).mint({_user: _user, _amount: _amount});
    }

    /// @inheritdoc IBridge
    function notify(address _recipient, uint256 _amount) external {
        if (msg.sender != module) revert NotModule();
        IERC20(xerc20).safeIncreaseAllowance({spender: _recipient, value: _amount});
        ILeafGauge(_recipient).notifyRewardAmount({amount: _amount});
    }

    /// @inheritdoc IBridge
    function sendToken(uint256 _amount, uint256 _chainid) external payable {
        if (!IVoter(voter).isAlive(msg.sender)) revert NotValidGauge();
        IXERC20(xerc20).burn({_user: msg.sender, _amount: _amount});
        ITokenBridge(module).transfer{value: msg.value}({_sender: msg.sender, _amount: _amount, _chainid: _chainid});
    }
}
