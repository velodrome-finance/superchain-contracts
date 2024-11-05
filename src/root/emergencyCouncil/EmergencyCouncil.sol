// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IEmergencyCouncil} from "../../interfaces/emergencyCouncil/IEmergencyCouncil.sol";
import {IRootMessageBridge} from "../../root/bridge/RootMessageBridge.sol";
import {IVotingEscrow} from "../../interfaces/external/IVotingEscrow.sol";
import {IRootGauge} from "../../interfaces/root/gauges/IRootGauge.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";
import {IPool} from "../../interfaces/pools/IPool.sol";
import {Commands} from "../../libraries/Commands.sol";

/// @title Emergency Council
/// @notice Contains logic for managing emergency council actions across superchain
contract EmergencyCouncil is Ownable, IEmergencyCouncil {
    /// @inheritdoc IEmergencyCouncil
    address public immutable voter;
    /// @inheritdoc IEmergencyCouncil
    address public immutable votingEscrow;

    constructor(address _owner, address _voter) Ownable(_owner) {
        voter = _voter;
        votingEscrow = IVoter(_voter).ve();
    }

    /// @inheritdoc IEmergencyCouncil
    function killRootGauge(address _gauge) external onlyOwner {
        try IRootGauge(_gauge).chainid() returns (uint256) {
            revert InvalidGauge();
        } catch {
            IVoter(voter).killGauge({_gauge: _gauge});
        }
    }

    /// @inheritdoc IEmergencyCouncil
    function killLeafGauge(address _gauge) external onlyOwner {
        IVoter(voter).killGauge({_gauge: _gauge});

        address bridge = IRootGauge(_gauge).bridge();
        uint256 chainid = IRootGauge(_gauge).chainid();

        bytes memory message = abi.encodePacked(uint8(Commands.KILL_GAUGE), _gauge);
        IRootMessageBridge(bridge).sendMessage({_chainid: uint32(chainid), _message: message});
    }

    /// @inheritdoc IEmergencyCouncil
    function reviveRootGauge(address _gauge) external onlyOwner {
        if (!IVoter(voter).isGauge({_gauge: _gauge})) {
            revert InvalidGauge();
        }
        try IRootGauge(_gauge).chainid() returns (uint256) {
            revert InvalidGauge();
        } catch {
            IVoter(voter).reviveGauge({_gauge: _gauge});
        }
    }

    /// @inheritdoc IEmergencyCouncil
    function reviveLeafGauge(address _gauge) external onlyOwner {
        if (!IVoter(voter).isGauge({_gauge: _gauge})) {
            revert InvalidGauge();
        }
        IVoter(voter).reviveGauge({_gauge: _gauge});

        address bridge = IRootGauge(_gauge).bridge();
        uint256 chainid = IRootGauge(_gauge).chainid();

        bytes memory message = abi.encodePacked(uint8(Commands.REVIVE_GAUGE), _gauge);
        IRootMessageBridge(bridge).sendMessage({_chainid: uint32(chainid), _message: message});
    }

    /// @inheritdoc IEmergencyCouncil
    function setPoolName(address _pool, string memory _name) external onlyOwner {
        IPool(_pool).setName({__name: _name});
    }

    /// @inheritdoc IEmergencyCouncil
    function setPoolSymbol(address _pool, string memory _symbol) external onlyOwner {
        IPool(_pool).setSymbol({__symbol: _symbol});
    }

    /// @inheritdoc IEmergencyCouncil
    function setManagedState(uint256 _mTokenId, bool _state) external onlyOwner {
        IVotingEscrow(votingEscrow).setManagedState({_mTokenId: _mTokenId, _state: _state});
    }

    /// @inheritdoc IEmergencyCouncil
    function setEmergencyCouncil(address _council) external onlyOwner {
        IVoter(voter).setEmergencyCouncil({_emergencyCouncil: _council});
    }
}
