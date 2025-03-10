// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootFeesVotingReward {
    error AlreadyInitialized();
    error MaxTokensExceeded();
    error RecipientNotSet();
    error NotAuthorized();
    error InvalidGauge();

    /// @notice Address of root voting rewards factory that created this contract
    function factory() external view returns (address);

    /// @notice Address of bridge contract used to forward messages
    function bridge() external view returns (address);

    /// @notice Address of voter contract that sets voting power
    function voter() external view returns (address);

    /// @notice Address of voting escrow contract that manages locked tokens
    function ve() external view returns (address);

    /// @notice Address of incentive voting reward contract associated with the gauge
    function incentiveVotingReward() external view returns (address);

    /// @notice Address of gauge contract corresponding to this contract
    /// @dev Settable once on deploy only
    function gauge() external view returns (address);

    /// @notice Chain id associated with the gauge / this contract
    /// @dev Settable once on deploy only
    function chainid() external view returns (uint256);

    /// @notice Maximum number of tokens that can be claimed in `getReward()`
    function MAX_REWARDS() external view returns (uint256);

    /// @notice Initializes the contract with the gauge address and chain id
    /// @dev Called during voter.createGauge() only
    /// @dev Not protected as tx is atomic
    function initialize(address _gauge) external;

    /// @notice Deposits voting power to leaf fees & incentive reward contracts corresponding to gauge
    /// @param _amount Amount of voting power to deposit
    /// @param _tokenId token id to deposit voting power to
    function _deposit(uint256 _amount, uint256 _tokenId) external;

    /// @notice Withdraws voting power from leaf fees & incentive reward contracts corresponding to gauge
    /// @param _amount Amount of voting power to withdraw
    /// @param _tokenId token id to withdraw voting power from
    function _withdraw(uint256 _amount, uint256 _tokenId) external;

    /// @notice Claims rewards from leaf fees reward contract corresponding to gauge
    /// @param _tokenId  token id to claim rewards from
    /// @param _tokens   Array of tokens to claim rewards of
    function getReward(uint256 _tokenId, address[] memory _tokens) external;
}
