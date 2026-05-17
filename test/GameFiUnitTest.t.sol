// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GameParametersV1} from "../contracts/GameParametersV1.sol";
import {GameParametersV2} from "../contracts/GameParametersV2.sol";
import {GameItems1155} from "../contracts/GameItems1155.sol";
import {ResourceToken} from "../contracts/ResourceToken.sol";
import {AMMPool} from "../contracts/AMMPool.sol";
import {AMMPoolFactory} from "../contracts/AMMPoolFactory.sol";
import {RentalVault} from "../contracts/RentalVault.sol";
import {BaseGameFiTest} from "./BaseGameFiTest.sol";
import {IGameParameters} from "../contracts/interfaces/IGameParameters.sol";

contract GameFiUnitTest is BaseGameFiTest {
    function testGovernanceTokenMetadataAndSupply() public {
        assertEq(gameToken.name(), "GameFi Governance Token");
        assertEq(gameToken.symbol(), "GGT");
        assertEq(gameToken.totalSupply(), GameTokenInitialSupply());
    }

    function GameTokenInitialSupply() internal pure returns (uint256) {
        return 100_000_000 ether;
    }

    function testGovernanceTokenPermitNonceStartsAtZero() public {
        assertEq(gameToken.nonces(alice), 0);
    }

    function testGovernanceTokenDelegationCreatesVotes() public {
        assertEq(gameToken.delegates(address(this)), address(this));
        assertGt(gameToken.getVotes(address(this)), 0);
    }

    function testGovernanceTokenOnlyMinterCanMint() public {
        vm.prank(alice);
        vm.expectRevert();
        gameToken.mint(alice, 1 ether);
    }

    function testResourceMintBurn() public {
        uint256 beforeSupply = gold.totalSupply();
        gold.mint(alice, 5 ether);
        gold.burnFrom(alice, 2 ether);
        assertEq(gold.balanceOf(alice), 10_003 ether);
        assertEq(gold.totalSupply(), beforeSupply + 3 ether);
    }

    function testResourceBurnOnlyBurner() public {
        vm.prank(alice);
        vm.expectRevert();
        gold.burnFrom(alice, 1 ether);
    }

    function testResourcePauseStopsTransfers() public {
        gold.pause();
        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        gold.transfer(bob, 1 ether);
        gold.unpause();
    }

    function testResourcePauseOnlyPauser() public {
        vm.prank(alice);
        vm.expectRevert();
        gold.pause();
    }

    function testItemsMintBurnSupply() public {
        items.mint(alice, items.SWORD(), 2, "");
        assertEq(items.balanceOf(alice, items.SWORD()), 2);
        assertEq(items.totalSupply(items.SWORD()), 2);
        items.burnFrom(alice, items.SWORD(), 1);
        assertEq(items.totalSupply(items.SWORD()), 1);
    }

    function testItemsMintOnlyMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        items.mint(alice, items.SWORD(), 1, "");
    }

    function testItemsUriSetter() public {
        items.setURI("ipfs://new/{id}.json");
        assertEq(items.uri(items.SWORD()), "ipfs://new/{id}.json");
    }

    function testItemsPauseStopsTransfer() public {
        items.mint(alice, items.SWORD(), 1, "");
        items.pause();
        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        items.safeTransferFrom(alice, bob, items.SWORD(), 1, "");
        items.unpause();
    }

    function testParametersRecipeRead() public {
        (address resourceA, uint256 amountA,,,,, bool active) = parameters.getRecipe(1);
        assertEq(resourceA, address(gold));
        assertEq(amountA, 100 ether);
        assertTrue(active);
    }

    function testParametersDisableRecipe() public {
        parameters.disableRecipe(1);
        (,,,,,, bool active) = parameters.getRecipe(1);
        assertFalse(active);
    }

    function testParametersOnlyAdminSetsRecipe() public {
        vm.prank(alice);
        vm.expectRevert();
        parameters.setRecipe(3, address(gold), 1, address(0), 0, items.SWORD(), 1, true);
    }

    function testParametersRejectsBadLootWeights() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory weights = new uint256[](1);
        ids[0] = items.SWORD();
        amounts[0] = 1;
        weights[0] = 9_999;
        vm.expectRevert("GameParameters: weights must total 10000");
        parameters.setLootTable(ids, amounts, weights);
    }

    function testParametersPickLootFirstBucket() public {
        (uint256 itemId, uint256 amount) = parameters.pickLoot(6999);
        assertEq(itemId, items.SWORD());
        assertEq(amount, 1);
    }

    function testParametersPickLootRareBucket() public {
        (uint256 itemId,) = parameters.pickLoot(9999);
        assertEq(itemId, items.DRAGON_ARMOR());
    }

    function testCraftingSuccess() public {
        vm.prank(alice);
        crafting.craft(1);
        assertEq(items.balanceOf(alice, items.SWORD()), 1);
        assertEq(gold.balanceOf(alice), 9_900 ether);
        assertEq(crystal.balanceOf(alice), 9_990 ether);
    }

    function testCraftingInactiveRecipeReverts() public {
        vm.prank(alice);
        vm.expectRevert("CraftingManager: inactive recipe");
        crafting.craft(2);
    }

    function testCraftingPauseReverts() public {
        crafting.pause();
        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        crafting.craft(1);
        crafting.unpause();
    }

    function testCraftingSetParametersOnlyConfigRole() public {
        vm.prank(alice);
        vm.expectRevert();
        crafting.setParameters(IGameParameters(address(parameters)));
    }

    function testLootDropOpenAndFulfill() public {
        _mintLootBox(alice, 1);
        vm.prank(alice);
        uint256 requestId = lootDrop.openLootBox();
        mockVrf.fulfill(requestId, 9999);
        assertEq(items.balanceOf(alice, items.DRAGON_ARMOR()), 1);
    }

    function testLootDropBurnsLootBox() public {
        _mintLootBox(alice, 2);
        vm.prank(alice);
        lootDrop.openLootBox();
        assertEq(items.balanceOf(alice, items.LOOT_BOX()), 1);
    }

    function testLootDropOnlyCoordinatorCanFulfill() public {
        uint256[] memory words = new uint256[](1);
        words[0] = 1;
        vm.expectRevert("LootDrop: only coordinator");
        lootDrop.rawFulfillRandomWords(1, words);
    }

    function testLootDropPauseReverts() public {
        _mintLootBox(alice, 1);
        lootDrop.pause();
        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        lootDrop.openLootBox();
        lootDrop.unpause();
    }

    function testLootDropConfigOnlyRole() public {
        vm.prank(alice);
        vm.expectRevert();
        lootDrop.setParameters(IGameParameters(address(parameters)));
    }

    function testRentalListEscrowsItem() public {
        _mintRentable(alice, items.SWORD(), 1);
        vm.prank(alice);
        uint256 listingId = rentalVault.list(items.SWORD(), 1, 1 ether, 1 days);
        assertEq(items.balanceOf(address(rentalVault), items.SWORD()), 1);
        (address lender,,,,,,,) = rentalVault.listings(listingId);
        assertEq(lender, alice);
    }

    function testRentalRentRecordsRenterAndPullPayment() public {
        _mintRentable(alice, items.SWORD(), 1);
        vm.prank(alice);
        uint256 listingId = rentalVault.list(items.SWORD(), 1, 1 ether, 1 days);
        vm.prank(bob);
        rentalVault.rent{value: 1 ether}(listingId);
        assertEq(rentalVault.pendingWithdrawals(alice), 0.95 ether);
        assertEq(rentalVault.pendingWithdrawals(address(this)), 0.05 ether);
    }

    function testRentalWrongPaymentReverts() public {
        _mintRentable(alice, items.SWORD(), 1);
        vm.prank(alice);
        uint256 listingId = rentalVault.list(items.SWORD(), 1, 1 ether, 1 days);
        vm.prank(bob);
        vm.expectRevert("RentalVault: wrong payment");
        rentalVault.rent{value: 0.5 ether}(listingId);
    }
}