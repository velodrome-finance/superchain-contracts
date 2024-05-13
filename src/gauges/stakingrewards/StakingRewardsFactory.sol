// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ITokenRegistry} from "../../interfaces/gauges/tokenregistry/ITokenRegistry.sol";
import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {StakingRewards} from "../../gauges/stakingrewards/StakingRewards.sol";
import {IPool} from "../../interfaces/pools/IPool.sol";

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗                                        
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝                                        
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗                                          
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝                                          
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗                                        
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝                                        
                                                                                                                      
███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗                                        
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║                                        
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║                                        
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║                                        
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║                                        
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝                                        
                                                                                                                      
███████╗████████╗ █████╗ ██╗  ██╗██╗███╗   ██╗ ██████╗     ███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
██╔════╝╚══██╔══╝██╔══██╗██║ ██╔╝██║████╗  ██║██╔════╝     ██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
███████╗   ██║   ███████║█████╔╝ ██║██╔██╗ ██║██║  ███╗    █████╗  ███████║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝ 
╚════██║   ██║   ██╔══██║██╔═██╗ ██║██║╚██╗██║██║   ██║    ██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝  
███████║   ██║   ██║  ██║██║  ██╗██║██║ ╚████║╚██████╔╝    ██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║   
╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   

*/

contract StakingRewardsFactory is IStakingRewardsFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IStakingRewardsFactory
    address public immutable tokenRegistry;

    /// @inheritdoc IStakingRewardsFactory
    address public admin;

    /// @inheritdoc IStakingRewardsFactory
    address public immutable router;

    /// @inheritdoc IStakingRewardsFactory
    mapping(address => address) public gauges;

    /// @inheritdoc IStakingRewardsFactory
    mapping(address => address) public poolForGauge;

    /// @inheritdoc IStakingRewardsFactory
    mapping(address => bool) public isAlive;

    /// @dev Array of approved Keeper addresses
    EnumerableSet.AddressSet internal _keeperRegistry;

    constructor(
        address _admin,
        address _keeperAdmin,
        address _tokenRegistry,
        address _router,
        address[] memory _keepers
    ) Ownable(_keeperAdmin) {
        for (uint256 i = 0; i < _keepers.length; i++) {
            _approveKeeper(_keepers[i]);
        }
        admin = _admin;
        tokenRegistry = _tokenRegistry;
        router = _router;
        emit SetAdmin({_admin: _admin});
    }

    /// @inheritdoc IStakingRewardsFactory
    function setAdmin(address _admin) external {
        if (msg.sender != admin) revert NotAdmin();
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        emit SetAdmin({_admin: _admin});
    }

    /// @inheritdoc IStakingRewardsFactory
    function createStakingRewards(address _pool, address _rewardToken) external returns (address stakingRewards) {
        if (gauges[_pool] != address(0)) revert GaugeExists();
        if (_rewardToken == address(0) || _pool == address(0)) revert ZeroAddress();
        (address token0, address token1) = IPool(_pool).tokens();
        ITokenRegistry _tokenRegistry = ITokenRegistry(tokenRegistry);
        if (!_tokenRegistry.isWhitelistedToken(token0) || !_tokenRegistry.isWhitelistedToken(token1)) {
            revert NotWhitelistedToken();
        }

        stakingRewards = _deployStakingRewards({_stakingToken: _pool, _rewardToken: _rewardToken});

        gauges[_pool] = stakingRewards;
        poolForGauge[stakingRewards] = _pool;
        isAlive[stakingRewards] = true;
        emit StakingRewardsCreated({
            pool: _pool,
            rewardToken: _rewardToken,
            stakingRewards: stakingRewards,
            creator: msg.sender
        });
    }

    /// @dev Internal function to deploy StakingRewards contracts
    function _deployStakingRewards(address _stakingToken, address _rewardToken) internal virtual returns (address) {
        return address(new StakingRewards({_stakingToken: _stakingToken, _rewardToken: _rewardToken}));
    }

    /// @inheritdoc IStakingRewardsFactory
    function killStakingRewards(address _gauge) external {
        if (msg.sender != admin) revert NotAdmin();
        if (!isAlive[_gauge]) revert StakingRewardsAlreadyKilled();

        isAlive[_gauge] = false;
        emit StakingRewardsKilled({_gauge: _gauge});
    }

    /// @inheritdoc IStakingRewardsFactory
    function reviveStakingRewards(address _gauge) external {
        if (msg.sender != admin) revert NotAdmin();
        if (isAlive[_gauge]) revert StakingRewardsStillAlive();

        isAlive[_gauge] = true;
        emit StakingRewardsRevived({_gauge: _gauge});
    }

    /// @inheritdoc IStakingRewardsFactory
    function approveKeeper(address _keeper) public virtual onlyOwner {
        _approveKeeper(_keeper);
    }

    // @dev Private approve function to be used in constructor
    function _approveKeeper(address _keeper) private {
        if (_keeper == address(0)) revert ZeroAddress();
        if (_keeperRegistry.contains(_keeper)) revert AlreadyApproved();

        _keeperRegistry.add(_keeper);
        emit ApproveKeeper(_keeper);
    }

    /// @inheritdoc IStakingRewardsFactory
    function unapproveKeeper(address _keeper) external virtual onlyOwner {
        if (!_keeperRegistry.contains(_keeper)) revert NotApproved();

        _keeperRegistry.remove(_keeper);
        emit UnapproveKeeper(_keeper);
    }

    /// @inheritdoc IStakingRewardsFactory
    function keepers() external view returns (address[] memory) {
        return _keeperRegistry.values();
    }

    /// @inheritdoc IStakingRewardsFactory
    function isKeeper(address _keeper) external view returns (bool) {
        return _keeperRegistry.contains(_keeper);
    }

    /// @inheritdoc IStakingRewardsFactory
    function keepersLength() external view returns (uint256) {
        return _keeperRegistry.length();
    }
}
