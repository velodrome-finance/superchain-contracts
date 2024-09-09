// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/console2.sol";
import {IVoter} from "src/interfaces/external/IVoter.sol";
import {IVotingEscrow} from "src/interfaces/external/IVotingEscrow.sol";
import {IFactoryRegistry} from "src/interfaces/external/IFactoryRegistry.sol";
import {IWETH} from "src/interfaces/external/IWETH.sol";

import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin5/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {IERC20, IERC20Errors} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {TestIsm} from "@hyperlane/core/contracts/test/TestIsm.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";
import {Commands} from "src/libraries/Commands.sol";

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
import {IRouter, Router} from "src/Router.sol";
import {IPoolFactory, PoolFactory} from "src/pools/PoolFactory.sol";
import {IBridge, Bridge} from "src/bridge/Bridge.sol";
import {IUserTokenBridge, TokenBridge} from "src/bridge/TokenBridge.sol";
import {IMessageBridge, MessageBridge} from "src/bridge/MessageBridge.sol";
import {IRootMessageBridge, RootMessageBridge} from "src/mainnet/bridge/RootMessageBridge.sol";
import {HLUserTokenBridge} from "src/bridge/hyperlane/HLUserTokenBridge.sol";
import {IHLHandler} from "src/interfaces/bridge/hyperlane/IHLHandler.sol";
import {IHLTokenBridge, HLTokenBridge} from "src/bridge/hyperlane/HLTokenBridge.sol";
import {IHLMessageBridge, HLMessageBridge} from "src/bridge/hyperlane/HLMessageBridge.sol";
import {IVotingRewardsFactory, VotingRewardsFactory} from "src/rewards/VotingRewardsFactory.sol";
import {IChainRegistry} from "src/interfaces/bridge/IChainRegistry.sol";

import {IMessageSender, RootHLMessageBridge} from "src/mainnet/bridge/hyperlane/RootHLMessageBridge.sol";
import {RootHLTokenBridge} from "src/mainnet/bridge/hyperlane/RootHLTokenBridge.sol";

import {IRootVotingRewardsFactory, RootVotingRewardsFactory} from "src/mainnet/rewards/RootVotingRewardsFactory.sol";
import {IRootBribeVotingReward, RootBribeVotingReward} from "src/mainnet/rewards/RootBribeVotingReward.sol";
import {IRootFeesVotingReward, RootFeesVotingReward} from "src/mainnet/rewards/RootFeesVotingReward.sol";

import {FeesVotingReward} from "src/rewards/FeesVotingReward.sol";
import {BribeVotingReward} from "src/rewards/BribeVotingReward.sol";
import {IReward} from "src/interfaces/rewards/IReward.sol";

