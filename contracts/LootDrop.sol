// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {GameItems1155} from "./GameItems1155.sol";
import {IGameParameters} from "./interfaces/IGameParameters.sol";
import {IVRFCoordinatorV2} from "./interfaces/IVRFCoordinatorV2.sol";

/// @title LootDrop
/// @notice Chainlink VRF-backed loot box opener. Randomness is never derived from block data.
contract LootDrop is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    GameItems1155 public immutable items;
    IGameParameters public parameters;
    IVRFCoordinatorV2 public coordinator;

    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint16 public requestConfirmations;
    uint32 public callbackGasLimit;
    uint256 public lootBoxItemId;

    mapping(uint256 => address) public requestToPlayer;

    event VrfConfigUpdated(address indexed coordinator, bytes32 keyHash, uint64 subscriptionId);
    event LootRequested(address indexed player, uint256 indexed requestId);
    event LootFulfilled(address indexed player, uint256 indexed requestId, uint256 indexed itemId, uint256 amount);

    constructor(
        address admin,
        GameItems1155 items_,
        IGameParameters parameters_,
        IVRFCoordinatorV2 coordinator_,
        uint256 lootBoxItemId_,
        bytes32 keyHash_,
        uint64 subscriptionId_
    ) {
        require(admin != address(0), "LootDrop: zero admin");
        require(address(items_) != address(0), "LootDrop: zero items");
        require(address(parameters_) != address(0), "LootDrop: zero parameters");
        require(address(coordinator_) != address(0), "LootDrop: zero coordinator");
        require(lootBoxItemId_ != 0, "LootDrop: zero loot box id");

        items = items_;
        parameters = parameters_;
        coordinator = coordinator_;
        lootBoxItemId = lootBoxItemId_;
        keyHash = keyHash_;
        subscriptionId = subscriptionId_;
        requestConfirmations = 3;
        callbackGasLimit = 250_000;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setVrfConfig(
        IVRFCoordinatorV2 newCoordinator,
        bytes32 newKeyHash,
        uint64 newSubscriptionId,
        uint16 newRequestConfirmations,
        uint32 newCallbackGasLimit
    ) external onlyRole(CONFIG_ROLE) {
        require(address(newCoordinator) != address(0), "LootDrop: zero coordinator");
        require(newRequestConfirmations != 0, "LootDrop: zero confirmations");
        require(newCallbackGasLimit >= 100_000, "LootDrop: gas too low");
        coordinator = newCoordinator;
        keyHash = newKeyHash;
        subscriptionId = newSubscriptionId;
        requestConfirmations = newRequestConfirmations;
        callbackGasLimit = newCallbackGasLimit;
        emit VrfConfigUpdated(address(newCoordinator), newKeyHash, newSubscriptionId);
    }

    function setParameters(IGameParameters newParameters) external onlyRole(CONFIG_ROLE) {
        require(address(newParameters) != address(0), "LootDrop: zero parameters");
        parameters = newParameters;
    }

    function openLootBox() external nonReentrant whenNotPaused returns (uint256 requestId) {
        items.burnFrom(msg.sender, lootBoxItemId, 1);
        requestId = coordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );
        requestToPlayer[requestId] = msg.sender;
        emit LootRequested(msg.sender, requestId);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        require(msg.sender == address(coordinator), "LootDrop: only coordinator");
        require(randomWords.length != 0, "LootDrop: empty randomness");
        address player = requestToPlayer[requestId];
        require(player != address(0), "LootDrop: unknown request");
        delete requestToPlayer[requestId];

        (uint256 itemId, uint256 amount) = parameters.pickLoot(randomWords[0]);
        items.mint(player, itemId, amount, "");
        emit LootFulfilled(player, requestId, itemId, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
