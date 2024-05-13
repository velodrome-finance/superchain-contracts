// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "../../IRouter.sol";
import {IPoolFactory} from "../../pools/IPoolFactory.sol";
import {IStakingRewardsFactory} from "../../gauges/stakingrewards/IStakingRewardsFactory.sol";

interface IConverter {
    error SlippageTooHigh();
    error NotAuthorized();
    error NoRouteFound();
    error AmountInZero();
    error ZeroAddress();
    error InvalidPath();
    error NotKeeper();

    event Compound(uint256 balanceCompounded);
    event SwapTokenToToken(
        address indexed sender, address indexed token, uint256 amountIn, uint256 amountOut, IRouter.Route[] routes
    );

    /// @notice Address of Gauge linked to this Converter
    function gauge() external view returns (address);

    /// @notice Address of Token to convert fees into
    function targetToken() external view returns (address);

    /// @notice Address of Router to be used for swaps
    function router() external view returns (IRouter);

    /// @notice Address of the PoolFactory
    function poolFactory() external view returns (IPoolFactory);

    /// @notice Address of the StakingRewardsFactory
    function stakingRewardsFactory() external view returns (IStakingRewardsFactory);

    /// @notice View for the amount of Tokens earned in an Epoch
    /// @param _epochStart Timestamp of Epoch Start
    /// @return _amount Amount of Tokens earned in given Epoch
    function amountEarned(uint256 _epochStart) external view returns (uint256 _amount);

    /// @notice Swap token held by the Converter into targetToken using the Route provided by the Keeper
    /// @dev    Only callable by Keepers
    /// @param _token Address of the Token to be converted into targetToken
    /// @param _slippage Maximum amount of Slippage allowed in swap
    /// @param _routes Routes to be used to execute swap
    function swapTokenToToken(address _token, uint256 _slippage, IRouter.Route[] memory _routes) external;

    /// @notice Deposit any Converted tokens into the StakingRewards
    /// @return amount Amount compounded by Converter
    function compound() external returns (uint256 amount);
}
