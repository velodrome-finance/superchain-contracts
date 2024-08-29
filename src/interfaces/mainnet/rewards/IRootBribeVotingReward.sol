// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootBribeVotingReward {
    error AlreadyInitialized();
    error NotAuthorized();

    /// @notice Address of bridge contract used to forward messages
    function bridge() external view returns (address);
    /// @notice Address of voter contract that sets voting power
    function voter() external view returns (address);
    /// @notice Address of voting escrow contract that manages locked tokens
    function ve() external view returns (address);
    /// @notice Address of gauge contract corresponding to this contract
    /// @dev Settable once on deploy only
    function gauge() external view returns (address);
    /// @notice Chain id associated with the gauge / this contract
    /// @dev Settable once on deploy only
    function chainid() external view returns (uint256);

    /// @notice Initializes the contract with the gauge address and chain id
    /// @dev Called during voter.createGauge() only
    /// @dev Not protected as tx is atomic
    function initialize(address _gauge) external;

    /// @notice Claims rewards from leaf reward contracts corresponding to gauge
    /// @param _tokenId  token id to claim rewards from
    /// @param _tokens   Array of tokens to claim rewards of
    function getReward(uint256 _tokenId, address[] memory _tokens) external;
}
