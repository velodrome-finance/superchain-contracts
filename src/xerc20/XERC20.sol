// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {ERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin5/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeCast} from "@openzeppelin5/contracts/utils/math/SafeCast.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {ISuperchainERC20} from "../interfaces/xerc20/ISuperchainERC20.sol";
import {ICrosschainERC20} from "../interfaces/xerc20/ICrosschainERC20.sol";
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

/// @title XERC20 with CrosschainERC20 support
/// @author Lunar Enterprise Ventures, Ltd., velodrome.finance
/// @notice Extension of ERC20 for bridged tokens
contract XERC20 is ERC20, Ownable, IXERC20, ERC20Permit, MintLimits, ISuperchainERC20 {
    using SafeCast for uint256;

    /// @inheritdoc IXERC20
    address public immutable lockbox;
    /// @inheritdoc ISuperchainERC20
    address public constant SUPERCHAIN_ERC20_BRIDGE = 0x4200000000000000000000000000000000000028;

    /// @notice maximum rate limit per second is 25k
    uint128 public constant MAX_RATE_LIMIT_PER_SECOND = 25_000 * 1e6;

    /// @notice minimum buffer cap
    uint112 public constant MIN_BUFFER_CAP = 1_000 * 1e6;

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

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    modifier onlySuperchainERC20Bridge() {
        if (msg.sender != SUPERCHAIN_ERC20_BRIDGE) revert OnlySuperchainERC20Bridge();
        _;
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

    /// @inheritdoc ICrosschainERC20
    function crosschainMint(address _to, uint256 _amount) external onlySuperchainERC20Bridge {
        _depleteBuffer(msg.sender, _amount);
        _mint(_to, _amount);

        emit CrosschainMint(_to, _amount);
    }

    /// @inheritdoc ICrosschainERC20
    function crosschainBurn(address _from, uint256 _amount) external onlySuperchainERC20Bridge {
        _spendAllowance(_from, msg.sender, _amount);
        _replenishBuffer(msg.sender, _amount);
        _burn(_from, _amount);

        emit CrosschainBurn(_from, _amount);
    }
}
