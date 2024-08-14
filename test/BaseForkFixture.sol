// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/console2.sol";
import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin5/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {TestIsm} from "@hyperlane/core/contracts/test/TestIsm.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";
import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {IXERC20, XERC20} from "src/xerc20/XERC20.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {IRootPool, RootPool} from "src/mainnet/pools/RootPool.sol";
import {IRootPoolFactory, RootPoolFactory} from "src/mainnet/pools/RootPoolFactory.sol";
import {IRootGauge, RootGauge} from "src/mainnet/gauges/RootGauge.sol";
import {IRootGaugeFactory, RootGaugeFactory} from "src/mainnet/gauges/RootGaugeFactory.sol";
import {ILeafVoter, LeafVoter} from "src/voter/LeafVoter.sol";
import {ILeafGauge, LeafGauge} from "src/gauges/LeafGauge.sol";
import {ILeafGaugeFactory, LeafGaugeFactory} from "src/gauges/LeafGaugeFactory.sol";
import {IPool, Pool} from "src/pools/Pool.sol";
import {IPoolFactory, PoolFactory} from "src/pools/PoolFactory.sol";
import {IBridge, Bridge} from "src/bridge/Bridge.sol";
import {IUserTokenBridge, TokenBridge} from "src/bridge/TokenBridge.sol";
import {IMessageBridge, MessageBridge} from "src/bridge/MessageBridge.sol";
import {HLUserTokenBridge} from "src/bridge/hyperlane/HLUserTokenBridge.sol";
import {IHLTokenBridge, HLTokenBridge} from "src/bridge/hyperlane/HLTokenBridge.sol";
import {IHLMessageBridge, HLMessageBridge} from "src/bridge/hyperlane/HLMessageBridge.sol";

import {CreateX} from "test/mocks/CreateX.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {MultichainMockMailbox} from "test/mocks/MultichainMockMailbox.sol";
import {MockVoter} from "test/mocks/MockVoter.sol";
import {MockFactoryRegistry} from "test/mocks/MockFactoryRegistry.sol";
import {MockVotingRewardsFactory} from "test/mocks/MockVotingRewardsFactory.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";
import {TestConstants} from "test/utils/TestConstants.sol";
import {MockMessageReceiver} from "test/mocks/MockMessageReceiver.sol";
import {Users} from "test/utils/Users.sol";

