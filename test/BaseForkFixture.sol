// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin5/contracts/interfaces/draft-IERC6093.sol";
import {TestIsm} from "@hyperlane/core/contracts/test/TestIsm.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";
import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";
import {IBridge, Bridge} from "src/bridge/Bridge.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {IXERC20, XERC20} from "src/xerc20/XERC20.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {IRootPool, RootPool} from "src/mainnet/pools/RootPool.sol";
import {IRootPoolFactory, RootPoolFactory} from "src/mainnet/pools/RootPoolFactory.sol";
import {IRootGauge, RootGauge} from "src/mainnet/gauges/RootGauge.sol";
import {IRootGaugeFactory, RootGaugeFactory} from "src/mainnet/gauges/RootGaugeFactory.sol";
import {ILeafGauge, LeafGauge} from "src/gauges/LeafGauge.sol";
import {ILeafGaugeFactory, LeafGaugeFactory} from "src/gauges/LeafGaugeFactory.sol";
import {IPool, Pool} from "src/pools/Pool.sol";
import {IPoolFactory, PoolFactory} from "src/pools/PoolFactory.sol";

import {CreateX} from "test/mocks/CreateX.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {MultichainMockMailbox} from "test/mocks/MultichainMockMailbox.sol";
import {MockVoter} from "test/mocks/MockVoter.sol";
import {MockFactoryRegistry} from "test/mocks/MockFactoryRegistry.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";
import {Constants} from "test/utils/Constants.sol";
import {Users} from "test/utils/Users.sol";

