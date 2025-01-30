// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";

import {IHookGasEstimator} from "src/interfaces/root/bridge/hyperlane/IHookGasEstimator.sol";
import {GasRouter} from "src/root/bridge/hyperlane/GasRouter.sol";

/// @dev Mock Custom Hook to test gas estimates
contract MockCustomHook is GasRouter, IPostDispatchHook, IHookGasEstimator {
    /// @inheritdoc IPostDispatchHook
    uint8 public constant hookType = uint8(Types.UNUSED);

    constructor(address _owner, uint256[] memory _commands, uint256[] memory _gasLimits)
        GasRouter(_owner, _commands, _gasLimits)
    {}

    /// @inheritdoc IPostDispatchHook
    function supportsMetadata(bytes calldata metadata) external view returns (bool) {}

    /// @inheritdoc IPostDispatchHook
    function postDispatch(bytes calldata metadata, bytes calldata message) external payable {}

    /// @inheritdoc IPostDispatchHook
    function quoteDispatch(bytes calldata metadata, bytes calldata message) external view returns (uint256) {}

    /// @inheritdoc IHookGasEstimator
    function estimateSendTokenGas() external pure returns (uint256) {
        return 400_000;
    }

    /// @inheritdoc IHookGasEstimator
    function estimateGas(uint256 _command) external view returns (uint256) {
        return gasLimit[_command] * 2;
    }
}
