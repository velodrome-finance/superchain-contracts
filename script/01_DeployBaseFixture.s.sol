// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "./DeployFixture.sol";

abstract contract DeployBaseFixture is DeployFixture {
    struct DeploymentParameters {
        address weth;
        address poolAdmin;
        address pauser;
        address feeManager;
        address whitelistAdmin;
        address[] whitelistedTokens;
        string outputFilename;
    }

    // deployed
    Pool public poolImplementation;
    PoolFactory public poolFactory;
    Router public router;
    TokenRegistry public tokenRegistry;

    DeploymentParameters internal _params;

    /// @dev Entropy used for deterministic deployments across chains
    bytes11 public constant POOL_ENTROPY = 0x0000000000000000000001;
    bytes11 public constant POOL_FACTORY_ENTROPY = 0x0000000000000000000002;
    bytes11 public constant ROUTER_ENTROPY = 0x0000000000000000000003;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
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

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console2.log("poolImplementation: ", address(poolImplementation));
        console2.log("poolFactory: ", address(poolFactory));
        console2.log("router: ", address(router));
        console2.log("tokenRegistry: ", address(tokenRegistry));
    }

    function logOutput() internal override {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(
            path,
            string(
                abi.encodePacked(
                    stdJson.serialize("", "poolImplementation", address(poolImplementation)),
                    stdJson.serialize("", "poolFactory", address(poolFactory)),
                    stdJson.serialize("", "router", address(router)),
                    stdJson.serialize("", "tokenRegistry", address(tokenRegistry))
                )
            )
        );
    }
}
