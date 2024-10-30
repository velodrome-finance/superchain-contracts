// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";

import {IHookGasEstimator} from "src/interfaces/root/bridge/hyperlane/IHookGasEstimator.sol";
import {GasLimits} from "src/libraries/GasLimits.sol";

/// @dev Mock Custom Hook to test gas estimates
contract MockCustomHook is IPostDispatchHook, IHookGasEstimator {
    using GasLimits for uint256;

    /// @inheritdoc IPostDispatchHook
    uint8 public constant hookType = uint8(Types.UNUSED);

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
    function estimateGas(uint256 _command) external pure returns (uint256) {
        return _command.gasLimit() * 2;
    }
}
