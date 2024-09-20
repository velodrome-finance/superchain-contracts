// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootGaugeFactory} from "../../interfaces/mainnet/gauges/IRootGaugeFactory.sol";
import {IRootPool} from "../../interfaces/mainnet/pools/IRootPool.sol";
import {IRootBribeVotingReward} from "../../interfaces/mainnet/rewards/IRootBribeVotingReward.sol";
import {IRootFeesVotingReward} from "../../interfaces/mainnet/rewards/IRootFeesVotingReward.sol";
import {IRootMessageBridge} from "../../interfaces/mainnet/bridge/IRootMessageBridge.sol";

import {CreateXLibrary} from "../../libraries/CreateXLibrary.sol";
import {Commands} from "../../libraries/Commands.sol";
import {RootGauge} from "./RootGauge.sol";

/// @notice Factory that creates root gauges on mainnet
contract RootGaugeFactory is IRootGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc IRootGaugeFactory
    address public immutable voter;
    /// @inheritdoc IRootGaugeFactory
    address public immutable xerc20;
    /// @inheritdoc IRootGaugeFactory
    address public immutable lockbox;
    /// @inheritdoc IRootGaugeFactory
    address public immutable messageBridge;
    /// @inheritdoc IRootGaugeFactory
    address public immutable poolFactory;
    /// @inheritdoc IRootGaugeFactory
    address public immutable votingRewardsFactory;
    /// @inheritdoc IRootGaugeFactory
    address public notifyAdmin;
    /// @inheritdoc IRootGaugeFactory
    address public emissionAdmin;
    /// @inheritdoc IRootGaugeFactory
    uint256 public defaultCap;
    /// @notice Emission cap for each gauge
    mapping(address => uint256) internal _emissionCaps;

    constructor(
        address _voter,
        address _xerc20,
        address _lockbox,
        address _messageBridge,
        address _poolFactory,
        address _votingRewardsFactory,
        address _notifyAdmin,
        address _emissionAdmin,
        uint256 _defaultCap
    ) {
        voter = _voter;
        xerc20 = _xerc20;
        lockbox = _lockbox;
        messageBridge = _messageBridge;
        poolFactory = _poolFactory;
        votingRewardsFactory = _votingRewardsFactory;
        notifyAdmin = _notifyAdmin;
        emissionAdmin = _emissionAdmin;
        defaultCap = _defaultCap;
    }

    /// @inheritdoc IRootGaugeFactory
    function emissionCaps(address _gauge) external view returns (uint256) {
        uint256 emissionCap = _emissionCaps[_gauge];
        return emissionCap == 0 ? defaultCap : emissionCap;
    }

    /// @inheritdoc IRootGaugeFactory
    function setNotifyAdmin(address _admin) external {
        if (notifyAdmin != msg.sender) revert NotAuthorized();
        if (_admin == address(0)) revert ZeroAddress();
        notifyAdmin = _admin;
        emit SetNotifyAdmin({notifyAdmin: _admin});
    }

    /// @inheritdoc IRootGaugeFactory
    function createGauge(address, address _pool, address _feesVotingReward, address _rewardToken, bool)
        external
        returns (address gauge)
    {
        if (msg.sender != voter) revert NotVoter();
        address _token0 = IRootPool(_pool).token0();
        address _token1 = IRootPool(_pool).token1();
        bool _stable = IRootPool(_pool).stable();
        uint256 _chainid = IRootPool(_pool).chainid();
        bytes32 salt = keccak256(abi.encodePacked(_chainid, _token0, _token1, _stable));
        bytes11 entropy = bytes11(salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(RootGauge).creationCode,
                abi.encode(
                    address(this), // gauge factory
                    _rewardToken, // reward token
                    xerc20, // xerc20 corresponding to reward token
                    lockbox, // lockbox to convert reward token to xerc20
                    messageBridge, // message bridge to communicate x-chain
                    voter, // voter
                    _chainid // chain id associated with gauge
                )
            )
        });

        address _bribeVotingReward = IRootFeesVotingReward(_feesVotingReward).bribeVotingReward();
        IRootFeesVotingReward(_feesVotingReward).initialize(gauge);
        IRootBribeVotingReward(_bribeVotingReward).initialize(gauge);

        /// @dev Used to create pool using alternate createPool function
        uint24 _poolParam = _stable ? 1 : 0;
        bytes memory payload = abi.encode(votingRewardsFactory, address(this), _token0, _token1, _poolParam);
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, abi.encode(poolFactory, payload));
        IRootMessageBridge(messageBridge).sendMessage({_chainid: _chainid, _message: message});
    }

    /// @inheritdoc IRootGaugeFactory
    function setEmissionAdmin(address _admin) external {
        if (msg.sender != emissionAdmin) revert NotAuthorized();
        if (_admin == address(0)) revert ZeroAddress();
        emissionAdmin = _admin;
        emit SetEmissionAdmin({_emissionAdmin: _admin});
    }

    /// @inheritdoc IRootGaugeFactory
    function setEmissionCap(address _gauge, uint256 _emissionCap) external {
        if (msg.sender != emissionAdmin) revert NotAuthorized();
        if (_gauge == address(0)) revert ZeroAddress();
        _emissionCaps[_gauge] = _emissionCap;
        emit SetEmissionCap({_gauge: _gauge, _newEmissionCap: _emissionCap});
    }

    /// @inheritdoc IRootGaugeFactory
    function setDefaultCap(uint256 _defaultCap) external {
        if (msg.sender != emissionAdmin) revert NotAuthorized();
        if (_defaultCap == 0) revert ZeroDefaultCap();
        defaultCap = _defaultCap;
        emit SetDefaultCap({_newDefaultCap: _defaultCap});
    }
}
