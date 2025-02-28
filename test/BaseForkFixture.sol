// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/src/console.sol";
import {IVoter} from "src/interfaces/external/IVoter.sol";
import {IMinter} from "src/interfaces/external/IMinter.sol";
import {IVotingEscrow} from "src/interfaces/external/IVotingEscrow.sol";
import {IFactoryRegistry} from "src/interfaces/external/IFactoryRegistry.sol";
import {IWETH} from "src/interfaces/external/IWETH.sol";
import {ISpecifiesInterchainSecurityModule} from "src/interfaces/external/ISpecifiesInterchainSecurityModule.sol";

import {Test, stdStorage, StdStorage} from "forge-std/src/Test.sol";
import {Clones} from "@openzeppelin5/contracts/proxy/Clones.sol";
import {Math} from "@openzeppelin5/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {IERC20, IERC20Errors} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {IERC721} from "@openzeppelin5/contracts/token/ERC721/IERC721.sol";
import {TestIsm} from "@hyperlane/core/contracts/test/TestIsm.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {SafeCast} from "@openzeppelin5/contracts/utils/math/SafeCast.sol";
import {StandardHookMetadata} from "@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol";

import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";
import {MintLimits} from "src/xerc20/MintLimits.sol";
import {Commands} from "src/libraries/Commands.sol";
import {GasLimits} from "src/libraries/GasLimits.sol";

import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {IXERC20, XERC20} from "src/xerc20/XERC20.sol";
import {RateLimitMidPoint} from "src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {IRootPool, RootPool} from "src/root/pools/RootPool.sol";
import {IRootPoolFactory, RootPoolFactory} from "src/root/pools/RootPoolFactory.sol";
import {IRootGauge, RootGauge} from "src/root/gauges/RootGauge.sol";
import {IRootGaugeFactory, RootGaugeFactory} from "src/root/gauges/RootGaugeFactory.sol";
import {ILeafVoter, LeafVoter} from "src/voter/LeafVoter.sol";
import {ILeafGauge, LeafGauge} from "src/gauges/LeafGauge.sol";
import {ILeafGaugeFactory, LeafGaugeFactory} from "src/gauges/LeafGaugeFactory.sol";
import {IPool, Pool} from "src/pools/Pool.sol";
import {IRouter, Router} from "src/Router.sol";
import {IPoolFactory, PoolFactory} from "src/pools/PoolFactory.sol";
import {ITokenBridge, LeafTokenBridge} from "src/bridge/LeafTokenBridge.sol";
import {ILeafEscrowTokenBridge, LeafEscrowTokenBridge} from "src/bridge/LeafEscrowTokenBridge.sol";
import {IRootTokenBridge, RootTokenBridge} from "src/root/bridge/RootTokenBridge.sol";
import {IRootEscrowTokenBridge, RootEscrowTokenBridge} from "src/root/bridge/RootEscrowTokenBridge.sol";
import {ILeafMessageBridge, LeafMessageBridge} from "src/bridge/LeafMessageBridge.sol";
import {IRootMessageBridge, RootMessageBridge} from "src/root/bridge/RootMessageBridge.sol";
import {IRootRestrictedTokenBridge, RootRestrictedTokenBridge} from "src/root/bridge/RootRestrictedTokenBridge.sol";
import {ILeafRestrictedTokenBridge, LeafRestrictedTokenBridge} from "src/bridge/LeafRestrictedTokenBridge.sol";

import {IHLHandler} from "src/interfaces/bridge/hyperlane/IHLHandler.sol";
import {ILeafHLMessageModule, LeafHLMessageModule} from "src/bridge/hyperlane/LeafHLMessageModule.sol";
import {IVotingRewardsFactory, VotingRewardsFactory} from "src/rewards/VotingRewardsFactory.sol";
import {IChainRegistry} from "src/interfaces/bridge/IChainRegistry.sol";
import {ICrossChainRegistry} from "src/interfaces/bridge/ICrossChainRegistry.sol";

