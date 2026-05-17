// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GameParametersV1} from "./GameParametersV1.sol";

/// @title GameParametersV2
/// @notice Demonstrates the documented V1 -> V2 UUPS upgrade path without changing storage layout.
contract GameParametersV2 is GameParametersV1 {
    function version() external pure returns (string memory) {
        return "GameParametersV2";
    }

    function recipeHash(uint256 recipeId) external view returns (bytes32) {
        (
            address resourceA,
            uint256 amountA,
            address resourceB,
            uint256 amountB,
            uint256 outputItemId,
            uint256 outputAmount,
            bool active
        ) = this.getRecipe(recipeId);

        return keccak256(abi.encode(resourceA, amountA, resourceB, amountB, outputItemId, outputAmount, active));
    }
}
