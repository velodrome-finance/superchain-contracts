// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin5/contracts/interfaces/draft-IERC6093.sol";
import {TestIsm} from "@hyperlane/core/contracts/test/TestIsm.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {IBridge, Bridge} from "src/bridge/Bridge.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {IXERC20, XERC20} from "src/xerc20/XERC20.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";

import {CreateX} from "test/mocks/CreateX.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {MultichainMockMailbox} from "test/mocks/MultichainMockMailbox.sol";
import {Constants} from "test/utils/Constants.sol";
import {Users} from "test/utils/Users.sol";

abstract contract BaseForkFixture is Test, Constants {
    // anything prefixed with origin is deployed on the origin chain
    // anything prefixed with destination is deployed on the destination chain

    // origin and destination domains (recommended to be the chainId)
    uint32 public origin = 1;
    uint32 public destination = 2;

    uint256 public originId;
    uint256 public destinationId;

    XERC20Factory public originXFactory;
    XERC20Factory public destinationXFactory;

    XERC20 public originXVelo;
    XERC20 public destinationXVelo;

    XERC20Lockbox public originLockbox;

    TestERC20 public originRewardToken;

    CreateX public cx = CreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    Bridge public originBridge;
    Bridge public destinationBridge;

    MultichainMockMailbox public originMailbox;
    MultichainMockMailbox public destinationMailbox;

    TestIsm public originIsm;
    TestIsm public destinationIsm;

    Users internal users;

    function setUp() public virtual {
        createUsers();

        setUpOriginChain();
        setUpDestinationChain();
        setUpCommon();
    }

    function setUpOriginChain() public virtual {
        originId = vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 123316800});
        originMailbox = new MultichainMockMailbox(origin);

        originRewardToken = new TestERC20("Reward Token", "RWRD", 18);
        deployCreateX();

        originXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: calculateSalt(XERC20_FACTORY_ENTROPY),
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
                salt: calculateSalt(BRIDGE_ENTROPY),
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
    }

    function setUpDestinationChain() public virtual {
        destinationId = vm.createSelectFork({urlOrAlias: "mode", blockNumber: 11032400});
        destinationMailbox = new MultichainMockMailbox(destination);

        deployCreateX();

        destinationXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: calculateSalt(XERC20_FACTORY_ENTROPY),
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
                salt: calculateSalt(BRIDGE_ENTROPY),
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
    }

    // Any set up required to link the contracts across the two chains
    function setUpCommon() public virtual {
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

    function calculateSalt(bytes11 _entropy) internal view returns (bytes32 salt) {
        salt = bytes32(abi.encodePacked(bytes20(address(this)), bytes1(0x00), _entropy));
    }
}
