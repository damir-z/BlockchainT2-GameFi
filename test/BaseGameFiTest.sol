// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {AMMPool} from "../contracts/AMMPool.sol";
import {AMMPoolFactory} from "../contracts/AMMPoolFactory.sol";
import {CraftingManager} from "../contracts/CraftingManager.sol";
import {GameGovernor} from "../contracts/GameGovernor.sol";
import {GameItems1155} from "../contracts/GameItems1155.sol";
import {GameParametersV1} from "../contracts/GameParametersV1.sol";
import {GameParametersV2} from "../contracts/GameParametersV2.sol";
import {GameToken} from "../contracts/GameToken.sol";
import {GameVault4626} from "../contracts/GameVault4626.sol";
import {LootDrop} from "../contracts/LootDrop.sol";
import {PriceFeedAdapter} from "../contracts/PriceFeedAdapter.sol";
import {RentalVault} from "../contracts/RentalVault.sol";
import {ResourceToken} from "../contracts/ResourceToken.sol";
import {AMMMathHarness} from "../contracts/math/AMMMathHarness.sol";
import {MockV3Aggregator} from "../contracts/mocks/MockV3Aggregator.sol";
import {MockVRFCoordinatorV2} from "../contracts/mocks/MockVRFCoordinatorV2.sol";
import {IGameParameters} from "../contracts/interfaces/IGameParameters.sol";
import {IVRFCoordinatorV2} from "../contracts/interfaces/IVRFCoordinatorV2.sol";

contract BaseGameFiTest is Test {
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA110);

    GameToken internal gameToken;
    ResourceToken internal gold;
    ResourceToken internal crystal;
    GameItems1155 internal items;
    GameParametersV1 internal parameters;
    CraftingManager internal crafting;
    LootDrop internal lootDrop;
    RentalVault internal rentalVault;
    AMMPoolFactory internal factory;
    AMMPool internal pool;
    GameVault4626 internal vault;
    MockV3Aggregator internal mockFeed;
    PriceFeedAdapter internal priceFeed;
    MockVRFCoordinatorV2 internal mockVrf;
    GameGovernor internal governor;
    TimelockController internal timelock;
    AMMMathHarness internal mathHarness;

    function setUp() public virtual {
        gameToken = new GameToken(address(this));
        gold = new ResourceToken("Gold", "GOLD", address(this));
        crystal = new ResourceToken("Crystal", "CRYSTAL", address(this));
        items = new GameItems1155("ipfs://gamefi-economy/{id}.json", address(this));

        GameParametersV1 impl = new GameParametersV1();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(GameParametersV1.initialize, (address(this)))
        );
        parameters = GameParametersV1(address(proxy));

        parameters.setRecipe(
            1,
            address(gold),
            100 ether,
            address(crystal),
            10 ether,
            items.SWORD(),
            1,
            true
        );

        parameters.setRecipe(
            2,
            address(gold),
            200 ether,
            address(crystal),
            25 ether,
            items.SHIELD(),
            1,
            false
        );

        uint256[] memory lootIds = new uint256[](3);
        uint256[] memory lootAmounts = new uint256[](3);
        uint256[] memory weights = new uint256[](3);
        lootIds[0] = items.SWORD();
        lootIds[1] = items.SHIELD();
        lootIds[2] = items.DRAGON_ARMOR();
        lootAmounts[0] = 1;
        lootAmounts[1] = 1;
        lootAmounts[2] = 1;
        weights[0] = 7_000;
        weights[1] = 2_500;
        weights[2] = 500;
        parameters.setLootTable(lootIds, lootAmounts, weights);

        crafting = new CraftingManager(address(this), items, IGameParameters(address(parameters)));
        items.grantRole(items.MINTER_ROLE(), address(crafting));
        gold.grantRole(gold.BURNER_ROLE(), address(crafting));
        crystal.grantRole(crystal.BURNER_ROLE(), address(crafting));

        mockVrf = new MockVRFCoordinatorV2();
        lootDrop = new LootDrop(
            address(this),
            items,
            IGameParameters(address(parameters)),
            IVRFCoordinatorV2(address(mockVrf)),   // <-- исправлено
            items.LOOT_BOX(),
            bytes32(0),
            0
        );
        items.grantRole(items.MINTER_ROLE(), address(lootDrop));
        items.grantRole(items.BURNER_ROLE(), address(lootDrop));

        rentalVault = new RentalVault(address(this), items, address(this), 500);
        factory = new AMMPoolFactory(address(this));
        pool = AMMPool(factory.createPool(address(gold), address(crystal)));
        vault = new GameVault4626(gold, address(this));
        mockFeed = new MockV3Aggregator(8, 2_000e8);
        priceFeed = new PriceFeedAdapter(mockFeed, 1 days, address(this));
        mathHarness = new AMMMathHarness();

        gold.mint(address(this), 10_000_000 ether);
        crystal.mint(address(this), 10_000_000 ether);
        gold.approve(address(pool), type(uint256).max);
        crystal.approve(address(pool), type(uint256).max);
        gold.approve(address(vault), type(uint256).max);
        crystal.approve(address(vault), type(uint256).max);
        pool.addLiquidity(1_000_000 ether, 1_000_000 ether, 1, address(this));

        _fundPlayer(alice, 10_000 ether);
        _fundPlayer(bob, 10_000 ether);
        _fundPlayer(carol, 10_000 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(2 days, proposers, executors, address(this));
        governor = new GameGovernor(IVotes(address(gameToken)), timelock);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        vault.grantRole(vault.PAUSER_ROLE(), address(timelock));
        vault.grantRole(vault.TREASURY_ROLE(), address(timelock));
        gameToken.delegate(address(this));
        vm.roll(block.number + 1);
    }

    function _fundPlayer(address player, uint256 amount) internal {
        gold.mint(player, amount);
        crystal.mint(player, amount);
        vm.startPrank(player);
        gold.approve(address(pool), type(uint256).max);
        crystal.approve(address(pool), type(uint256).max);
        gold.approve(address(vault), type(uint256).max);
        crystal.approve(address(vault), type(uint256).max);
        items.setApprovalForAll(address(rentalVault), true);
        vm.stopPrank();
    }

    function _mintLootBox(address player, uint256 amount) internal {
        items.mint(player, items.LOOT_BOX(), amount, "");
    }

    function _mintRentable(address player, uint256 itemId, uint256 amount) internal {
        items.mint(player, itemId, amount, "");
    }

    function _poolK() internal view returns (uint256) {
        (uint256 r0, uint256 r1) = pool.getReserves();
        return r0 * r1;
    }
}