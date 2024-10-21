// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IFeeModule, ICustomFeeModule} from "../interfaces/fees/ICustomFeeModule.sol";
import {IPoolFactory} from "../interfaces/pools/IPoolFactory.sol";
import {IPool} from "../interfaces/pools/IPool.sol";

contract CustomFeeModule is ICustomFeeModule {
    /// @inheritdoc IFeeModule
    IPoolFactory public immutable factory;
    /// @inheritdoc ICustomFeeModule
    uint256 public constant MAX_FEE = 300; // 3%
    /// @inheritdoc ICustomFeeModule
    uint256 public constant ZERO_FEE_INDICATOR = 420;
    /// @inheritdoc ICustomFeeModule
    mapping(address => uint24) public customFee; // override for custom fees

    constructor(address _factory) {
        factory = IPoolFactory(_factory);
    }

    /// @inheritdoc ICustomFeeModule
    function setCustomFee(address _pool, uint24 _fee) external {
        if (msg.sender != factory.feeManager()) revert NotFeeManager();
        if (_fee > MAX_FEE && _fee != ZERO_FEE_INDICATOR) revert FeeTooHigh();
        if (!factory.isPool(_pool)) revert InvalidPool();

        customFee[_pool] = _fee;
        emit SetCustomFee({pool: _pool, fee: _fee});
    }

    /// @inheritdoc IFeeModule
    function getFee(address _pool) external view returns (uint24) {
        uint24 fee = customFee[_pool];
        return fee == ZERO_FEE_INDICATOR
            ? 0
            : fee != 0 ? fee : IPool(_pool).stable() ? uint24(factory.stableFee()) : uint24(factory.volatileFee());
    }
}
