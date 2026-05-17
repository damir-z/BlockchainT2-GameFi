// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGameParameters {
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
        );

    function pickLoot(uint256 randomWord) external view returns (uint256 itemId, uint256 amount);
}