import {
    IMessageSender,
    IRootHLMessageModule,
    RootHLMessageModule
} from "src/root/bridge/hyperlane/RootHLMessageModule.sol";
import {IPaymaster} from "src/root/bridge/hyperlane/Paymaster.sol";
import {IGasRouter} from "src/interfaces/root/bridge/hyperlane/IGasRouter.sol";
import {IPaymasterVault, PaymasterVault} from "src/root/bridge/hyperlane/PaymasterVault.sol";

import {IRootVotingRewardsFactory, RootVotingRewardsFactory} from "src/root/rewards/RootVotingRewardsFactory.sol";
import {IRootIncentiveVotingReward, RootIncentiveVotingReward} from "src/root/rewards/RootIncentiveVotingReward.sol";
import {IRootFeesVotingReward, RootFeesVotingReward} from "src/root/rewards/RootFeesVotingReward.sol";

import {FeesVotingReward} from "src/rewards/FeesVotingReward.sol";
import {IncentiveVotingReward} from "src/rewards/IncentiveVotingReward.sol";
import {IReward} from "src/interfaces/rewards/IReward.sol";

import {IEmergencyCouncil, EmergencyCouncil} from "src/root/emergencyCouncil/EmergencyCouncil.sol";

import {RestrictedXERC20Factory} from "src/xerc20/extensions/RestrictedXERC20Factory.sol";
import {IRestrictedXERC20, RestrictedXERC20} from "src/xerc20/extensions/RestrictedXERC20.sol";

import {CreateX} from "test/mocks/CreateX.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {Mailbox, MultichainMockMailbox} from "test/mocks/MultichainMockMailbox.sol";
import {IVoter, MockVoter} from "test/mocks/MockVoter.sol";
import {MockCustomHook, IHookGasEstimator} from "test/mocks/MockCustomHook.sol";
import {IVotingEscrow, MockVotingEscrow} from "test/mocks/MockVotingEscrow.sol";
import {IFactoryRegistry, MockFactoryRegistry} from "test/mocks/MockFactoryRegistry.sol";
import {TestConstants} from "test/utils/TestConstants.sol";
import {Users} from "test/utils/Users.sol";
import {TestDeployLeaf} from "test/utils/TestDeployLeaf.sol";
import {TestDeployRoot} from "test/utils/TestDeployRoot.sol";
import {TestDeployRestrictedXERC20Root} from "test/utils/TestDeployRestrictedXERC20Root.sol";
import {TestDeployRestrictedXERC20Leaf} from "test/utils/TestDeployRestrictedXERC20Leaf.sol";

import {DeployRootBaseFixture} from "script/root/01_DeployRootBaseFixture.s.sol";
import {DeployBaseFixture} from "script/01_DeployBaseFixture.s.sol";
import {DeployRootRestrictedXERC20} from "script/root/deployRestrictedXERC20/01_DeployRootRestrictedXERC20.sol";
import {DeployLeafRestrictedXERC20} from "script/deployRestrictedXERC20/01_DeployLeafRestrictedXERC20.sol";

