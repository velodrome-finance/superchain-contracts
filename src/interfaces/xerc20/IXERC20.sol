// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IXERC20 {
    /// @notice Emits when a limit is set
    /// @param _mintingLimit The updated minting limit we are setting to the bridge
    /// @param _burningLimit The updated burning limit we are setting to the bridge
    /// @param _bridge The address of the bridge we are setting the limit to
    event BridgeLimitsSet(uint256 _mintingLimit, uint256 _burningLimit, address indexed _bridge);

    /// @notice Reverts when a user with too low of a limit tries to call mint/burn
    error IXERC20_NotHighEnoughLimits();

    /// @notice Reverts when limits are too high
    error IXERC20_LimitsTooHigh();

    /// @notice Contains the full minting and burning data for a particular bridge
    /// @param minterParams The minting parameters for the bridge
    /// @param burnerParams The burning parameters for the bridge
    struct Bridge {
        BridgeParameters minterParams;
        BridgeParameters burnerParams;
    }

    /// @notice Contains the mint or burn parameters for a bridge
    /// @param timestamp The timestamp of the last mint/burn
    /// @param ratePerSecond The rate per second of the bridge
    /// @param maxLimit The max limit of the bridge
    /// @param currentLimit The current limit of the bridge
    struct BridgeParameters {
        uint256 timestamp;
        uint256 ratePerSecond;
        uint256 maxLimit;
        uint256 currentLimit;
    }

    /// @notice The address of the lockbox contract
    function lockbox() external view returns (address);

    /// @notice Maps bridge address to bridge configurations
    /// @param _bridge The bridge we are viewing the configurations of
    /// @return _minterParams The minting parameters of the bridge
    /// @return _burnerParams The burning parameters of the bridge
    function bridges(address _bridge)
        external
        view
        returns (BridgeParameters memory _minterParams, BridgeParameters memory _burnerParams);

    /// @notice Returns the max limit of a bridge
    /// @param _bridge The bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function mintingMaxLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Returns the max limit of a bridge
    /// @param _bridge the bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function burningMaxLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Returns the current limit of a bridge
    /// @param _bridge The bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function mintingCurrentLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Returns the current limit of a bridge
    /// @param _bridge the bridge we are viewing the limits of
    /// @return _limit The limit the bridge has
    function burningCurrentLimitOf(address _bridge) external view returns (uint256 _limit);

    /// @notice Mints tokens for a user
    /// @dev Can only be called by a bridge
    /// @param _user The address of the user who needs tokens minted
    /// @param _amount The amount of tokens being minted
    function mint(address _user, uint256 _amount) external;

    /// @notice Burns tokens for a user
    /// @dev Can only be called by a bridge
    /// @param _user The address of the user who needs tokens burned
    /// @param _amount The amount of tokens being burned
    function burn(address _user, uint256 _amount) external;

    /// @notice Updates the limits of any bridge
    /// @dev Can only be called by the owner
    /// @param _mintingLimit The updated minting limit we are setting to the bridge
    /// @param _burningLimit The updated burning limit we are setting to the bridge
    /// @param _bridge The address of the bridge we are setting the limits to
    function setLimits(address _bridge, uint256 _mintingLimit, uint256 _burningLimit) external;
}
