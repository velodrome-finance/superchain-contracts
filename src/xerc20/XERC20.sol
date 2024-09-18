// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

import {ERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin5/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeCast} from "@openzeppelin5/contracts/utils/math/SafeCast.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";
import {MintLimits} from "./MintLimits.sol";

import {RateLimitMidPoint} from "../libraries/rateLimits/RateLimitMidpointCommonLibrary.sol";

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

██╗  ██╗███████╗██████╗  ██████╗██████╗  ██████╗
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝╚════██╗██╔═████╗
 ╚███╔╝ █████╗  ██████╔╝██║      █████╔╝██║██╔██║
 ██╔██╗ ██╔══╝  ██╔══██╗██║     ██╔═══╝ ████╔╝██║
██╔╝ ██╗███████╗██║  ██║╚██████╗███████╗╚██████╔╝
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝

*/

/// @title XERC20
/// @notice Extension of ERC20 for bridged tokens
contract XERC20 is ERC20, Ownable, IXERC20, ERC20Permit, MintLimits {
    using SafeCast for uint256;

    /// @inheritdoc IXERC20
    address public immutable lockbox;

    /// @notice maximum rate limit per second is 25k
    uint128 public constant MAX_RATE_LIMIT_PER_SECOND = 25_000 * 1e18;

    /// @notice minimum buffer cap
    uint112 public constant MIN_BUFFER_CAP = 1_000 * 1e18;

    /// @notice Constructs the initial config of the XERC20
    /// @param _name The name of the token
    /// @param _symbol The symbol of the token
    /// @param _owner The manager of the xerc20 token
    /// @param _lockbox The lockbox corresponding to the token
    constructor(string memory _name, string memory _symbol, address _owner, address _lockbox)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(_owner)
    {
        lockbox = _lockbox;
    }

    /// @inheritdoc IXERC20
    function mint(address _user, uint256 _amount) public {
        _mintWithCaller(msg.sender, _user, _amount);
    }

    /// @inheritdoc IXERC20
    function burn(address _user, uint256 _amount) public {
        if (msg.sender != _user) {
            _spendAllowance(_user, msg.sender, _amount);
        }

        _burnWithCaller(msg.sender, _user, _amount);
    }

    /// @inheritdoc IXERC20
    function setBufferCap(address _bridge, uint256 _newBufferCap) public onlyOwner {
        _setBufferCap(_bridge, _newBufferCap.toUint112());

        emit BridgeLimitsSet(_bridge, _newBufferCap);
    }

    /// @inheritdoc IXERC20
    function setRateLimitPerSecond(address _bridge, uint128 _newRateLimitPerSecond) external onlyOwner {
        _setRateLimitPerSecond(_bridge, _newRateLimitPerSecond);
    }

    /// @inheritdoc IXERC20
    function addBridge(RateLimitMidPointInfo memory _newBridge) external onlyOwner {
        _addLimit(_newBridge);
    }

    /// @inheritdoc IXERC20
    function removeBridge(address _bridge) external onlyOwner {
        _removeLimit(_bridge);
    }

    /// @inheritdoc IXERC20
    function rateLimits(address _bridge) external view returns (RateLimitMidPoint memory) {
        return _rateLimits[_bridge];
    }

    /// @inheritdoc MintLimits
    function maxRateLimitPerSecond() public pure override returns (uint128) {
        return MAX_RATE_LIMIT_PER_SECOND;
    }

    /// @inheritdoc MintLimits
    function minBufferCap() public pure override returns (uint112) {
        return MIN_BUFFER_CAP;
    }

    /// @inheritdoc IXERC20
    function mintingMaxLimitOf(address _bridge) external view returns (uint256 _limit) {
        _limit = bufferCap(_bridge);
    }

    /// @inheritdoc IXERC20
    function burningMaxLimitOf(address _bridge) external view returns (uint256 _limit) {
        _limit = bufferCap(_bridge);
    }

    /// @inheritdoc IXERC20
    function mintingCurrentLimitOf(address _bridge) public view returns (uint256 _limit) {
        _limit = buffer(_bridge);
    }

    /// @inheritdoc IXERC20
    function burningCurrentLimitOf(address _bridge) public view returns (uint256 _limit) {
        // buffer <= bufferCap, so this can never revert, just return 0
        _limit = bufferCap(_bridge) - buffer(_bridge);
    }

    /// @notice Internal function for burning tokens
    /// @param _caller The caller address
    /// @param _user The user address
    /// @param _amount The amount to burn
    function _burnWithCaller(address _caller, address _user, uint256 _amount) internal {
        if (_caller != lockbox) {
            /// first replenish buffer for the minter if not at max
            /// unauthorized sender reverts
            _replenishBuffer(_caller, _amount);
        }
        _burn(_user, _amount);
    }

    /// @notice Internal function for minting tokens
    /// @param _caller The caller address
    /// @param _user The user address
    /// @param _amount The amount to mint
    function _mintWithCaller(address _caller, address _user, uint256 _amount) internal {
        if (_caller != lockbox) {
            /// first deplete buffer for the minter if not at max
            _depleteBuffer(_caller, _amount);
        }
        _mint(_user, _amount);
    }
}
