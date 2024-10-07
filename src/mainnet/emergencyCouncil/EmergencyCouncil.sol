// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IVoter} from "../../interfaces/external/IVoter.sol";
import {IRootMessageBridge} from "../../mainnet/bridge/RootMessageBridge.sol";
import {IEmergencyCouncil} from "../../interfaces/emergencyCouncil/IEmergencyCouncil.sol";
import {Commands} from "../../libraries/Commands.sol";
import {IPool} from "../../interfaces/pools/IPool.sol";
import {IVotingEscrow} from "../../interfaces/external/IVotingEscrow.sol";
import {IRootGauge} from "../../interfaces/mainnet/gauges/IRootGauge.sol";

/// @title Emergency Council
/// @notice Contains logic for managing emergency council actions across superchain
contract EmergencyCouncil is Ownable, IEmergencyCouncil {
    /// @inheritdoc IEmergencyCouncil
    address public immutable voter;
    /// @inheritdoc IEmergencyCouncil
    address public immutable votingEscrow;
    /// @inheritdoc IEmergencyCouncil
    address public immutable bridge;

    constructor(address _owner, address _voter, address _bridge) Ownable(_owner) {
        voter = _voter;
        votingEscrow = IVoter(_voter).ve();
        bridge = _bridge;
    }

    /// @inheritdoc IEmergencyCouncil
    function killRootGauge(address _gauge) public onlyOwner {
        IVoter(voter).killGauge({_gauge: _gauge});
    }

    /// @inheritdoc IEmergencyCouncil
    function killLeafGauge(address _gauge) external onlyOwner {
        killRootGauge({_gauge: _gauge});

        uint256 _chainid = IRootGauge(_gauge).chainid();

        bytes memory message = abi.encodePacked(uint8(Commands.KILL_GAUGE), _gauge);
        IRootMessageBridge(bridge).sendMessage({_chainid: uint32(_chainid), _message: message});
    }

    /// @inheritdoc IEmergencyCouncil
    function reviveRootGauge(address _gauge) public onlyOwner {
        IVoter(voter).reviveGauge({_gauge: _gauge});
    }

    /// @inheritdoc IEmergencyCouncil
    function reviveLeafGauge(address _gauge) external onlyOwner {
        reviveRootGauge({_gauge: _gauge});

        uint256 _chainid = IRootGauge(_gauge).chainid();

        bytes memory message = abi.encodePacked(uint8(Commands.REVIVE_GAUGE), _gauge);
        IRootMessageBridge(bridge).sendMessage({_chainid: uint32(_chainid), _message: message});
    }

    /// @inheritdoc IEmergencyCouncil
    function setPoolName(address _pool, string memory _name) external onlyOwner {
        IPool(_pool).setName({__name: _name});
    }

    /// @inheritdoc IEmergencyCouncil
    function setPoolSymbol(address _pool, string memory _symbol) external onlyOwner {
        IPool(_pool).setSymbol({__symbol: _symbol});
    }

    function setManagedState(uint256 _mTokenId, bool _state) external onlyOwner {
        IVotingEscrow(votingEscrow).setManagedState({_mTokenId: _mTokenId, _state: _state});
    }
}