abstract contract BaseForkFixture is Test, Constants {
    // anything prefixed with origin is deployed on the origin chain
    // anything prefixed with destination is deployed on the destination chain
    // all helper functions return control to the origin fork at end of execution
    // assume all tests start from the origin fork

    // origin contracts
    uint32 public origin = 10;
    uint256 public originId;

    XERC20Factory public originXFactory;
    XERC20 public originXVelo;
    Bridge public originBridge;
    MultichainMockMailbox public originMailbox;
    TestIsm public originIsm;

    // origin-only contracts
    MockVoter public mockVoter;
    MockFactoryRegistry public mockFactoryRegistry;

    XERC20Lockbox public originLockbox;
    TestERC20 public originRewardToken;
    RootPool public originRootPool;
    RootPoolFactory public originRootPoolFactory;
    RootGaugeFactory public originRootGaugeFactory;

    // destination contracts
    uint32 public destination = 34443;
    uint256 public destinationId;
    XERC20Factory public destinationXFactory;
    XERC20 public destinationXVelo;
    Bridge public destinationBridge;
    MultichainMockMailbox public destinationMailbox;
    TestIsm public destinationIsm;

    // destination-only contracts
    PoolFactory public destinationPoolFactory;
    Pool public destinationPool;
    LeafGaugeFactory public destinationLeafGaugeFactory;
    LeafGauge public destinationLeafGauge;

    // common
    TestERC20 public token0;
    TestERC20 public token1;
    MockWETH public weth;
    CreateX public cx = CreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    // used by tests
    /// @dev We reset origin and destination fork start time to the start of the epoch and record it here
    uint256 public originStartTime;
    uint256 public destinationStartTime;

    Users internal users;

    function setUp() public virtual {
        createUsers();

        vm.startPrank(users.deployer);
        setUpPreCommon();
        setUpOriginChain();
        setUpDestinationChain();
        setUpPostCommon();
        vm.stopPrank();

        vm.selectFork({forkId: originId});
    }

    function setUpPreCommon() public virtual {
        originId = vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 123316800});
        deployCreateX();
        /// @dev Tokens do not need to exist on mainnet, only on the superchain
        TestERC20 tokenA = new TestERC20("Test Token A", "TTA", 18);
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        weth = new MockWETH();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        originStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: originStartTime});

        destinationId = vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        deployCreateX();
        tokenA = new TestERC20("Test Token A", "TTA", 18);
        tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        weth = new MockWETH();
        destinationStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: destinationStartTime});
    }

    function setUpOriginChain() public virtual {
        vm.selectFork({forkId: originId});

        mockFactoryRegistry = new MockFactoryRegistry();
        originRootPool = new RootPool();
        originRootPoolFactory = new RootPoolFactory({_implementation: address(originRootPool), _chainId: destination});

        originMailbox = new MultichainMockMailbox(origin);

        originRewardToken = new TestERC20("Reward Token", "RWRD", 18);

        originXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: XERC20_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        address(cx), // create x address
                        users.owner // xerc20 owner address
                    )
                )
            })
        );

        (address _xVelo, address _lockbox) =
            originXFactory.deployXERC20WithLockbox({_erc20: address(originRewardToken)});
        originXVelo = XERC20(_xVelo);
        originLockbox = XERC20Lockbox(_lockbox);
        originIsm = new TestIsm();

        originBridge = Bridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(Bridge).creationCode,
                    abi.encode(
                        address(originXVelo), // xerc20 address
                        address(originMailbox), // mailbox address
                        originIsm // test ism
                    )
                )
            })
        );

        mockVoter =
            new MockVoter({_rewardToken: address(originRewardToken), _factoryRegistry: address(mockFactoryRegistry)});
        originRootGaugeFactory = RootGaugeFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: GAUGE_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootGaugeFactory).creationCode,
                    abi.encode(
                        address(mockVoter), // voter address
                        address(originXVelo), // xerc20 address
                        address(originLockbox), // lockbox address
                        address(originBridge) // bridge address
                    )
                )
            })
        );

        mockFactoryRegistry.approve({
            poolFactory: address(originRootPoolFactory),
            votingRewardsFactory: address(11),
            gaugeFactory: address(originRootGaugeFactory)
        });

        vm.label({account: address(mockVoter), newLabel: "Origin Mock Voter"});
        vm.label({account: address(mockFactoryRegistry), newLabel: "Origin Factory Registry"});
        vm.label({account: address(originRootPool), newLabel: "Origin Root Pool"});
        vm.label({account: address(originRootPoolFactory), newLabel: "Origin Root Pool Factory"});
        vm.label({account: address(originRootGaugeFactory), newLabel: "Origin Root Gauge Factory"});
        vm.label({account: address(originMailbox), newLabel: "Origin Mailbox"});
        vm.label({account: address(originRewardToken), newLabel: "Origin Reward Token"});
        vm.label({account: address(originXFactory), newLabel: "Origin X Factory"});
        vm.label({account: address(originXVelo), newLabel: "Origin XVELO"});
        vm.label({account: address(originLockbox), newLabel: "Origin Lockbox"});
        vm.label({account: address(originIsm), newLabel: "Origin ISM"});
        vm.label({account: address(originBridge), newLabel: "Origin Bridge"});
    }

    function setUpDestinationChain() public virtual {
        vm.selectFork({forkId: destinationId});
        destinationMailbox = new MultichainMockMailbox(destination);

        destinationPool = Pool(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: POOL_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(type(Pool).creationCode)
            })
        );
        destinationPoolFactory = PoolFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: POOL_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(PoolFactory).creationCode,
                    abi.encode(
                        address(destinationPool), // pool implementation
                        users.owner, // pool admin
                        users.owner, // pauser
                        users.feeManager // fee manager
                    )
                )
            })
        );

        destinationXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: XERC20_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        address(cx), // create x address
                        users.owner // xerc20 owner address
                    )
                )
            })
        );

        destinationXVelo = XERC20(destinationXFactory.deployXERC20());
        destinationIsm = new TestIsm();

        destinationBridge = Bridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(Bridge).creationCode,
                    abi.encode(
                        address(destinationXVelo), // xerc20 address
                        address(destinationMailbox), // mailbox address
                        destinationIsm // test ism
                    )
                )
            })
        );

        destinationLeafGaugeFactory = LeafGaugeFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: GAUGE_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(LeafGaugeFactory).creationCode,
                    abi.encode(
                        address(mockVoter), // voter address
                        address(destinationPoolFactory), // pool factory address
                        address(destinationXVelo), // xerc20 address
                        address(destinationBridge) // bridge address
                    )
                )
            })
        );

        vm.label({account: address(destinationMailbox), newLabel: "Destination Mailbox"});
        vm.label({account: address(destinationPool), newLabel: "Destination Pool"});
        vm.label({account: address(destinationPoolFactory), newLabel: "Destination Pool Factory"});
        vm.label({account: address(destinationXFactory), newLabel: "Destination X Factory"});
        vm.label({account: address(destinationXVelo), newLabel: "Destination XVELO"});
        vm.label({account: address(destinationBridge), newLabel: "Destination Bridge"});
        vm.label({account: address(destinationIsm), newLabel: "Destination ISM"});
        vm.label({account: address(destinationLeafGaugeFactory), newLabel: "Destination Leaf Gauge Factory"});
    }

    // Any set up required to link the contracts across the two chains
    function setUpPostCommon() public virtual {
        vm.selectFork({forkId: originId});
        originMailbox.addRemoteMailbox(destination, destinationMailbox);
        originMailbox.setDomainForkId({_domain: destination, _forkId: destinationId});
    }

    function createUsers() internal {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie"),
            deployer: createUser("Deployer")
        });
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }

    function deployCreateX() internal {
        // identical to CreateX, with versions changed
        deployCodeTo("test/mocks/CreateX.sol", address(cx));
    }

    /// @dev Helper function that sets origin minting limit & destination burning limit
    /// @dev and destination minting limit & origin burning limit
    function setLimits(uint256 _originMintingLimit, uint256 _destinationMintingLimit) internal {
        vm.startPrank(users.owner);
        vm.selectFork({forkId: originId});
        originXVelo.setLimits({
            _bridge: address(originBridge),
            _mintingLimit: _originMintingLimit,
            _burningLimit: _destinationMintingLimit
        });
        vm.selectFork({forkId: destinationId});
        destinationXVelo.setLimits({
            _bridge: address(destinationBridge),
            _mintingLimit: _destinationMintingLimit,
            _burningLimit: _originMintingLimit
        });
        vm.selectFork({forkId: originId});
        vm.stopPrank();
    }

    /// @dev Move time forward on all chains
    function skipTime(uint256 _time) internal {
        vm.selectFork({forkId: originId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: destinationId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: originId});
    }
}