abstract contract BaseForkFixture is Test, TestConstants {
    using stdStorage for StdStorage;
    using SafeCast for uint256;

    // anything prefixed with root is deployed on the root chain
    // anything prefixed with leaf is deployed on the leaf chain
    // in the context of velodrome superchain, the root chain will always be optimism (chainid=10)
    // leaf chains will be any chain that velodrome expands to

    // all helper functions return control to the root fork at end of execution
    // assume all tests start from the root fork
    // contracts in {root/leaf} superchain contracts run identical code (with different constructor / initialization args)
    // contracts in {root/leaf}-only contracts run different code (but all code on each leaf chain will run the same code w/ different args)
    // contracts in {root}-only mocks are mock contracts and not part of the superchain deployment

    TestDeployLeaf public deployLeaf;
    TestDeployLeaf.DeploymentParameters public leafParams;

    TestDeployRoot public deployRoot;
    TestDeployRoot.RootDeploymentParameters public rootParams;

    TestDeployRestrictedXERC20Root public deployRestrictedRoot;
    TestDeployRestrictedXERC20Root.RestrictedXERC20DeploymentParams public rootRestrictedParams;

    TestDeployRestrictedXERC20Leaf public deployRestrictedLeaf;
    TestDeployRestrictedXERC20Leaf.RestrictedXERC20DeploymentParams public leafRestrictedParams;

    // root variables
    uint32 public root = 10; // root chain id
    uint32 public rootDomain = 10; // root domain
    uint256 public rootId; // root fork id (used by foundry)
    uint256 public rootStartTime; // root fork start time (set to start of epoch for simplicity)

    // root superchain contracts
    XERC20Factory public rootXFactory;
    XERC20 public rootXVelo;
    RootTokenBridge public rootTokenBridge;
    RootMessageBridge public rootMessageBridge;
    RootHLMessageModule public rootMessageModule;
    PaymasterVault public rootTokenBridgeVault;
    PaymasterVault public rootModuleVault;

    EmergencyCouncil public emergencyCouncil;

    // restricted rewards contracts
    RestrictedXERC20Factory public rootRestrictedXFactory;
    RestrictedXERC20 public rootRestrictedRewardToken;
    RootRestrictedTokenBridge public rootRestrictedTokenBridge;
    PaymasterVault public rootRestrictedTokenBridgeVault;

    // root-only contracts
    XERC20Lockbox public rootLockbox;
    RootPool public rootPoolImplementation;
    RootPoolFactory public rootPoolFactory;
    RootGaugeFactory public rootGaugeFactory;
    IRootVotingRewardsFactory public rootVotingRewardsFactory;

    RootPool public rootPool;
    RootGauge public rootGauge;
    RootFeesVotingReward public rootFVR;
    RootIncentiveVotingReward public rootIVR;
    IMinter public minter;

    // restricted rewards lockbox contract
    XERC20Lockbox public rootRestrictedRewardLockbox;

    // root-only mocks
    IERC20 public rootRewardToken;
    IERC20 public rootIncentiveToken; // used to test restricted rewards
    IVoter public mockVoter;
    IVotingEscrow public mockEscrow;
    IFactoryRegistry public mockFactoryRegistry;
    MultichainMockMailbox public rootMailbox;
    MockCustomHook public rootHook;
    TestIsm public rootIsm;

    // leaf variables
    uint32 public leaf = 34443; // leaf chain id
    uint32 public leafDomain = 1000034443; // leaf domain
    uint256 public leafId; // leaf fork id (used by foundry)
    uint256 public leafStartTime; // leaf fork start time (set to start of epoch for simplicity)

    // leaf superchain contracts
    XERC20Factory public leafXFactory;
    XERC20 public leafXVelo;
    Router public leafRouter;
    LeafTokenBridge public leafTokenBridge;
    LeafMessageBridge public leafMessageBridge;
    LeafHLMessageModule public leafMessageModule;

    RestrictedXERC20Factory public leafRestrictedXFactory;
    RestrictedXERC20 public leafRestrictedRewardToken;
    LeafRestrictedTokenBridge public leafRestrictedTokenBridge;

    // leaf-only contracts
    Pool public leafPoolImplementation;
    PoolFactory public leafPoolFactory;
    LeafGaugeFactory public leafGaugeFactory;
    LeafVoter public leafVoter;
    VotingRewardsFactory public leafVotingRewardsFactory;

    Pool public leafPool;
    LeafGauge public leafGauge;
    FeesVotingReward public leafFVR;
    IncentiveVotingReward public leafIVR;

    // leaf-only mocks
    TestERC20 public token0;
    TestERC20 public token1;
    MultichainMockMailbox public leafMailbox;
    TestIsm public leafIsm;

    // common contracts
    IWETH public weth;
    CreateX public cx = CreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    // common variables
    Users internal users;

    // Gas Router default commands and gas limits
    uint256[] defaultCommands = [
        Commands.DEPOSIT,
        Commands.WITHDRAW,
        Commands.GET_INCENTIVES,
        Commands.GET_FEES,
        Commands.CREATE_GAUGE,
        Commands.NOTIFY,
        Commands.NOTIFY_WITHOUT_CLAIM,
        Commands.KILL_GAUGE,
        Commands.REVIVE_GAUGE
    ];
    uint256[] defaultGasLimits = [281_000, 75_000, 650_000, 300_000, 6_710_000, 280_000, 233_000, 83_000, 169_000];

    /// @dev Fixed fee used for x-chain message quotes
    uint256 public constant MESSAGE_FEE = 1 ether / 10_000; // 0.0001 ETH

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
        weth = IWETH(0x4200000000000000000000000000000000000006);
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: rootStartTime});

        leafId = vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        weth = IWETH(0x4200000000000000000000000000000000000006);

        leafStartTime = rootStartTime;
        vm.warp({newTimestamp: leafStartTime});
        vm.stopPrank();
    }

    function deployRootDependencies() public virtual {
        string memory path = string(abi.encodePacked(vm.projectRoot(), "/test/e2e/addresses.json"));
        string memory addresses = vm.readFile(path);

        // deploy root mocks
        vm.startPrank(users.owner);
        rootMailbox = new MultichainMockMailbox(rootDomain);
        rootIsm = new TestIsm();
        rootRewardToken = new TestERC20("Reward Token", "RWRD", 18);
        minter = IMinter(vm.parseJsonAddress(addresses, ".Minter"));
        mockFactoryRegistry = new MockFactoryRegistry();
        mockEscrow = new MockVotingEscrow(address(rootRewardToken));
        mockVoter = new MockVoter({
            _rewardToken: address(rootRewardToken),
            _factoryRegistry: address(mockFactoryRegistry),
            _ve: address(mockEscrow),
            _governor: users.owner,
            _minter: address(minter)
        });
        rootIncentiveToken = new TestERC20("Incentive Token", "INCNT", 18);
        rootHook = new MockCustomHook(users.owner, defaultCommands, defaultGasLimits);
        vm.stopPrank();
    }

    function setUpRootChain() public virtual {
        vm.selectFork({forkId: rootId});
        deployRootDependencies();

        // deploy root contracts
        vm.startPrank(users.deployer);
        TestERC20 tokenA = new TestERC20("Test Token A", "TTA", 18);
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        assertEq(token1.decimals(), 6);
        vm.stopPrank();

        rootParams = DeployRootBaseFixture.RootDeploymentParameters({
            weth: address(weth),
            voter: address(mockVoter),
            velo: address(rootRewardToken),
            tokenAdmin: users.owner,
            bridgeOwner: users.owner,
            emergencyCouncilOwner: users.owner,
            notifyAdmin: users.owner,
            emissionAdmin: users.owner,
            defaultCap: 100,
            mailbox: address(rootMailbox),
            outputFilename: "optimism.json"
        });
        deployRoot = new TestDeployRoot(rootParams);
        stdstore.target(address(deployRoot)).sig("deployer()").checked_write(users.deployer);

        deployRoot.run();

        rootXFactory = deployRoot.rootXFactory();
        rootXVelo = deployRoot.rootXVelo();
        rootTokenBridge = deployRoot.rootTokenBridge();
        rootMessageBridge = deployRoot.rootMessageBridge();
        rootMessageModule = deployRoot.rootMessageModule();
        rootTokenBridgeVault = deployRoot.rootTokenBridgeVault();
        rootModuleVault = deployRoot.rootModuleVault();

        emergencyCouncil = deployRoot.emergencyCouncil();

        rootLockbox = deployRoot.rootLockbox();
        rootPoolImplementation = deployRoot.rootPoolImplementation();
        rootPoolFactory = deployRoot.rootPoolFactory();
        rootGaugeFactory = deployRoot.rootGaugeFactory();
        rootVotingRewardsFactory = deployRoot.rootVotingRewardsFactory();

        rootRestrictedParams = DeployRootRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: users.owner,
            incentiveToken: address(rootIncentiveToken),
            module: address(rootMessageModule),
            weth: address(weth),
            ism: address(rootIsm),
            outputFilename: "optimism-xop.json"
        });
        deployRestrictedRoot = new TestDeployRestrictedXERC20Root(rootRestrictedParams);
        stdstore.target(address(deployRestrictedRoot)).sig("deployer()").checked_write(users.deployer);

        deployRestrictedRoot.run();

        rootRestrictedXFactory = deployRestrictedRoot.rootRestrictedXFactory();
        rootRestrictedRewardToken = deployRestrictedRoot.rootRestrictedRewardToken();
        rootRestrictedRewardLockbox = deployRestrictedRoot.rootRestrictedRewardLockbox();
        rootRestrictedTokenBridge = deployRestrictedRoot.rootRestrictedTokenBridge();
        rootRestrictedTokenBridgeVault = deployRestrictedRoot.rootRestrictedTokenBridgeVault();

        vm.startPrank(mockVoter.emergencyCouncil());
        mockVoter.setEmergencyCouncil(address(emergencyCouncil));
        vm.stopPrank();

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
        vm.label({account: address(rootTokenBridgeVault), newLabel: "TokenBridge Vault"});
        vm.label({account: address(rootMessageBridge), newLabel: "Message Bridge"});
        vm.label({account: address(rootMessageModule), newLabel: "Message Module"});
        vm.label({account: address(rootModuleVault), newLabel: "Module Vault"});
        vm.label({account: address(rootVotingRewardsFactory), newLabel: "Voting Rewards Factory"});

        vm.label({account: address(rootRestrictedXFactory), newLabel: "Root Restricted X Factory"});
        vm.label({account: address(rootRestrictedRewardToken), newLabel: "Root Restricted Reward Token"});
        vm.label({account: address(rootRestrictedRewardLockbox), newLabel: "Root Restricted Reward Lockbox"});
        vm.label({account: address(rootRestrictedTokenBridge), newLabel: "Root Restricted Token Bridge"});
        vm.label({account: address(rootRestrictedTokenBridgeVault), newLabel: "Root Restricted Token Bridge Vault"});

        vm.label({account: address(emergencyCouncil), newLabel: "Emergency Council"});
    }

    function setUpLeafChain() public virtual {
        vm.selectFork({forkId: leafId});

        // deploy leaf mocks
        // use deployer2 here to ensure addresses are different from the root mocks
        // this helps with labeling
        vm.startPrank(users.deployer);
        TestERC20 tokenA = new TestERC20("Test Token A", "TTA", 18);
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        assertEq(token1.decimals(), 6);
        vm.stopPrank();

        vm.startPrank(users.deployer2);
        leafMailbox = new MultichainMockMailbox(leafDomain);
        leafIsm = new TestIsm();
        vm.stopPrank();

        leafParams = DeployBaseFixture.DeploymentParameters({
            weth: address(weth),
            poolAdmin: users.owner,
            pauser: users.owner,
            feeManager: users.owner,
            tokenAdmin: users.owner,
            bridgeOwner: users.owner,
            moduleOwner: users.owner,
            mailbox: address(leafMailbox),
            outputFilename: "mode.json"
        });
        deployLeaf = new TestDeployLeaf(leafParams);
        stdstore.target(address(deployLeaf)).sig("deployer()").checked_write(users.deployer);

        deployLeaf.run();

        leafXFactory = deployLeaf.leafXFactory();
        leafXVelo = deployLeaf.leafXVelo();
        leafRouter = deployLeaf.leafRouter();
        leafTokenBridge = deployLeaf.leafTokenBridge();
        leafMessageBridge = deployLeaf.leafMessageBridge();
        leafMessageModule = deployLeaf.leafMessageModule();

        leafPoolFactory = deployLeaf.leafPoolFactory();
        leafPoolImplementation = deployLeaf.leafPoolImplementation();
        leafGaugeFactory = deployLeaf.leafGaugeFactory();
        leafVoter = deployLeaf.leafVoter();
        leafVotingRewardsFactory = deployLeaf.leafVotingRewardsFactory();

        leafRestrictedParams = DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: users.owner,
            mailbox: address(leafMailbox),
            ism: address(leafIsm),
            voter: address(leafVoter),
            outputFilename: "mode-xop.json"
        });
        deployRestrictedLeaf = new TestDeployRestrictedXERC20Leaf(leafRestrictedParams);
        stdstore.target(address(deployRestrictedLeaf)).sig("deployer()").checked_write(users.deployer);

        deployRestrictedLeaf.run();

        leafRestrictedXFactory = deployRestrictedLeaf.leafRestrictedXFactory();
        leafRestrictedRewardToken = deployRestrictedLeaf.leafRestrictedRewardToken();
        leafRestrictedTokenBridge = deployRestrictedLeaf.leafRestrictedTokenBridge();

        vm.label({account: address(leafMailbox), newLabel: "Leaf Mailbox"});
        vm.label({account: address(leafIsm), newLabel: "Leaf ISM"});
        vm.label({account: address(leafVoter), newLabel: "Leaf Voter"});
        vm.label({account: address(leafVotingRewardsFactory), newLabel: "Leaf Voting Rewards Factory"});

        vm.label({account: address(leafRestrictedXFactory), newLabel: "Leaf Restricted X Factory"});
        vm.label({account: address(leafRestrictedRewardToken), newLabel: "Leaf Restricted Reward Token"});
        vm.label({account: address(leafRestrictedTokenBridge), newLabel: "Leaf Restricted Token Bridge"});
    }

    // Any set up required to link the contracts across the two chains
    function setUpPostCommon() public virtual {
        vm.selectFork({forkId: rootId});
        // mock calls to dispatch
        vm.mockCall({
            callee: address(rootMailbox),
            data: abi.encode(bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)"))),
            returnData: abi.encode(MESSAGE_FEE)
        });

        // fund paymaster vaults for transaction sponsoring
        vm.deal(address(rootModuleVault), MESSAGE_FEE * 1_000);
        vm.deal(address(rootTokenBridgeVault), MESSAGE_FEE * 1_000);

        // fund alice for gauge creation below
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 3});
        vm.startPrank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 3});

        rootMailbox.addRemoteMailbox({_domain: leafDomain, _mailbox: leafMailbox});
        rootMailbox.setDomainForkId({_domain: leafDomain, _forkId: leafId});

        // set up root pool & gauge
        vm.startPrank(users.owner);
        rootMessageBridge.addModule({_module: address(rootMessageModule)});
        rootMessageBridge.registerChain({_chainid: leaf, _module: address(rootMessageModule)});
        rootMessageModule.setDomain({_chainid: leaf, _domain: leafDomain});

        rootPool = RootPool(
            rootPoolFactory.createPool({chainid: leaf, tokenA: address(token0), tokenB: address(token1), stable: false})
        );
        vm.startPrank({msgSender: mockVoter.governor(), txOrigin: users.alice});
        rootGauge = RootGauge(mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(rootPool)}));
        rootFVR = RootFeesVotingReward(mockVoter.gaugeToFees(address(rootGauge)));
        rootIVR = RootIncentiveVotingReward(mockVoter.gaugeToBribe(address(rootGauge)));

        // create pool & gauge to whitelist WETH as incentive token
        address incentivePool =
            rootPoolFactory.createPool({chainid: leaf, tokenA: address(token0), tokenB: address(weth), stable: false});
        mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(incentivePool)});
        vm.stopPrank();

        vm.selectFork({forkId: leafId});
        // mock calls to dispatch
        vm.mockCall({
            callee: address(leafMailbox),
            data: abi.encode(bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)"))),
            returnData: abi.encode(MESSAGE_FEE)
        });
        leafMailbox.addRemoteMailbox({_domain: rootDomain, _mailbox: rootMailbox});
        leafMailbox.setDomainForkId({_domain: rootDomain, _forkId: rootId});

        // set up leaf pool & gauge by processing pending `createGauge` message in mailbox
        leafMailbox.processNextInboundMessage();
        leafPool = Pool(leafPoolFactory.getPool({tokenA: address(token0), tokenB: address(token1), stable: false}));
        leafGauge = LeafGauge(leafVoter.gauges(address(leafPool)));
        leafFVR = FeesVotingReward(leafVoter.gaugeToFees(address(leafGauge)));
        leafIVR = IncentiveVotingReward(leafVoter.gaugeToIncentive(address(leafGauge)));

        // set up pool & gauge for incentive token on leaf by processing pending `createGauge` message in mailbox
        leafMailbox.processNextInboundMessage();
    }

    function createUsers() internal {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie"),
            deployer: createUser("Deployer"),
            deployer2: createUser("Deployer2")
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

    /// @dev Helper function that adds root & leaf bridge limits
    function setLimits(uint256 _rootBufferCap, uint256 _leafBufferCap) internal {
        vm.stopPrank();
        uint256 activeFork = vm.activeFork();

        vm.startPrank(users.owner);
        vm.selectFork({forkId: rootId});

        uint112 rootBufferCap = _rootBufferCap.toUint112();
        // replenish limits in 1 day, avoid max rate limit per second
        uint128 rps = Math.min((rootBufferCap / 2) / DAY, rootXVelo.maxRateLimitPerSecond()).toUint128();
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: rootBufferCap,
                bridge: address(rootTokenBridge),
                rateLimitPerSecond: rps
            })
        );
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: rootBufferCap,
                bridge: address(rootMessageModule),
                rateLimitPerSecond: rps
            })
        );

        vm.selectFork({forkId: leafId});
        uint112 leafBufferCap = _leafBufferCap.toUint112();
        // replenish limits in 1 day, avoid max rate limit per second
        rps = Math.min((leafBufferCap / 2) / DAY, leafXVelo.maxRateLimitPerSecond()).toUint128();
        leafXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: leafBufferCap,
                bridge: address(leafTokenBridge),
                rateLimitPerSecond: rps
            })
        );
        leafXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: leafBufferCap,
                bridge: address(leafMessageModule),
                rateLimitPerSecond: rps
            })
        );

        vm.selectFork({forkId: activeFork});
        vm.stopPrank();
    }

    /// @dev Helper function that adds root & leaf bridge limits for restricted tokens
    function setLimitsRestricted(uint256 _rootBufferCap, uint256 _leafBufferCap) internal {
        vm.stopPrank();
        uint256 activeFork = vm.activeFork();

        vm.startPrank(users.owner);
        vm.selectFork({forkId: rootId});

        uint112 rootBufferCap = _rootBufferCap.toUint112();
        // replenish limits in 1 day, avoid max rate limit per second
        uint128 rps = Math.min((rootBufferCap / 2) / DAY, rootRestrictedRewardToken.maxRateLimitPerSecond()).toUint128();
        rootRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: rootBufferCap,
                bridge: address(rootRestrictedTokenBridge),
                rateLimitPerSecond: rps
            })
        );

        vm.selectFork({forkId: leafId});
        uint112 leafBufferCap = _leafBufferCap.toUint112();
        // replenish limits in 1 day, avoid max rate limit per second
        rps = Math.min((leafBufferCap / 2) / DAY, leafRestrictedRewardToken.maxRateLimitPerSecond()).toUint128();
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: leafBufferCap,
                bridge: address(leafRestrictedTokenBridge),
                rateLimitPerSecond: rps
            })
        );

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

    modifier syncForkTimestamps() {
        uint256 fork = vm.activeFork();
        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: rootStartTime});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        vm.selectFork({forkId: fork});
        _;
    }
}