abstract contract BaseForkFixture is Test, TestConstants {
    // anything prefixed with root is deployed on the root chain
    // anything prefixed with leaf is deployed on the leaf chain
    // in the context of velodrome superchain, the root chain will always be optimism (chainid=10)
    // leaf chains will be any chain that velodrome expands to

    // all helper functions return control to the root fork at end of execution
    // assume all tests start from the root fork
    // contracts in {root/leaf} superchain contracts run identical code (with different constructor / initialization args)
    // contracts in {root/leaf}-only contracts run different code (but all code on each leaf chain will run the same code w/ different args)
    // contracts in {root}-only mocks are mock contracts and not part of the superchain deployment

    // root variables
    uint32 public root = 10; // root chain id
    uint256 public rootId; // root fork id (used by foundry)
    uint256 public rootStartTime; // root fork start time (set to start of epoch for simplicity)

    // root superchain contracts
    XERC20Factory public rootXFactory;
    XERC20 public rootXVelo;
    Bridge public rootBridge;
    HLTokenBridge public rootModule;
    TokenBridge public rootTokenBridge;
    HLUserTokenBridge public rootTokenModule;
    MessageBridge public rootMessageBridge;
    HLMessageBridge public rootMessageModule;

    // root-only contracts
    XERC20Lockbox public rootLockbox;
    RootPool public rootPool;
    RootPoolFactory public rootPoolFactory;
    RootGaugeFactory public rootGaugeFactory;
    RootGauge public rootGauge;

    // root-only mocks
    TestERC20 public rootRewardToken;
    MockVoter public mockVoter;
    MockFactoryRegistry public mockFactoryRegistry;
    MultichainMockMailbox public rootMailbox;
    TestIsm public rootIsm;

    // leaf variables
    uint32 public leaf = 34443; // leaf chain id
    uint256 public leafId; // leaf fork id (used by foundry)
    uint256 public leafStartTime; // leaf fork start time (set to start of epoch for simplicity)

    // leaf superchain contracts
    XERC20Factory public leafXFactory;
    XERC20 public leafXVelo;
    Bridge public leafBridge;
    HLTokenBridge public leafModule;
    TokenBridge public leafTokenBridge;
    HLUserTokenBridge public leafTokenModule;
    MessageBridge public leafMessageBridge;
    HLMessageBridge public leafMessageModule;

    // leaf-only contracts
    PoolFactory public leafPoolFactory;
    Pool public leafPool;
    LeafGaugeFactory public leafGaugeFactory;
    LeafGauge public leafGauge;
    LeafVoter public leafVoter;

    // leaf-only mocks
    TestERC20 public token0;
    TestERC20 public token1;
    MultichainMockMailbox public leafMailbox;
    MockFactoryRegistry public leafMockFactoryRegistry;
    MockVotingRewardsFactory public leafMockRewardsFactory;
    TestIsm public leafIsm;

    // common contracts
    MockWETH public weth;
    CreateX public cx = CreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    // common variables
    Users internal users;

    function setUp() public virtual {
        createUsers();

        setUpPreCommon();
        setUpRootChain();
        setUpLeafChain();
        setUpPostCommon();

        vm.selectFork({forkId: rootId});
    }

    function setUpPreCommon() public virtual {
        vm.startPrank(users.owner);
        rootId = vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 123316800});
        deployCreateX();
        weth = new MockWETH();
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: rootStartTime});

        leafId = vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        deployCreateX();
        weth = new MockWETH();

        TestERC20 tokenA = new TestERC20("Test Token A", "TTA", 18);
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        leafStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: leafStartTime});
        vm.stopPrank();
    }

    function setUpRootChain() public virtual {
        vm.selectFork({forkId: rootId});

        // deploy root mocks
        vm.startPrank(users.owner);
        rootMailbox = new MultichainMockMailbox(root);
        rootIsm = new TestIsm();
        rootRewardToken = new TestERC20("Reward Token", "RWRD", 18);
        mockFactoryRegistry = new MockFactoryRegistry();
        mockVoter =
            new MockVoter({_rewardToken: address(rootRewardToken), _factoryRegistry: address(mockFactoryRegistry)});
        vm.stopPrank();

        // deploy root contracts
        vm.startPrank(users.deployer);
        rootPool = new RootPool();
        rootPoolFactory = new RootPoolFactory({_implementation: address(rootPool), _chainId: leaf});

        rootXFactory = XERC20Factory(
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

        (address _xVelo, address _lockbox) = rootXFactory.deployXERC20WithLockbox({_erc20: address(rootRewardToken)});
        rootXVelo = XERC20(_xVelo);
        rootLockbox = XERC20Lockbox(_lockbox);

        rootModule = HLTokenBridge(
            CreateXLibrary.computeCreate3Address({_entropy: HL_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        rootBridge = Bridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(Bridge).creationCode,
                    abi.encode(
                        users.owner, // bridge owner
                        address(rootXVelo), // xerc20 address
                        address(rootModule) // module
                    )
                )
            })
        );
        rootModule = HLTokenBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLTokenBridge).creationCode,
                    abi.encode(address(rootBridge), address(rootMailbox), address(rootIsm))
                )
            })
        );
        rootMessageModule = HLMessageBridge(
            CreateXLibrary.computeCreate3Address({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        rootMessageBridge = MessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(MessageBridge).creationCode,
                    abi.encode(
                        users.owner, // message bridge owner
                        address(rootMessageModule) // message module
                    )
                )
            })
        );
        rootMessageModule = HLMessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLMessageBridge).creationCode,
                    abi.encode(address(rootMessageBridge), address(rootMailbox), address(rootIsm))
                )
            })
        );
        rootTokenModule = HLUserTokenBridge(
            CreateXLibrary.computeCreate3Address({_entropy: HL_USER_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        rootTokenBridge = TokenBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(TokenBridge).creationCode,
                    abi.encode(
                        users.owner, // bridge owner
                        address(rootXVelo), // xerc20 address
                        address(rootTokenModule) // module
                    )
                )
            })
        );
        rootTokenModule = HLUserTokenBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_USER_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLUserTokenBridge).creationCode,
                    abi.encode(address(rootTokenBridge), address(rootMailbox), address(rootIsm))
                )
            })
        );

        rootGaugeFactory = RootGaugeFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: GAUGE_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootGaugeFactory).creationCode,
                    abi.encode(
                        address(mockVoter), // voter address
                        address(rootXVelo), // xerc20 address
                        address(rootLockbox), // lockbox address
                        address(rootBridge) // bridge address
                    )
                )
            })
        );

        mockFactoryRegistry.approve({
            poolFactory: address(rootPoolFactory),
            votingRewardsFactory: address(11),
            gaugeFactory: address(rootGaugeFactory)
        });
        vm.stopPrank();

        vm.label({account: address(rootMailbox), newLabel: "Root Mailbox"});
        vm.label({account: address(rootIsm), newLabel: "Root ISM"});
        vm.label({account: address(rootRewardToken), newLabel: "Root Reward Token"});
        vm.label({account: address(mockFactoryRegistry), newLabel: "Root Factory Registry"});
        vm.label({account: address(mockVoter), newLabel: "Root Mock Voter"});
        vm.label({account: address(rootLockbox), newLabel: "Root Lockbox"});

        vm.label({account: address(rootPool), newLabel: "Pool"});
        vm.label({account: address(rootPoolFactory), newLabel: "Pool Factory"});
        vm.label({account: address(rootGaugeFactory), newLabel: "Gauge Factory"});
        vm.label({account: address(rootXFactory), newLabel: "X Factory"});
        vm.label({account: address(rootXVelo), newLabel: "XVELO"});
        vm.label({account: address(rootTokenBridge), newLabel: "Token Bridge"});
        vm.label({account: address(rootTokenModule), newLabel: "Token Module"});
        vm.label({account: address(rootBridge), newLabel: "Gauge Token Bridge"});
        vm.label({account: address(rootModule), newLabel: "Gauge Token Module"});
        vm.label({account: address(rootMessageBridge), newLabel: "Message Bridge"});
        vm.label({account: address(rootMessageModule), newLabel: "Message Module"});
    }

    function setUpLeafChain() public virtual {
        vm.selectFork({forkId: leafId});

        // deploy leaf mocks
        // use deployer here to ensure addresses are different from the root mocks
        // this helps with labeling
        vm.startPrank(users.deployer);
        leafMailbox = new MultichainMockMailbox(leaf);
        leafIsm = new TestIsm();
        leafMockFactoryRegistry = new MockFactoryRegistry();
        leafMockRewardsFactory = new MockVotingRewardsFactory();
        leafVoter = new LeafVoter({_factoryRegistry: address(leafMockFactoryRegistry), _emergencyCouncil: users.owner});
        vm.stopPrank();

        vm.startPrank(users.deployer);
        leafPool = Pool(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: POOL_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(type(Pool).creationCode)
            })
        );
        leafPoolFactory = PoolFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: POOL_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(PoolFactory).creationCode,
                    abi.encode(
                        address(leafPool), // pool implementation
                        users.owner, // pool admin
                        users.owner, // pauser
                        users.feeManager // fee manager
                    )
                )
            })
        );

        leafXFactory = XERC20Factory(
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

        leafXVelo = XERC20(leafXFactory.deployXERC20());

        leafModule = HLTokenBridge(
            CreateXLibrary.computeCreate3Address({_entropy: HL_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        leafBridge = Bridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(Bridge).creationCode,
                    abi.encode(
                        users.owner, // bridge owner
                        address(leafXVelo), // xerc20 address
                        address(leafModule) // module
                    )
                )
            })
        );
        leafModule = HLTokenBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLTokenBridge).creationCode,
                    abi.encode(address(leafBridge), address(leafMailbox), address(leafIsm))
                )
            })
        );
        leafMessageModule = HLMessageBridge(
            CreateXLibrary.computeCreate3Address({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        leafMessageBridge = MessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(MessageBridge).creationCode,
                    abi.encode(
                        users.owner, // message bridge owner
                        address(leafMessageModule) // message module
                    )
                )
            })
        );
        leafMessageModule = HLMessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLMessageBridge).creationCode,
                    abi.encode(address(leafMessageBridge), address(leafMailbox), address(leafIsm))
                )
            })
        );
        leafTokenModule = HLUserTokenBridge(
            CreateXLibrary.computeCreate3Address({_entropy: HL_USER_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        leafTokenBridge = TokenBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(TokenBridge).creationCode,
                    abi.encode(
                        users.owner, // bridge owner
                        address(leafXVelo), // xerc20 address
                        address(leafTokenModule) // module
                    )
                )
            })
        );
        leafTokenModule = HLUserTokenBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_USER_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLUserTokenBridge).creationCode,
                    abi.encode(address(leafTokenBridge), address(leafMailbox), address(leafIsm))
                )
            })
        );

        leafGaugeFactory = LeafGaugeFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: GAUGE_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(LeafGaugeFactory).creationCode,
                    abi.encode(
                        address(mockVoter), // voter address
                        address(leafPoolFactory), // pool factory address
                        address(leafXVelo), // xerc20 address
                        address(leafBridge) // bridge address
                    )
                )
            })
        );

        leafMockFactoryRegistry.approve({
            poolFactory: address(leafPoolFactory),
            votingRewardsFactory: address(leafMockRewardsFactory),
            gaugeFactory: address(leafGaugeFactory)
        });
        vm.stopPrank();

        vm.label({account: address(leafMailbox), newLabel: "Leaf Mailbox"});
        vm.label({account: address(leafIsm), newLabel: "Leaf ISM"});
        vm.label({account: address(leafMockFactoryRegistry), newLabel: "Leaf Factory Registry"});
        vm.label({account: address(leafMockRewardsFactory), newLabel: "Leaf Mock Rewards Factory"});
        vm.label({account: address(leafVoter), newLabel: "Leaf Voter"});
    }

    // Any set up required to link the contracts across the two chains
    function setUpPostCommon() public virtual {
        vm.selectFork({forkId: rootId});
        rootMailbox.addRemoteMailbox(leaf, leafMailbox);
        rootMailbox.setDomainForkId({_domain: leaf, _forkId: leafId});

        // set up root pool & gauge
        rootPool =
            RootPool(rootPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false}));
        rootGauge = RootGauge(mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(rootPool)}));

        // set up leaf pool & gauge
        vm.selectFork({forkId: leafId});
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false}));
        leafGauge = LeafGauge(leafVoter.createGauge({_poolFactory: address(leafPoolFactory), _pool: address(leafPool)}));
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

    /// @dev Helper function that sets root minting limit & leaf burning limit
    /// @dev and leaf minting limit & root burning limit
    function setLimits(uint256 _rootMintingLimit, uint256 _leafMintingLimit) internal {
        vm.stopPrank();
        uint256 activeFork = vm.activeFork();
        vm.startPrank(users.owner);
        vm.selectFork({forkId: rootId});
        rootXVelo.setLimits({
            _bridge: address(rootBridge),
            _mintingLimit: _rootMintingLimit,
            _burningLimit: _leafMintingLimit
        });
        rootXVelo.setLimits({
            _bridge: address(rootTokenBridge),
            _mintingLimit: _rootMintingLimit,
            _burningLimit: _leafMintingLimit
        });
        vm.selectFork({forkId: leafId});
        leafXVelo.setLimits({
            _bridge: address(leafBridge),
            _mintingLimit: _leafMintingLimit,
            _burningLimit: _rootMintingLimit
        });
        leafXVelo.setLimits({
            _bridge: address(leafTokenBridge),
            _mintingLimit: _leafMintingLimit,
            _burningLimit: _rootMintingLimit
        });
        vm.selectFork({forkId: activeFork});
        vm.stopPrank();
    }

    /// @dev Move time forward on all chains
    function skipTime(uint256 _time) internal {
        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: rootId});
    }
}
