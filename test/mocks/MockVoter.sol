// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";

import {RootGaugeFactory} from "src/mainnet/gauges/RootGaugeFactory.sol";
import {IVoter} from "src/interfaces/external/IVoter.sol";
import {IFactoryRegistry} from "src/interfaces/external/IFactoryRegistry.sol";
import {IRootGauge} from "src/interfaces/mainnet/gauges/IRootGauge.sol";
import {IRootPool} from "src/interfaces/mainnet/pools/IRootPool.sol";
import {IRootPoolFactory} from "src/interfaces/mainnet/pools/IRootPoolFactory.sol";
import {IRootVotingRewardsFactory} from "src/interfaces/mainnet/rewards/IRootVotingRewardsFactory.sol";

contract MockVoter is IVoter {
    // mock addresses used for testing gauge creation, a copy is stored in Constants.sol
    address public forwarder = address(11);

    // Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;

    /// @dev pool => gauge
    mapping(address => address) public override gauges;
    /// @dev gauge => isAlive
    mapping(address => bool) public override isAlive;
    mapping(address => address) public override gaugeToFees;
    mapping(address => address) public override gaugeToBribe;
    mapping(address => bool) public override isWhitelistedToken;

    IERC20 internal immutable rewardToken;
    IFactoryRegistry public immutable override factoryRegistry;
    address public immutable override emergencyCouncil;
    address public immutable override ve;

    constructor(address _rewardToken, address _factoryRegistry, address _ve) {
        rewardToken = IERC20(_rewardToken);
        factoryRegistry = IFactoryRegistry(_factoryRegistry);
        emergencyCouncil = msg.sender;
        ve = _ve;
    }

    function claimFees(address[] memory, address[][] memory, uint256) external override {}

    function distribute(address[] memory) external pure override {
        revert("Not implemented");
    }

    function createGauge(address _poolFactory, address _pool) external override returns (address) {
        require(factoryRegistry.isPoolFactoryApproved(_poolFactory));
        (address votingRewardsFactory, address gaugeFactory) = factoryRegistry.factoriesToPoolFactory(_poolFactory);

        /// @dev mimic flow in real voter, note that feesVotingReward and bribeVotingReward are unused mocks
        address[] memory rewards = new address[](2);
        rewards[0] = IRootPool(_pool).token0();
        rewards[1] = IRootPool(_pool).token1();
        (address feesVotingReward, address bribeVotingReward) =
            IRootVotingRewardsFactory(votingRewardsFactory).createRewards(address(0), rewards);

        address gauge =
            RootGaugeFactory(gaugeFactory).createGauge(forwarder, _pool, feesVotingReward, address(rewardToken), true);
        require(IRootPoolFactory(_poolFactory).isPair(_pool));
        isAlive[gauge] = true;
        gauges[_pool] = gauge;
        gaugeToFees[gauge] = feesVotingReward;
        gaugeToBribe[gauge] = bribeVotingReward;
        isWhitelistedToken[rewards[0]] = true;
        isWhitelistedToken[rewards[1]] = true;
        return gauge;
    }

    // function distribute(address gauge) external override {
    //     uint256 _claimable = rewardToken.balanceOf(address(this));
    //     if (_claimable > IRootGauge(gauge).left() && _claimable > DURATION) {
    //         rewardToken.approve(gauge, _claimable);
    //         IRootGauge(gauge).notifyRewardAmount(rewardToken.balanceOf(address(this)));
    //     }
    // }

    function killGauge(address gauge) external override {
        isAlive[gauge] = false;
    }

    function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external override {}

    // function claimRewards(address[] memory _gauges) external override {
    //     uint256 _length = _gauges.length;
    //     for (uint256 i = 0; i < _length; i++) {
    //         IRootGauge(_gauges[i]).getReward(msg.sender);
    //     }
    // }
}
