// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IPaymasterVault} from "../../../interfaces/root/bridge/hyperlane/IPaymasterVault.sol";

/// @title Velodrome Superchain Paymaster Vault
/// @notice Vault used to sponsor x-chain transactions
contract PaymasterVault is IPaymasterVault, Ownable {
    /// @inheritdoc IPaymasterVault
    address public immutable vaultManager;

    constructor(address _owner, address _vaultManager) Ownable(_owner) {
        vaultManager = _vaultManager;
    }

    receive() external payable {}

    /// @inheritdoc IPaymasterVault
    function withdrawFunds(address _recipient, uint256 _amount) external onlyOwner {
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount > 0) {
            (bool success,) = _recipient.call{value: _amount}("");
            if (!success) revert ETHTransferFailed();

            emit FundsWithdrawn({_recipient: _recipient, _amount: _amount});
        }
    }

    /// @inheritdoc IPaymasterVault
    function sponsorTransaction(uint256 _value) external {
        if (msg.sender != vaultManager) revert NotVaultManager();

        (bool success,) = vaultManager.call{value: _value}("");
        if (!success) revert ETHTransferFailed();
    }
}
