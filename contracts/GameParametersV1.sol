// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title GameParametersV1
/// @notice UUPS-upgradeable source of DAO-governed game parameters.
contract GameParametersV1 is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    bytes32 public constant PARAMETER_ADMIN_ROLE = keccak256("PARAMETER_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant BPS = 10_000;

    struct Recipe {
        address resourceA;
        uint256 amountA;
        address resourceB;
        uint256 amountB;
        uint256 outputItemId;
        uint256 outputAmount;
        bool active;
    }

    mapping(uint256 => Recipe) internal _recipes;
    uint256[] internal _lootItemIds;
    uint256[] internal _lootAmounts;
    uint256[] internal _lootCumulativeBps;

    event RecipeUpdated(
        uint256 indexed recipeId,
        address indexed resourceA,
        uint256 amountA,
        address indexed resourceB,
        uint256 amountB,
        uint256 outputItemId,
        uint256 outputAmount,
        bool active
    );
    event LootTableUpdated(uint256 rows);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        require(admin != address(0), "GameParameters: zero admin");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PARAMETER_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setRecipe(
        uint256 recipeId,
        address resourceA,
        uint256 amountA,
        address resourceB,
        uint256 amountB,
        uint256 outputItemId,
        uint256 outputAmount,
        bool active
    ) external onlyRole(PARAMETER_ADMIN_ROLE) {
        require(recipeId != 0, "GameParameters: recipe id zero");
        require(outputItemId != 0, "GameParameters: output id zero");
        require(outputAmount != 0, "GameParameters: output amount zero");
        require(amountA != 0 || amountB != 0, "GameParameters: zero cost");
        if (amountA != 0) require(resourceA != address(0), "GameParameters: zero resource A");
        if (amountB != 0) require(resourceB != address(0), "GameParameters: zero resource B");

        _recipes[recipeId] = Recipe({
            resourceA: resourceA,
            amountA: amountA,
            resourceB: resourceB,
            amountB: amountB,
            outputItemId: outputItemId,
            outputAmount: outputAmount,
            active: active
        });

        emit RecipeUpdated(recipeId, resourceA, amountA, resourceB, amountB, outputItemId, outputAmount, active);
    }

    function disableRecipe(uint256 recipeId) external onlyRole(PARAMETER_ADMIN_ROLE) {
        _recipes[recipeId].active = false;
        Recipe memory recipe = _recipes[recipeId];
        emit RecipeUpdated(
            recipeId,
            recipe.resourceA,
            recipe.amountA,
            recipe.resourceB,
            recipe.amountB,
            recipe.outputItemId,
            recipe.outputAmount,
            false
        );
    }

    function getRecipe(uint256 recipeId)
        external
        view
        returns (
            address resourceA,
            uint256 amountA,
            address resourceB,
            uint256 amountB,
            uint256 outputItemId,
            uint256 outputAmount,
            bool active
        )
    {
        Recipe memory recipe = _recipes[recipeId];
        return (
            recipe.resourceA,
            recipe.amountA,
            recipe.resourceB,
            recipe.amountB,
            recipe.outputItemId,
            recipe.outputAmount,
            recipe.active
        );
    }

    function setLootTable(uint256[] calldata itemIds, uint256[] calldata amounts, uint256[] calldata weightsBps)
        external
        onlyRole(PARAMETER_ADMIN_ROLE)
    {
        require(itemIds.length != 0, "GameParameters: empty loot table");
        require(itemIds.length == amounts.length, "GameParameters: amount length");
        require(itemIds.length == weightsBps.length, "GameParameters: weight length");

        delete _lootItemIds;
        delete _lootAmounts;
        delete _lootCumulativeBps;

        uint256 cumulative;
        for (uint256 i; i < itemIds.length; ++i) {
            require(itemIds[i] != 0, "GameParameters: zero item");
            require(amounts[i] != 0, "GameParameters: zero amount");
            require(weightsBps[i] != 0, "GameParameters: zero weight");
            cumulative += weightsBps[i];
            require(cumulative <= BPS, "GameParameters: weight overflow");
            _lootItemIds.push(itemIds[i]);
            _lootAmounts.push(amounts[i]);
            _lootCumulativeBps.push(cumulative);
        }
        require(cumulative == BPS, "GameParameters: weights must total 10000");
        emit LootTableUpdated(itemIds.length);
    }

    function lootTableLength() external view returns (uint256) {
        return _lootItemIds.length;
    }

    function lootRow(uint256 index) external view returns (uint256 itemId, uint256 amount, uint256 cumulativeBps) {
        return (_lootItemIds[index], _lootAmounts[index], _lootCumulativeBps[index]);
    }

    function pickLoot(uint256 randomWord) external view whenNotPaused returns (uint256 itemId, uint256 amount) {
        require(_lootItemIds.length != 0, "GameParameters: loot table not set");
        uint256 roll = randomWord % BPS;
        for (uint256 i; i < _lootCumulativeBps.length; ++i) {
            if (roll < _lootCumulativeBps[i]) {
                return (_lootItemIds[i], _lootAmounts[i]);
            }
        }
        revert("GameParameters: unreachable loot roll");
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[45] private __gap;
}
