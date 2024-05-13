// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ICreateX} from "createX/ICreateX.sol";
import {Pool} from "src/pools/Pool.sol";
import {PoolFactory} from "src/pools/PoolFactory.sol";
import {Router} from "src/Router.sol";
import {TokenRegistry} from "src/gauges/tokenregistry/TokenRegistry.sol";

abstract contract DeployBase is Script {
    error InvalidAddress(address expected, address output);

    struct DeploymentParameters {
        address weth;
        address poolAdmin;
        address pauser;
        address feeManager;
        address whitelistAdmin;
        address[] whitelistedTokens;
        string outputFilename;
    }

    DeploymentParameters internal _params;

    // deployed
    Pool public poolImplementation;
    PoolFactory public poolFactory;
    Router public router;
    TokenRegistry public tokenRegistry;

    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    address public deployer = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;

    /// @dev Entropy used for deterministic deployments across chains
    bytes11 public constant POOL_ENTROPY = 0x0000000000000000000001;
    bytes11 public constant POOL_FACTORY_ENTROPY = 0x0000000000000000000002;
    bytes11 public constant ROUTER_ENTROPY = 0x0000000000000000000003;

    function setUp() public virtual;

    function run() external {
        vm.startBroadcast(deployer);
        verifyCreate3();

        deploy();
        logParams();

        vm.stopBroadcast();
    }

    /// @dev Override if deploying extensions
    function deploy() internal virtual {
        bytes32 salt;

        salt = calculateSalt(POOL_ENTROPY);
        poolImplementation = Pool(cx.deployCreate3({salt: salt, initCode: abi.encodePacked(type(Pool).creationCode)}));
        checkAddress({salt: salt, output: address(poolImplementation)});

        salt = calculateSalt(POOL_FACTORY_ENTROPY);
        poolFactory = PoolFactory(
            cx.deployCreate3({
                salt: salt,
                initCode: abi.encodePacked(
                    type(PoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // pool implementation
                        _params.poolAdmin, // pool admin
                        _params.pauser, // pauser
                        _params.feeManager // fee manager
                    )
                )
            })
        );
        checkAddress({salt: salt, output: address(poolFactory)});

        salt = calculateSalt(ROUTER_ENTROPY);
        router = Router(
            payable(
                cx.deployCreate3({
                    salt: salt,
                    initCode: abi.encodePacked(
                        type(Router).creationCode,
                        abi.encode(
                            address(poolFactory), // pool factory
                            _params.weth // weth contract
                        )
                    )
                })
            )
        );
        checkAddress({salt: salt, output: address(router)});

        tokenRegistry =
            new TokenRegistry({_admin: _params.whitelistAdmin, _whitelistedTokens: _params.whitelistedTokens});
    }

    /// @dev Check if the computed address matches the address produced by the deployment
    function checkAddress(bytes32 salt, address output) internal {
        bytes32 guardedSalt = keccak256(abi.encodePacked(uint256(uint160(deployer)), salt));
        address computedAddress = cx.computeCreate3Address({salt: guardedSalt, deployer: address(cx)});
        if (computedAddress != output) {
            revert InvalidAddress(computedAddress, output);
        }
    }

    function verifyCreate3() internal view {
        /// if not run locally
        if (block.chainid != 31337) {
            uint256 size;
            address contractAddress = address(cx);
            assembly {
                size := extcodesize(contractAddress)
            }

            bytes memory bytecode = new bytes(size);
            assembly {
                extcodecopy(contractAddress, add(bytecode, 32), 0, size)
            }

            assert(keccak256(bytecode) == bytes32(0xbd8a7ea8cfca7b4e5f5041d7d4b17bc317c5ce42cfbc42066a00cf26b43eb53f));
        }
    }

    function calculateSalt(bytes11 entropy) internal view returns (bytes32 salt) {
        salt = bytes32(abi.encodePacked(bytes20(deployer), bytes1(0x00), bytes11(entropy)));
    }

    function logParams() internal view {
        console2.log("poolImplementation: ", address(poolImplementation));
        console2.log("poolFactory: ", address(poolFactory));
        console2.log("router: ", address(router));
    }

    function logOutput() internal {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses", _params.outputFilename));
        vm.writeJson(
            path,
            string(
                abi.encodePacked(
                    stdJson.serialize("", "poolImplementation", address(poolImplementation)),
                    stdJson.serialize("", "poolFactory", address(poolFactory)),
                    stdJson.serialize("", "router", address(router))
                )
            )
        );
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }
}
