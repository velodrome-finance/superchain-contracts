// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../01_DeployBaseFixture.s.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";

contract DeployBase is DeployBaseFixture {
    using CreateXLibrary for bytes11;

    struct ModeDeploymentParameters {
        address sfs;
        address recipient;
    }

    ModeDeploymentParameters internal _modeParams;
    address[] public whitelistedTokens = new address[](15);

    function setUp() public override {
        whitelistedTokens.push(0x4200000000000000000000000000000000000006);
        whitelistedTokens.push(0xDfc7C877a950e49D2610114102175A06C2e3167a);
        whitelistedTokens.push(0x59889b7021243dB5B1e065385F918316cD90D46c);
        whitelistedTokens.push(0x4186BFC76E2E237523CBC30FD220FE055156b41F);
        whitelistedTokens.push(0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd);
        whitelistedTokens.push(0x2416092f143378750bb29b79eD961ab195CcEea5);
        whitelistedTokens.push(0x80137510979822322193FC997d400D5A6C747bf7);
        whitelistedTokens.push(0xd988097fb8612cc24eeC14542bC03424c656005f);
        whitelistedTokens.push(0xf0F161fDA2712DB8b566946122a5af183995e2eD);
        whitelistedTokens.push(0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A);
        whitelistedTokens.push(0xcDd475325D6F564d27247D1DddBb0DAc6fA0a5CF);
        whitelistedTokens.push(0x9e5AAC1Ba1a2e6aEd6b32689DFcF62A509Ca96f3);
        whitelistedTokens.push(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
        whitelistedTokens.push(0xE7798f023fC62146e8Aa1b36Da45fb70855a77Ea);
        whitelistedTokens.push(0x18470019bF0E94611f15852F7e93cf5D65BC34CA);

        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            pauser: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            feeManager: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            whitelistAdmin: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            tokenAdmin: 0x0000000000000000000000000000000000000001,
            whitelistedTokens: whitelistedTokens,
            outputFilename: "mode.json"
        });
        _modeParams = ModeDeploymentParameters({
            sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020,
            recipient: 0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3
        });
    }

    function deploy() internal override {
        address _deployer = deployer;

        poolImplementation = ModePool(
            cx.deployCreate3({
                salt: POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(ModePool).creationCode)
            })
        );
        checkAddress({_entropy: POOL_ENTROPY, _output: address(poolImplementation)});

        poolFactory = ModePoolFactory(
            cx.deployCreate3({
                salt: POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(ModePoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // pool implementation
                        _params.poolAdmin, // pool admin
                        _params.pauser, // pauser
                        _params.feeManager, // fee manager
                        _modeParams.sfs, // sequencer fee sharing contract
                        _modeParams.recipient // sfs nft recipient
                    )
                )
            })
        );
        checkAddress({_entropy: POOL_FACTORY_ENTROPY, _output: address(poolFactory)});

        router = ModeRouter(
            payable(
                cx.deployCreate3({
                    salt: ROUTER_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(ModeRouter).creationCode,
                        abi.encode(
                            address(poolFactory), // pool factory
                            _params.weth, // weth contract
                            _modeParams.sfs, // sequencer fee sharing contract
                            _modeParams.recipient // sfs nft recipient
                        )
                    )
                })
            )
        );
        checkAddress({_entropy: ROUTER_ENTROPY, _output: address(router)});

        xerc20Factory = XERC20Factory(
            cx.deployCreate3({
                salt: XERC20_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        address(cx), // create x address
                        _params.tokenAdmin // xerc20 owner
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(xerc20Factory)});
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
