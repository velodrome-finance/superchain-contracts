// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin5/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {IVotingRewardsFactory} from "../interfaces/external/IVotingRewardsFactory.sol";
import {IFactoryRegistry} from "../interfaces/external/IFactoryRegistry.sol";
import {ILeafGaugeFactory} from "../interfaces/gauges/ILeafGaugeFactory.sol";
import {ILeafGauge} from "../interfaces/gauges/ILeafGauge.sol";
import {IReward} from "../interfaces/external/IReward.sol";
import {IPoolFactory} from "../interfaces/pools/IPoolFactory.sol";
import {IPool} from "../interfaces/pools/IPool.sol";
import {ILeafVoter} from "../interfaces/voter/ILeafVoter.sol";

/// @title Velodrome Superchain Voter
/// @author velodrome.finance
/// @notice Leaf Voter contract to manage Votes on non-canonical chains
contract LeafVoter is ILeafVoter, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ILeafVoter
    address public immutable factoryRegistry;
    /// @inheritdoc ILeafVoter
    address public emergencyCouncil;

    /// @dev All pools viable for incentives
    address[] public pools;
    /// @inheritdoc ILeafVoter
    mapping(address => address) public gauges;
    /// @inheritdoc ILeafVoter
    mapping(address => address) public poolForGauge;
    /// @inheritdoc ILeafVoter
    mapping(address => address) public gaugeToFees;
    /// @inheritdoc ILeafVoter
    mapping(address => address) public gaugeToBribe;
    /// @inheritdoc ILeafVoter
    mapping(address => bool) public isGauge;
    /// @inheritdoc ILeafVoter
    mapping(address => bool) public isAlive;
    /// @inheritdoc ILeafVoter
    mapping(address => uint256) public whitelistTokenCount;
    /// @dev Set of Whitelisted Tokens
    EnumerableSet.AddressSet private _whitelistedTokens;

    constructor(address _factoryRegistry, address _emergencyCouncil) {
        factoryRegistry = _factoryRegistry;
        emergencyCouncil = _emergencyCouncil;
    }

    /// @inheritdoc ILeafVoter
    function whitelistedTokens() external view returns (address[] memory) {
        return _whitelistedTokens.values();
    }

    /// @inheritdoc ILeafVoter
    function whitelistedTokens(uint256 _start, uint256 _end) external view returns (address[] memory _tokens) {
        uint256 length = _whitelistedTokens.length();
        _end = _end < length ? _end : length;
        _tokens = new address[](_end - _start);
        for (uint256 i = 0; i < _end - _start; i++) {
            _tokens[i] = _whitelistedTokens.at(i + _start);
        }
    }

    /// @inheritdoc ILeafVoter
    function isWhitelistedToken(address _token) external view returns (bool) {
        return _whitelistedTokens.contains(_token);
    }

    /// @inheritdoc ILeafVoter
    function whitelistedTokensLength() external view returns (uint256) {
        return _whitelistedTokens.length();
    }

    /// @inheritdoc ILeafVoter
    function createGauge(address _poolFactory, address _pool) external nonReentrant returns (address _gauge) {
        // TODO: Call should be permissioned to message bridge only
        // if (msg.sender != bridge) revert NotBridge();

        address[] memory rewards = new address[](2);
        (rewards[0], rewards[1]) = IPool(_pool).tokens();

        (address votingRewardsFactory, address gaugeFactory) =
            IFactoryRegistry(factoryRegistry).factoriesToPoolFactory(_poolFactory);

        (address _feeVotingReward, address _bribeVotingReward) =
            IVotingRewardsFactory(votingRewardsFactory).createRewards({_forwarder: address(0), _rewards: rewards});

        _gauge = ILeafGaugeFactory(gaugeFactory).createGauge({
            _token0: rewards[0],
            _token1: rewards[1],
            _stable: IPool(_pool).stable(),
            _feesVotingReward: _feeVotingReward,
            isPool: IPoolFactory(_poolFactory).isPool(_pool)
        });

        gaugeToFees[_gauge] = _feeVotingReward;
        gaugeToBribe[_gauge] = _bribeVotingReward;
        gauges[_pool] = _gauge;
        poolForGauge[_gauge] = _pool;
        isGauge[_gauge] = true;
        isAlive[_gauge] = true;
        pools.push(_pool);

        _whitelistToken(rewards[0], true);
        _whitelistToken(rewards[1], true);

        emit GaugeCreated({
            poolFactory: _poolFactory,
            votingRewardsFactory: votingRewardsFactory,
            gaugeFactory: gaugeFactory,
            pool: _pool,
            bribeVotingReward: _bribeVotingReward,
            feeVotingReward: _feeVotingReward,
            gauge: _gauge,
            creator: msg.sender
        });
    }

    /// @inheritdoc ILeafVoter
    function killGauge(address _gauge) external {
        if (msg.sender != emergencyCouncil) revert NotEmergencyCouncil();
        if (!isAlive[_gauge]) revert GaugeAlreadyKilled();

        isAlive[_gauge] = false;
        (address token0, address token1) = IPool(poolForGauge[_gauge]).tokens();
        _whitelistToken(token0, false);
        _whitelistToken(token1, false);
        emit GaugeKilled({gauge: _gauge});
    }

    /// @inheritdoc ILeafVoter
    function reviveGauge(address _gauge) external {
        if (msg.sender != emergencyCouncil) revert NotEmergencyCouncil();
        if (!isGauge[_gauge]) revert NotAGauge();
        if (isAlive[_gauge]) revert GaugeAlreadyRevived();

        isAlive[_gauge] = true;
        (address token0, address token1) = IPool(poolForGauge[_gauge]).tokens();
        _whitelistToken(token0, true);
        _whitelistToken(token1, true);
        emit GaugeRevived({gauge: _gauge});
    }

    /// @inheritdoc ILeafVoter
    function claimRewards(address[] memory _gauges) external {
        uint256 _length = _gauges.length;
        for (uint256 i = 0; i < _length; i++) {
            ILeafGauge(_gauges[i]).getReward(msg.sender);
        }
    }

    /// @inheritdoc ILeafVoter
    function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint256 _tokenId) external {
        // TODO: Needs to be permissioned
        // if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId)) revert NotApprovedOrOwner();
        uint256 _length = _bribes.length;
        for (uint256 i = 0; i < _length; i++) {
            IReward(_bribes[i]).getReward(_tokenId, _tokens[i]);
        }
    }

    /// @inheritdoc ILeafVoter
    function claimFees(address[] memory _fees, address[][] memory _tokens, uint256 _tokenId) external {
        // TODO: Needs to be permissioned
        // if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId)) revert NotApprovedOrOwner();
        uint256 _length = _fees.length;
        for (uint256 i = 0; i < _length; i++) {
            IReward(_fees[i]).getReward(_tokenId, _tokens[i]);
        }
    }

    /// @inheritdoc ILeafVoter
    function setEmergencyCouncil(address _council) public {
        if (msg.sender != emergencyCouncil) revert NotEmergencyCouncil();
        if (_council == address(0)) revert ZeroAddress();
        emergencyCouncil = _council;
        emit SetEmergencyCouncil({emergencyCouncil: _council});
    }

    /// @notice Sets the whitelist state of a given token
    /// @dev    Assumes token to be unwhitelisted has whitelistTokenCount > 0
    /// @param _token The address of the token for whitelist
    /// @param _bool Whether the token should be whitelisted or not
    function _whitelistToken(address _token, bool _bool) internal {
        if (_bool) {
            if (++whitelistTokenCount[_token] == 1) {
                _whitelistedTokens.add(_token);
            }
        } else {
            if (--whitelistTokenCount[_token] == 0) {
                _whitelistedTokens.remove(_token);
            }
        }
        emit WhitelistToken({whitelister: msg.sender, token: _token, _bool: _bool});
    }
}
