// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {IStakingRewards} from "../../interfaces/gauges/stakingrewards/IStakingRewards.sol";
import {IConverter} from "../../interfaces/gauges/stakingrewards/IConverter.sol";
import {VelodromeTimeLibrary} from "../../libraries/VelodromeTimeLibrary.sol";
import {IPoolFactory} from "../../interfaces/pools/IPoolFactory.sol";
import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {IPool} from "../../interfaces/pools/IPool.sol";
import {IRouter} from "../../interfaces/IRouter.sol";

/// @title Velodrome xChain Rewards Converter Contract
/// @author velodrome.finance
/// @notice Contract designed to Claim and Convert fees accrued by the Staking into the given target token
contract Converter is IConverter, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Maximum slippage allowed on Swaps
    uint256 public constant MAX_SLIPPAGE = 500;
    /// @dev Default granularity used to fetch quotes
    uint256 public constant POINTS = 3;

    /// @inheritdoc IConverter
    address public immutable gauge;
    /// @inheritdoc IConverter
    address public immutable targetToken;

    /// @inheritdoc IConverter
    IRouter public immutable router;
    /// @inheritdoc IConverter
    IPoolFactory public immutable poolFactory;
    /// @inheritdoc IConverter
    IStakingRewardsFactory public immutable stakingRewardsFactory;

    /// @inheritdoc IConverter
    mapping(uint256 epochStart => uint256 amount) public amountEarned;

    constructor(address _stakingRewardsFactory, address _poolFactory, address _targetToken) {
        gauge = msg.sender;
        targetToken = _targetToken;
        poolFactory = IPoolFactory(_poolFactory);
        stakingRewardsFactory = IStakingRewardsFactory(_stakingRewardsFactory);
        router = IRouter(IStakingRewardsFactory(_stakingRewardsFactory).router());
    }

    /// @dev Keep amountEarned for the epoch synced based on the balance before and after operations
    modifier syncAmountEarned() {
        uint256 balanceBefore = IERC20(targetToken).balanceOf(address(this));
        _;
        uint256 delta = IERC20(targetToken).balanceOf(address(this)) - balanceBefore;
        if (delta > 0) {
            amountEarned[VelodromeTimeLibrary.epochStart(block.timestamp)] += delta;
        }
    }

    /// @inheritdoc IConverter
    function swapTokenToToken(address _token, uint256 _slippage, IRouter.Route[] memory _routes)
        external
        nonReentrant
        syncAmountEarned
    {
        if (!stakingRewardsFactory.isKeeper(msg.sender)) revert NotKeeper();
        if (_slippage > MAX_SLIPPAGE) revert SlippageTooHigh();
        if (_token == address(0)) revert ZeroAddress();
        if (_token == targetToken) revert InvalidPath();

        uint256 routeLength = _routes.length;
        if (routeLength == 0) revert InvalidPath();
        if (_routes[0].from != _token) revert InvalidPath();
        if (_routes[routeLength - 1].to != targetToken) revert InvalidPath();

        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance == 0) revert AmountInZero();

        // Estimate optimal amountOutMin
        uint256 amountOutMin = _getOptimalAmountOutMin({_routes: _routes, _amountIn: balance, _slippage: _slippage});
        if (amountOutMin == 0) revert NoRouteFound();

        // Execute Swap
        IERC20(_token).safeIncreaseAllowance({spender: address(router), value: balance});
        uint256[] memory amountsOut = router.swapExactTokensForTokens({
            amountIn: balance,
            amountOutMin: amountOutMin,
            routes: _routes,
            to: address(this),
            deadline: block.timestamp
        });

        emit SwapTokenToToken({
            sender: msg.sender,
            token: _token,
            amountIn: balance,
            amountOut: amountsOut[amountsOut.length - 1],
            routes: _routes
        });
    }

    /// @inheritdoc IConverter
    function compound() external nonReentrant returns (uint256 amount) {
        if (msg.sender != gauge) revert NotAuthorized();

        amount = IERC20(targetToken).balanceOf(address(this));
        if (amount > 0) {
            IERC20(targetToken).safeTransfer({to: gauge, value: amount});
            emit Compound({balanceCompounded: amount});
        }
    }

    /// @dev Fetches an optimal `amountOutMin` given the Swap information and desired slippage
    /// @param _routes Routes to be used to fetch quote
    /// @param _amountIn Input amount for swap
    /// @param _slippage Maximum slippage allowed in swap
    /// @return amountOutMin Minimum amount of output token given expected amountOut and `_slippage`
    function _getOptimalAmountOutMin(IRouter.Route[] memory _routes, uint256 _amountIn, uint256 _slippage)
        internal
        view
        returns (uint256 amountOutMin)
    {
        uint256 length = _routes.length;

        for (uint256 i = 0; i < length; i++) {
            IRouter.Route memory route = _routes[i];
            address pool = poolFactory.getPool({tokenA: route.from, tokenB: route.to, stable: route.stable});

            // Return 0 if the pool does not exist
            if (pool == address(0)) return 0;
            uint256 amountOut = IPool(pool).quote({tokenIn: route.from, amountIn: _amountIn, granularity: POINTS});
            // Overwrite _amountIn assuming we're using the TWAP for the next route swap
            _amountIn = amountOut;
        }

        // At this point, _amountIn is actually amountOut as we finished the loop
        amountOutMin = (_amountIn * (10_000 - _slippage)) / 10_000;
    }

    /// @inheritdoc IConverter
    function claimFees() external nonReentrant returns (uint256, uint256) {
        if (!stakingRewardsFactory.isKeeper(msg.sender)) revert NotKeeper();
        return IStakingRewards(gauge).claimFees();
    }
}
