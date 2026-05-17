// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

import {AMMPoolFactory} from "../contracts/AMMPoolFactory.sol";
import {CraftingManager} from "../contracts/CraftingManager.sol";
import {GameGovernor} from "../contracts/GameGovernor.sol";
import {GameItems1155} from "../contracts/GameItems1155.sol";
import {GameParametersV1} from "../contracts/GameParametersV1.sol";
import {GameToken} from "../contracts/GameToken.sol";
import {GameVault4626} from "../contracts/GameVault4626.sol";
import {LootDrop} from "../contracts/LootDrop.sol";
import {PriceFeedAdapter} from "../contracts/PriceFeedAdapter.sol";
import {RentalVault} from "../contracts/RentalVault.sol";
import {ResourceToken} from "../contracts/ResourceToken.sol";
import {AggregatorV3Interface} from "../contracts/interfaces/AggregatorV3Interface.sol";
import {IGameParameters} from "../contracts/interfaces/IGameParameters.sol";
import {IVRFCoordinatorV2} from "../contracts/interfaces/IVRFCoordinatorV2.sol";
import {MockV3Aggregator} from "../contracts/mocks/MockV3Aggregator.sol";
import {MockVRFCoordinatorV2} from "../contracts/mocks/MockVRFCoordinatorV2.sol";

