// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {StandardHookMetadata} from "@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol";

import {ISpecifiesInterchainSecurityModule} from "../interfaces/external/ISpecifiesInterchainSecurityModule.sol";
import {IHookGasEstimator} from "../interfaces/root/bridge/hyperlane/IHookGasEstimator.sol";
import {IHLHandler} from "../interfaces/bridge/hyperlane/IHLHandler.sol";
import {ITokenBridge} from "../interfaces/bridge/ITokenBridge.sol";

import {ChainRegistry} from "./ChainRegistry.sol";

/// @title Velodrome Superchain Base Token Bridge
/// @notice Base Token Bridge contract to be extended in Root & Leaf implementations
abstract contract BaseTokenBridge is ITokenBridge, IHLHandler, ISpecifiesInterchainSecurityModule, ChainRegistry {
    /// @inheritdoc ITokenBridge
    address public immutable xerc20;
    /// @inheritdoc ITokenBridge
    address public immutable mailbox;
    /// @inheritdoc ITokenBridge
    address public hook;
    /// @inheritdoc ITokenBridge
    IInterchainSecurityModule public securityModule;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism) ChainRegistry(_owner) {
        xerc20 = _xerc20;
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
        emit InterchainSecurityModuleSet({_new: _ism});
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule
    function interchainSecurityModule() external view returns (IInterchainSecurityModule) {
        return securityModule;
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule
    function setInterchainSecurityModule(address _ism) external onlyOwner {
        securityModule = IInterchainSecurityModule(_ism);
        emit InterchainSecurityModuleSet({_new: _ism});
    }

    /// @inheritdoc ITokenBridge
    function setHook(address _hook) external onlyOwner {
        hook = _hook;
        emit HookSet({_newHook: _hook});
    }

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint256 _chainid) external payable virtual;

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable virtual;

    function _generateGasMetadata(address _hook, uint256 _value, bytes memory _message)
        internal
        view
        virtual
        returns (bytes memory)
    {
        /// @dev If custom hook is set, it should be used to estimate gas
        uint256 gasLimit = _hook == address(0) ? GAS_LIMIT() : IHookGasEstimator(_hook).estimateSendTokenGas();
        return StandardHookMetadata.formatMetadata({
            _msgValue: _value,
            _gasLimit: gasLimit,
            _refundAddress: msg.sender,
            _customMetadata: ""
        });
    }

    /// @inheritdoc ITokenBridge
    function GAS_LIMIT() public pure virtual returns (uint256) {
        return 200_000;
    }
}
