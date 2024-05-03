// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {IStakingRewards} from "../../interfaces/gauges/stakingrewards/IStakingRewards.sol";
import {IConverter} from "../../interfaces/IConverter.sol";

/// @title Velodrome xChain Rewards Converter Contract
/// @author velodrome.finance
/// @notice Contract designed to Claim and Convert fees accrued by the Staking into the given target token
contract Converter is IConverter, ReentrancyGuard {
    address public immutable gauge;
    address public immutable targetToken;
    IStakingRewardsFactory public immutable stakingRewardsFactory;

    constructor(address _stakingRewardsFactory, address _targetToken, address _sfs, uint256 _tokenId) {
        gauge = msg.sender;
        targetToken = _targetToken;
        IFeeSharing(_sfs).assign(_tokenId);
        stakingRewardsFactory = IStakingRewardsFactory(_stakingRewardsFactory);
    }
}