contract Deploy is Script {
    uint256 internal constant TIMELOCK_DELAY = 2 days;

    struct Deployment {
        GameToken gameToken;
        ResourceToken gold;
        ResourceToken crystal;
        GameItems1155 items;
        GameParametersV1 parameters;
        PriceFeedAdapter priceFeed;
        CraftingManager crafting;
        LootDrop lootDrop;
        RentalVault rentalVault;
        GameVault4626 vault;
        AMMPoolFactory factory;
        GameGovernor governor;
        TimelockController timelock;
        address pool;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        Deployment memory d;
        d.gameToken = new GameToken(deployer);
        d.gameToken.delegate(deployer);

        d.gold = new ResourceToken("Gold", "GOLD", deployer);
        d.crystal = new ResourceToken("Crystal", "CRYSTAL", deployer);
        d.items = new GameItems1155("ipfs://gamefi-economy/{id}.json", deployer);

        d.parameters = _deployParameters(deployer, d.gold, d.crystal, d.items);
        d.priceFeed = _deployPriceFeed(deployer);
        (IVRFCoordinatorV2 coordinator, bytes32 keyHash, uint64 subscriptionId) = _deployOrLoadVRF();

        IGameParameters paramsInterface = IGameParameters(address(d.parameters));
        d.crafting = new CraftingManager(deployer, d.items, paramsInterface);
        d.lootDrop = new LootDrop(
            deployer,
            d.items,
            paramsInterface,
            coordinator,
            d.items.LOOT_BOX(),
            keyHash,
            subscriptionId
        );
        d.rentalVault = new RentalVault(deployer, d.items, deployer, 500);
        d.vault = new GameVault4626(d.gold, deployer);
        d.factory = new AMMPoolFactory(deployer);
        d.pool = d.factory.createPoolDeterministic(address(d.gold), address(d.crystal), keccak256("GOLD_CRYSTAL"));

        _setupInitialBalances(d.gold, d.crystal, d.items, deployer);
        _grantManagerRoles(d.gold, d.crystal, d.items, d.crafting, d.lootDrop);
        (d.governor, d.timelock) = _setupGovernance(deployer, d.gameToken);
        _transferProtocolControlToTimelock(d, deployer);

        vm.stopBroadcast();

        _logDeployment(d, coordinator);
    }

    function _deployParameters(address deployer, ResourceToken gold, ResourceToken crystal, GameItems1155 items)
        internal
        returns (GameParametersV1)
    {
        GameParametersV1 impl = new GameParametersV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(GameParametersV1.initialize, (deployer)));
        GameParametersV1 parameters = GameParametersV1(address(proxy));

        parameters.setRecipe(1, address(gold), 100 ether, address(crystal), 10 ether, items.SWORD(), 1, true);

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
        return parameters;
    }

    function _deployPriceFeed(address deployer) internal returns (PriceFeedAdapter) {
        address configuredFeed = vm.envOr("CHAINLINK_PRICE_FEED", address(0));
        AggregatorV3Interface feed = configuredFeed == address(0)
            ? AggregatorV3Interface(address(new MockV3Aggregator(8, 2_000e8)))
            : AggregatorV3Interface(configuredFeed);
        return new PriceFeedAdapter(feed, 1 days, deployer);
    }

    function _deployOrLoadVRF() internal returns (IVRFCoordinatorV2 coordinator, bytes32 keyHash, uint64 subscriptionId) {
        address configuredCoordinator = vm.envOr("VRF_COORDINATOR", address(0));
        coordinator = configuredCoordinator == address(0)
            ? IVRFCoordinatorV2(address(new MockVRFCoordinatorV2()))
            : IVRFCoordinatorV2(configuredCoordinator);
        keyHash = vm.envOr("VRF_KEY_HASH", bytes32(0));
        subscriptionId = uint64(vm.envOr("VRF_SUBSCRIPTION_ID", uint256(0)));
    }

    function _setupInitialBalances(ResourceToken gold, ResourceToken crystal, GameItems1155 items, address deployer) internal {
        gold.mint(deployer, 5_000_000 ether);
        crystal.mint(deployer, 5_000_000 ether);
        items.mint(deployer, items.LOOT_BOX(), 1_000, "");
    }

    function _grantManagerRoles(
        ResourceToken gold,
        ResourceToken crystal,
        GameItems1155 items,
        CraftingManager crafting,
        LootDrop lootDrop
    ) internal {
        gold.grantRole(gold.BURNER_ROLE(), address(crafting));
        crystal.grantRole(crystal.BURNER_ROLE(), address(crafting));
        items.grantRole(items.MINTER_ROLE(), address(crafting));
        items.grantRole(items.MINTER_ROLE(), address(lootDrop));
        items.grantRole(items.BURNER_ROLE(), address(lootDrop));
    }

    function _setupGovernance(address deployer, GameToken gameToken)
        internal
        returns (GameGovernor governor, TimelockController timelock)
    {
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, deployer);
        governor = new GameGovernor(IVotes(address(gameToken)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.TIMELOCK_ADMIN_ROLE(), address(timelock));
    }

    function _transferProtocolControlToTimelock(Deployment memory d, address deployer) internal {
        address timelockAddress = address(d.timelock);

        _moveGameTokenControl(d.gameToken, deployer, timelockAddress);
        _moveResourceControl(d.gold, deployer, timelockAddress);
        _moveResourceControl(d.crystal, deployer, timelockAddress);
        _moveItemsControl(d.items, deployer, timelockAddress);
        _moveParametersControl(d.parameters, deployer, timelockAddress);
        _moveCraftingControl(d.crafting, deployer, timelockAddress);
        _moveLootControl(d.lootDrop, deployer, timelockAddress);
        _moveRentalControl(d.rentalVault, deployer, timelockAddress);
        _moveVaultControl(d.vault, deployer, timelockAddress);
        _moveFactoryControl(d.factory, deployer, timelockAddress);
        _movePriceFeedControl(d.priceFeed, deployer, timelockAddress);

        d.timelock.revokeRole(d.timelock.TIMELOCK_ADMIN_ROLE(), deployer);
    }

    function _moveGameTokenControl(GameToken token, address deployer, address timelockAddress) internal {
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), timelockAddress);
        token.grantRole(token.MINTER_ROLE(), timelockAddress);
        token.revokeRole(token.MINTER_ROLE(), deployer);
        token.revokeRole(token.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveResourceControl(ResourceToken token, address deployer, address timelockAddress) internal {
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), timelockAddress);
        token.grantRole(token.MINTER_ROLE(), timelockAddress);
        token.grantRole(token.BURNER_ROLE(), timelockAddress);
        token.grantRole(token.PAUSER_ROLE(), timelockAddress);
        token.revokeRole(token.MINTER_ROLE(), deployer);
        token.revokeRole(token.BURNER_ROLE(), deployer);
        token.revokeRole(token.PAUSER_ROLE(), deployer);
        token.revokeRole(token.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveItemsControl(GameItems1155 items, address deployer, address timelockAddress) internal {
        items.grantRole(items.DEFAULT_ADMIN_ROLE(), timelockAddress);
        items.grantRole(items.MINTER_ROLE(), timelockAddress);
        items.grantRole(items.BURNER_ROLE(), timelockAddress);
        items.grantRole(items.URI_SETTER_ROLE(), timelockAddress);
        items.grantRole(items.PAUSER_ROLE(), timelockAddress);
        items.revokeRole(items.MINTER_ROLE(), deployer);
        items.revokeRole(items.BURNER_ROLE(), deployer);
        items.revokeRole(items.URI_SETTER_ROLE(), deployer);
        items.revokeRole(items.PAUSER_ROLE(), deployer);
        items.revokeRole(items.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveParametersControl(GameParametersV1 parameters, address deployer, address timelockAddress) internal {
        parameters.grantRole(parameters.DEFAULT_ADMIN_ROLE(), timelockAddress);
        parameters.grantRole(parameters.PARAMETER_ADMIN_ROLE(), timelockAddress);
        parameters.grantRole(parameters.UPGRADER_ROLE(), timelockAddress);
        parameters.grantRole(parameters.PAUSER_ROLE(), timelockAddress);
        parameters.revokeRole(parameters.PARAMETER_ADMIN_ROLE(), deployer);
        parameters.revokeRole(parameters.UPGRADER_ROLE(), deployer);
        parameters.revokeRole(parameters.PAUSER_ROLE(), deployer);
        parameters.revokeRole(parameters.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveCraftingControl(CraftingManager crafting, address deployer, address timelockAddress) internal {
        crafting.grantRole(crafting.DEFAULT_ADMIN_ROLE(), timelockAddress);
        crafting.grantRole(crafting.CONFIG_ROLE(), timelockAddress);
        crafting.grantRole(crafting.PAUSER_ROLE(), timelockAddress);
        crafting.revokeRole(crafting.CONFIG_ROLE(), deployer);
        crafting.revokeRole(crafting.PAUSER_ROLE(), deployer);
        crafting.revokeRole(crafting.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveLootControl(LootDrop lootDrop, address deployer, address timelockAddress) internal {
        lootDrop.grantRole(lootDrop.DEFAULT_ADMIN_ROLE(), timelockAddress);
        lootDrop.grantRole(lootDrop.CONFIG_ROLE(), timelockAddress);
        lootDrop.grantRole(lootDrop.PAUSER_ROLE(), timelockAddress);
        lootDrop.revokeRole(lootDrop.CONFIG_ROLE(), deployer);
        lootDrop.revokeRole(lootDrop.PAUSER_ROLE(), deployer);
        lootDrop.revokeRole(lootDrop.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveRentalControl(RentalVault rentalVault, address deployer, address timelockAddress) internal {
        rentalVault.grantRole(rentalVault.DEFAULT_ADMIN_ROLE(), timelockAddress);
        rentalVault.grantRole(rentalVault.FEE_SETTER_ROLE(), timelockAddress);
        rentalVault.grantRole(rentalVault.PAUSER_ROLE(), timelockAddress);
        rentalVault.revokeRole(rentalVault.FEE_SETTER_ROLE(), deployer);
        rentalVault.revokeRole(rentalVault.PAUSER_ROLE(), deployer);
        rentalVault.revokeRole(rentalVault.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveVaultControl(GameVault4626 vault, address deployer, address timelockAddress) internal {
        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), timelockAddress);
        vault.grantRole(vault.TREASURY_ROLE(), timelockAddress);
        vault.grantRole(vault.PAUSER_ROLE(), timelockAddress);
        vault.revokeRole(vault.TREASURY_ROLE(), deployer);
        vault.revokeRole(vault.PAUSER_ROLE(), deployer);
        vault.revokeRole(vault.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _moveFactoryControl(AMMPoolFactory factory, address deployer, address timelockAddress) internal {
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), timelockAddress);
        factory.grantRole(factory.POOL_CREATOR_ROLE(), timelockAddress);
        factory.revokeRole(factory.POOL_CREATOR_ROLE(), deployer);
        factory.revokeRole(factory.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _movePriceFeedControl(PriceFeedAdapter priceFeed, address deployer, address timelockAddress) internal {
        priceFeed.grantRole(priceFeed.DEFAULT_ADMIN_ROLE(), timelockAddress);
        priceFeed.grantRole(priceFeed.CONFIG_ROLE(), timelockAddress);
        priceFeed.revokeRole(priceFeed.CONFIG_ROLE(), deployer);
        priceFeed.revokeRole(priceFeed.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _logDeployment(Deployment memory d, IVRFCoordinatorV2 coordinator) internal view {
        console2.log("Deployment successful");
        console2.log("GameToken:", address(d.gameToken));
        console2.log("Gold:", address(d.gold));
        console2.log("Crystal:", address(d.crystal));
        console2.log("GameItems1155:", address(d.items));
        console2.log("ParametersProxy:", address(d.parameters));
        console2.log("PriceFeedAdapter:", address(d.priceFeed));
        console2.log("VRFCoordinator:", address(coordinator));
        console2.log("CraftingManager:", address(d.crafting));
        console2.log("LootDrop:", address(d.lootDrop));
        console2.log("RentalVault:", address(d.rentalVault));
        console2.log("GameVault4626:", address(d.vault));
        console2.log("AMMPoolFactory:", address(d.factory));
        console2.log("AMMPool:", d.pool);
        console2.log("Governor:", address(d.governor));
        console2.log("Timelock:", address(d.timelock));
    }
}
