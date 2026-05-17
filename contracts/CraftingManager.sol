// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {GameItems1155} from "./GameItems1155.sol";
import {IGameParameters} from "./interfaces/IGameParameters.sol";
import {IResourceToken} from "./interfaces/IResourceToken.sol";

/// @title CraftingManager
/// @notice Burns ERC-20 resources and mints ERC-1155 game items according to DAO-controlled recipes.
contract CraftingManager is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    GameItems1155 public immutable items;
    IGameParameters public parameters;

    event ParametersUpdated(address indexed oldParameters, address indexed newParameters);
    event ItemCrafted(address indexed player, uint256 indexed recipeId, uint256 indexed outputItemId, uint256 amount);

    constructor(address admin, GameItems1155 items_, IGameParameters parameters_) {
        require(admin != address(0), "CraftingManager: zero admin");
        require(address(items_) != address(0), "CraftingManager: zero items");
        require(address(parameters_) != address(0), "CraftingManager: zero parameters");

        items = items_;
        parameters = parameters_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setParameters(IGameParameters newParameters) external onlyRole(CONFIG_ROLE) {
        require(address(newParameters) != address(0), "CraftingManager: zero parameters");
        address old = address(parameters);
        parameters = newParameters;
        emit ParametersUpdated(old, address(newParameters));
    }

    function craft(uint256 recipeId) external nonReentrant whenNotPaused {
        (
            address resourceA,
            uint256 amountA,
            address resourceB,
            uint256 amountB,
            uint256 outputItemId,
            uint256 outputAmount,
            bool active
        ) = parameters.getRecipe(recipeId);

        require(active, "CraftingManager: inactive recipe");
        if (amountA != 0) {
            IResourceToken(resourceA).burnFrom(msg.sender, amountA);
        }
        if (amountB != 0) {
            IResourceToken(resourceB).burnFrom(msg.sender, amountB);
        }

        items.mint(msg.sender, outputItemId, outputAmount, "");
        emit ItemCrafted(msg.sender, recipeId, outputItemId, outputAmount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
