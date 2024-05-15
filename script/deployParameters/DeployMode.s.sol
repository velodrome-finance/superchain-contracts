// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBase} from "../01_DeployBase.s.sol";
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
    address[] public whitelistedTokens = new address[](1);

    ModeStakingRewardsFactory public stakingRewardsFactory;
    ModeStakingRewards public stakingRewards;

    function setUp() public override {
        whitelistedTokens.push(0x4200000000000000000000000000000000000006);

        _params = DeployBase.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x0000000000000000000000000000000000000001,
            pauser: 0x0000000000000000000000000000000000000001,
            feeManager: 0x0000000000000000000000000000000000000001,
            whitelistAdmin: 0x0000000000000000000000000000000000000001,
            whitelistedTokens: whitelistedTokens,
            outputFilename: "Mode.json"
        });
        _modeParams = ModeDeploymentParameters({
            sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020,
            recipient: 0x0000000000000000000000000000000000000001,
            keeperAdmin: 0x0000000000000000000000000000000000000001,
            notifyAdmin: 0x0000000000000000000000000000000000000001,
            admin: 0x0000000000000000000000000000000000000001,
            rewardToken: 0x0000000000000000000000000000000000000001
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
    }

    function modeParams() public view returns (ModeDeploymentParameters memory) {
        return _modeParams;
    }
}
