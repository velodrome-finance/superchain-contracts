// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IPool, Pool} from "src/pools/Pool.sol";
import {IPoolFactory, PoolFactory} from "src/pools/PoolFactory.sol";
import {IRouter, Router} from "src/Router.sol";
import {IConverter, Converter} from "src/gauges/stakingrewards/Converter.sol";
import {IStakingRewards, StakingRewards} from "src/gauges/stakingrewards/StakingRewards.sol";
import {IStakingRewardsFactory, StakingRewardsFactory} from "src/gauges/stakingrewards/StakingRewardsFactory.sol";
import {ITokenRegistry, TokenRegistry} from "src/gauges/tokenregistry/TokenRegistry.sol";
import {IGauge} from "src/interfaces/gauges/IGauge.sol";
import {Users} from "./utils/Users.sol";
import {Constants} from "./utils/Constants.sol";
import {MockWETH} from "./mocks/MockWETH.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {CreateX} from "./mocks/CreateX.sol";
import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";
import {FeeSharing} from "test/mocks/mode/FeeSharing.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract BaseFixture is Test, Constants {
    using SafeERC20 for TestERC20;

    PoolFactory public poolFactory;
    Pool public poolImplementation;
    StakingRewardsFactory public stakingRewardsFactory;
    TokenRegistry public tokenRegistry;
    Router public router;

    /// tokens
    TestERC20 public rewardToken;
    TestERC20 public token0;
    TestERC20 public token1;
    MockWETH public weth;

    /// mocks
    FeeSharing public fs;
    CreateX public cx = CreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    Users internal users;

    function setUp() public virtual {
        createUsers();

        // run deployments as address(this)
        // at end of deployment, address(this) should have no ownership
        rewardToken = new TestERC20("Reward Token", "RWRD", 18);

        TestERC20 tokenA = new TestERC20("Test Token A", "TTA", 18);
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        weth = new MockWETH();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        deployCreateX();

        // mode mock -- remove when stakingrewards is removed
        fs = new FeeSharing();
        vm.etch(0x8680CEaBcb9b56913c519c069Add6Bc3494B7020, address(fs).code);

        poolImplementation = Pool(
            cx.deployCreate3({salt: calculateSalt(POOL_ENTROPY), initCode: abi.encodePacked(type(Pool).creationCode)})
        );
        poolFactory = PoolFactory(
            cx.deployCreate3({
                salt: calculateSalt(POOL_FACTORY_ENTROPY),
                initCode: abi.encodePacked(
                    type(PoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // pool implementation
                        users.owner, // pool admin
                        users.owner, // pauser
                        users.feeManager // fee manager
                    )
                )
            })
        );

        router = Router(
            payable(
                cx.deployCreate3({
                    salt: calculateSalt(ROUTER_ENTROPY),
                    initCode: abi.encodePacked(
                        type(Router).creationCode,
                        abi.encode(
                            address(poolFactory), // pool factory
                            address(weth) // weth contract
                        )
                    )
                })
            )
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokenRegistry = new TokenRegistry({_admin: users.owner, _whitelistedTokens: tokens});

        stakingRewardsFactory = new StakingRewardsFactory({
            _admin: users.owner,
            _keeperAdmin: users.owner,
            _tokenRegistry: address(tokenRegistry),
            _router: address(router),
            _keepers: new address[](0)
        });

        deal(address(token0), users.alice, TOKEN_1 * 1e9);
        deal(address(token1), users.alice, TOKEN_1 * 1e9);
        deal(address(token0), users.bob, TOKEN_1 * 1e9);
        deal(address(token1), users.bob, TOKEN_1 * 1e9);

        labelContracts();

        skipToNextEpoch(0);
    }

    function labelContracts() public virtual {
        vm.label(address(poolImplementation), "Pool Implementation");
        vm.label(address(poolFactory), "Pool Factory");
        vm.label(address(router), "Router");
        vm.label(address(cx), "CreateX");
    }

    function deployCreateX() internal {
        // identical to CreateX, with versions changed
        deployCodeTo("test/mocks/CreateX.sol", address(cx));
    }

    function calculateSalt(bytes11 entropy) internal view returns (bytes32 salt) {
        salt = bytes32(abi.encodePacked(bytes20(address(this)), bytes1(0x00), bytes11(entropy)));
    }

    function createUsers() internal {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie")
        });
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }

    /// @dev Helper utility to forward time to next week
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 offset) internal {
        uint256 nextEpoch = VelodromeTimeLibrary.epochNext(block.timestamp);
        uint256 newTimestamp = nextEpoch + offset;
        uint256 diff = newTimestamp - block.timestamp;
        vm.warp(newTimestamp);
        vm.roll(block.number + diff / 2);
    }

    function skipAndRoll(uint256 timeOffset) public {
        skip(timeOffset);
        vm.roll(block.number + timeOffset / 2);
    }

    /// @dev Helper function to add rewards to gauge
    function addRewardToGauge(address _gauge, uint256 _amount) internal prank(users.owner) {
        deal(address(rewardToken), users.owner, _amount);
        rewardToken.safeIncreaseAllowance(_gauge, _amount);
        IGauge(_gauge).notifyRewardAmount(_amount);
    }

    /// @dev Helper function to deposit liquidity into pool
    function addLiquidityToPool(
        address _owner,
        address _token0,
        address _token1,
        bool _stable,
        uint256 _amount0,
        uint256 _amount1
    ) internal prank(_owner) {
        bytes32 salt = keccak256(abi.encodePacked(_token0, _token1, _stable));
        address pool = Clones.predictDeterministicAddress({
            implementation: address(poolImplementation),
            salt: salt,
            deployer: address(poolFactory)
        });
        TestERC20(_token0).safeTransfer(pool, _amount0);
        TestERC20(_token1).safeTransfer(pool, _amount1);
        IPool(pool).mint(_owner);
    }

    modifier prank(address _caller) {
        vm.startPrank(_caller);
        _;
        vm.stopPrank();
    }
}
