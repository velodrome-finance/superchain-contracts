// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../01_DeployBase.s.sol";
import {ModePool} from "src/pools/extensions/ModePool.sol";
import {ModePoolFactory} from "src/pools/extensions/ModePoolFactory.sol";
import {ModeRouter} from "src/extensions/ModeRouter.sol";
import {ModeStakingRewardsFactory} from "src/gauges/stakingrewards/extensions/ModeStakingRewardsFactory.sol";
import {ModeStakingRewards} from "src/gauges/stakingrewards/extensions/ModeStakingRewards.sol";
import {TokenRegistry} from "src/gauges/tokenregistry/TokenRegistry.sol";

contract DeployMode is DeployBase {
    struct ModeDeploymentParameters {
        address sfs;
        address recipient;
        address keeperAdmin;
        address notifyAdmin;
        address admin;
        address rewardToken;
    }

    ModeDeploymentParameters internal _modeParams;
    address[] public whitelistedTokens = new address[](15);

    ModeStakingRewardsFactory public stakingRewardsFactory;
    ModeStakingRewards public stakingRewards;

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

        _params = DeployBase.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            pauser: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            feeManager: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            whitelistAdmin: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            whitelistedTokens: whitelistedTokens,
            outputFilename: "Mode.json"
        });
        _modeParams = ModeDeploymentParameters({
            sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020,
            recipient: 0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3,
            keeperAdmin: 0xb32Db5b848B837DC39EF20B4110dFAc7493e93ed,
            notifyAdmin: 0xA6074AcC04DeAb343881882c896555A1Ba2E9d46,
            admin: 0x5d496974832B8BC3c02F89E7Ac0b7579b4d1cC09,
            rewardToken: 0xDfc7C877a950e49D2610114102175A06C2e3167a
        });
    }

    function deploy() internal override {
        bytes32 salt;

        salt = calculateSalt(POOL_ENTROPY);
        poolImplementation =
            ModePool(cx.deployCreate3({salt: salt, initCode: abi.encodePacked(type(ModePool).creationCode)}));
        checkAddress({salt: salt, output: address(poolImplementation)});

        salt = calculateSalt(POOL_FACTORY_ENTROPY);
        poolFactory = ModePoolFactory(
            cx.deployCreate3({
                salt: salt,
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
        checkAddress({salt: salt, output: address(poolFactory)});

        salt = calculateSalt(ROUTER_ENTROPY);
        router = ModeRouter(
            payable(
                cx.deployCreate3({
                    salt: salt,
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
        checkAddress({salt: salt, output: address(router)});

        tokenRegistry =
            new TokenRegistry({_admin: _params.whitelistAdmin, _whitelistedTokens: _params.whitelistedTokens});

        stakingRewardsFactory = new ModeStakingRewardsFactory({
            _admin: _modeParams.admin,
            _notifyAdmin: _modeParams.notifyAdmin,
            _keeperAdmin: _modeParams.keeperAdmin,
            _tokenRegistry: address(tokenRegistry),
            _rewardToken: _modeParams.rewardToken,
            _router: address(router),
            _sfs: _modeParams.sfs,
            _recipient: _modeParams.recipient,
            _keepers: new address[](0)
        });

        console2.log("TokenRegistry deployed at: ", address(tokenRegistry));
        console2.log("StakingRewardsFactory deployed at: ", address(stakingRewardsFactory));
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