import {CreateX} from "test/mocks/CreateX.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {MultichainMockMailbox} from "test/mocks/MultichainMockMailbox.sol";
import {IVoter, MockVoter} from "test/mocks/MockVoter.sol";
import {IVotingEscrow, MockVotingEscrow} from "test/mocks/MockVotingEscrow.sol";
import {IFactoryRegistry, MockFactoryRegistry} from "test/mocks/MockFactoryRegistry.sol";
import {IWETH, MockWETH} from "test/mocks/MockWETH.sol";
import {TestConstants} from "test/utils/TestConstants.sol";
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
    Router public rootRouter;
    RootHLTokenBridge public rootModule;
    TokenBridge public rootTokenBridge;
    HLUserTokenBridge public rootTokenModule;
    RootMessageBridge public rootMessageBridge;
    RootHLMessageBridge public rootMessageModule;

    // root-only contracts
    XERC20Lockbox public rootLockbox;
    RootPoolFactory public rootPoolFactory;
    RootGaugeFactory public rootGaugeFactory;
    RootVotingRewardsFactory public rootVotingRewardsFactory;

    RootPool public rootPool;
    RootPool public rootPoolImplementation;
    RootGauge public rootGauge;
    RootFeesVotingReward public rootFVR;
    RootBribeVotingReward public rootIVR;

    // root-only mocks
    IERC20 public rootRewardToken;
    IVoter public mockVoter;
    IVotingEscrow public mockEscrow;
    IFactoryRegistry public mockFactoryRegistry;
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
    Router public leafRouter;
    HLTokenBridge public leafModule;
    TokenBridge public leafTokenBridge;
    HLUserTokenBridge public leafTokenModule;
    MessageBridge public leafMessageBridge;
    HLMessageBridge public leafMessageModule;

    // leaf-only contracts
    PoolFactory public leafPoolFactory;
    LeafGaugeFactory public leafGaugeFactory;
    LeafVoter public leafVoter;
    VotingRewardsFactory public leafVotingRewardsFactory;

    Pool public leafPool;
    LeafGauge public leafGauge;
    FeesVotingReward public leafFVR;
    BribeVotingReward public leafIVR;

    // leaf-only mocks
    TestERC20 public token0;
    TestERC20 public token1;
    MultichainMockMailbox public leafMailbox;
    MockFactoryRegistry public leafMockFactoryRegistry;
    TestIsm public leafIsm;

    // common contracts
    IWETH public weth;
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
        weth = IWETH(new MockWETH());
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: rootStartTime});

        leafId = vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        deployCreateX();
        weth = IWETH(new MockWETH());

        leafStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: leafStartTime});
        vm.stopPrank();
    }

    function deployRootDependencies() public virtual {
        // deploy root mocks
        vm.startPrank(users.owner);
        rootMailbox = new MultichainMockMailbox(root);
        rootIsm = new TestIsm();
        rootRewardToken = new TestERC20("Reward Token", "RWRD", 18);
        mockFactoryRegistry = new MockFactoryRegistry();
        mockEscrow = new MockVotingEscrow();
        mockVoter = new MockVoter({
            _rewardToken: address(rootRewardToken),
            _factoryRegistry: address(mockFactoryRegistry),
            _ve: address(mockEscrow),
            _governor: users.owner
        });
        vm.stopPrank();
    }

    function setUpRootChain() public virtual {
        vm.selectFork({forkId: rootId});
        deployRootDependencies();

        // deploy root contracts
        vm.startPrank(users.deployer);
        rootPoolImplementation = new RootPool();
        rootPoolFactory = new RootPoolFactory({_implementation: address(rootPoolImplementation), _chainId: leaf});
        rootRouter = Router(
            payable(
                cx.deployCreate3({
                    salt: CreateXLibrary.calculateSalt({_entropy: ROUTER_ENTROPY, _deployer: users.deployer}),
                    initCode: abi.encodePacked(
                        type(Router).creationCode,
                        abi.encode(
                            address(rootPoolFactory), // pool factory
                            address(weth) // weth contract
                        )
                    )
                })
            )
        );

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

        rootModule = RootHLTokenBridge(
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
                        address(rootModule), // module
                        address(mockVoter) // mock voter address
                    )
                )
            })
        );
        rootModule = RootHLTokenBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_TOKEN_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLTokenBridge).creationCode,
                    abi.encode(address(rootBridge), address(rootMailbox), address(rootIsm))
                )
            })
        );
        rootMessageModule = RootHLMessageBridge(
            CreateXLibrary.computeCreate3Address({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        rootGaugeFactory = RootGaugeFactory(
            CreateXLibrary.computeCreate3Address({_entropy: GAUGE_FACTORY_ENTROPY, _deployer: users.deployer})
        );
        rootMessageBridge = RootMessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootMessageBridge).creationCode,
                    abi.encode(
                        users.owner, // message bridge owner
                        address(rootXVelo), // xerc20 address
                        address(mockVoter), // mock root voter
                        address(rootMessageModule), // message module
                        address(rootGaugeFactory) // root gauge factory
                    )
                )
            })
        );
        rootMessageModule = RootHLMessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootHLMessageBridge).creationCode,
                    abi.encode(
                        address(rootMessageBridge), // root bridge
                        address(rootMailbox) // root mailbox
                    )
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
                        address(rootBridge), // gauge token bridge address
                        address(rootMessageBridge) // message bridge address
                    )
                )
            })
        );
        rootVotingRewardsFactory = RootVotingRewardsFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: VOTING_REWARDS_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootVotingRewardsFactory).creationCode,
                    abi.encode(
                        address(rootMessageBridge) // message bridge
                    )
                )
            })
        );

        vm.startPrank(Ownable(address(mockFactoryRegistry)).owner());
        mockFactoryRegistry.approve({
            poolFactory: address(rootPoolFactory),
            votingRewardsFactory: address(rootVotingRewardsFactory),
            gaugeFactory: address(rootGaugeFactory)
        });
        vm.stopPrank();

        vm.label({account: address(rootMailbox), newLabel: "Root Mailbox"});
        vm.label({account: address(rootIsm), newLabel: "Root ISM"});
        vm.label({account: address(rootRewardToken), newLabel: "Root Reward Token"});
        vm.label({account: address(mockFactoryRegistry), newLabel: "Root Factory Registry"});
        vm.label({account: address(mockVoter), newLabel: "Root Mock Voter"});
        vm.label({account: address(rootLockbox), newLabel: "Root Lockbox"});

        vm.label({account: address(rootPoolImplementation), newLabel: "Pool"});
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
        vm.label({account: address(rootVotingRewardsFactory), newLabel: "Voting Rewards Factory"});
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

        TestERC20 tokenA = new TestERC20("Test Token A", "TTA", 18);
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
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
        leafRouter = Router(
            payable(
                cx.deployCreate3({
                    salt: CreateXLibrary.calculateSalt({_entropy: ROUTER_ENTROPY, _deployer: users.deployer}),
                    initCode: abi.encodePacked(
                        type(Router).creationCode,
                        abi.encode(
                            address(leafPoolFactory), // pool factory
                            address(weth) // weth contract
                        )
                    )
                })
            )
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

        leafMessageBridge = MessageBridge(
            CreateXLibrary.computeCreate3Address({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer})
        );
        leafVoter = LeafVoter(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: VOTER_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(LeafVoter).creationCode,
                    abi.encode(
                        address(leafMockFactoryRegistry), // mock factory registry
                        users.owner, // emergency council
                        address(leafMessageBridge) // message bridge
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
                        address(leafModule), // module
                        address(leafVoter) // voter address
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
                        address(leafXVelo), // xerc20 address
                        address(leafVoter), // leaf voter
                        address(leafMessageModule), // message module
                        address(leafPoolFactory) // leaf pool factory
                    )
                )
            })
        );
        leafMessageModule = HLMessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: HL_MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(HLMessageBridge).creationCode,
                    abi.encode(
                        address(leafMessageBridge), // leaf message bridge
                        address(leafMailbox), // leaf mailbox
                        address(leafIsm) // leaf security module
                    )
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
                        address(leafVoter), // voter address
                        address(leafPoolFactory), // pool factory address
                        address(leafXVelo), // xerc20 address
                        address(leafMessageBridge), // bridge address
                        users.owner // notifyAdmin address
                    )
                )
            })
        );

        leafVotingRewardsFactory = VotingRewardsFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: REWARDS_FACTORY_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(VotingRewardsFactory).creationCode,
                    abi.encode(
                        address(leafVoter), // voter address
                        address(leafMessageBridge) // bridge address
                    )
                )
            })
        );

        leafMockFactoryRegistry.approve({
            poolFactory: address(leafPoolFactory),
            votingRewardsFactory: address(leafVotingRewardsFactory),
            gaugeFactory: address(leafGaugeFactory)
        });
        vm.stopPrank();

        vm.label({account: address(leafMailbox), newLabel: "Leaf Mailbox"});
        vm.label({account: address(leafIsm), newLabel: "Leaf ISM"});
        vm.label({account: address(leafMockFactoryRegistry), newLabel: "Leaf Factory Registry"});
        vm.label({account: address(leafVoter), newLabel: "Leaf Voter"});
        vm.label({account: address(leafVotingRewardsFactory), newLabel: "Leaf Voting Rewards Factory"});
    }

    // Any set up required to link the contracts across the two chains
    function setUpPostCommon() public virtual {
        vm.selectFork({forkId: rootId});
        rootMailbox.addRemoteMailbox(leaf, leafMailbox);
        rootMailbox.setDomainForkId({_domain: leaf, _forkId: leafId});

        // set up root pool & gauge
        vm.startPrank(users.owner);
        rootMessageBridge.registerChain({_chainid: leaf});

        rootPool =
            RootPool(rootPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false}));
        vm.startPrank(mockVoter.governor());
        rootGauge = RootGauge(mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(rootPool)}));
        rootFVR = RootFeesVotingReward(mockVoter.gaugeToFees(address(rootGauge)));
        rootIVR = RootBribeVotingReward(mockVoter.gaugeToBribe(address(rootGauge)));

        // create pool & gauge to whitelist WETH as bribe token
        address bribePool = rootPoolFactory.createPool({tokenA: address(token0), tokenB: address(weth), stable: false});
        mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(bribePool)});
        vm.stopPrank();

        vm.selectFork({forkId: leafId});
        // set up leaf pool & gauge by processing pending `createGauge` message in mailbox
        leafMailbox.processNextInboundMessage();
        leafPool = Pool(leafPoolFactory.getPool({tokenA: address(token0), tokenB: address(token1), stable: false}));
        leafGauge = LeafGauge(leafVoter.gauges(address(leafPool)));
        leafFVR = FeesVotingReward(leafVoter.gaugeToFees(address(leafGauge)));
        leafIVR = BribeVotingReward(leafVoter.gaugeToBribe(address(leafGauge)));

        // set up pool & gauge for bribe token on leaf by processing pending `createGauge` message in mailbox
        leafMailbox.processNextInboundMessage();
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
        rootXVelo.setLimits({
            _bridge: address(rootMessageBridge),
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
        leafXVelo.setLimits({
            _bridge: address(leafMessageBridge),
            _mintingLimit: _leafMintingLimit,
            _burningLimit: _rootMintingLimit
        });
        vm.selectFork({forkId: activeFork});
        vm.stopPrank();
    }

    /// @dev Move time forward on all chains
    function skipTime(uint256 _time) internal {
        uint256 activeFork = vm.activeFork();
        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: activeFork});
    }

    /// @dev Helper utility to forward time to next week on all chains
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 _offset) public {
        uint256 timeToNextEpoch = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        skipTime(timeToNextEpoch + _offset);
    }
}
