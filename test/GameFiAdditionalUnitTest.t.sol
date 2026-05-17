// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AMMPool} from "../contracts/AMMPool.sol";
import {ResourceToken} from "../contracts/ResourceToken.sol";
import {RentalVault} from "../contracts/RentalVault.sol";
import {IGameParameters} from "../contracts/interfaces/IGameParameters.sol";
import {IVRFCoordinatorV2} from "../contracts/interfaces/IVRFCoordinatorV2.sol";
import {BaseGameFiTest} from "./BaseGameFiTest.sol";

contract GameFiAdditionalUnitTest is BaseGameFiTest {
    function testFactoryAllPoolsLengthStartsAtOne() public {
        assertEq(factory.allPoolsLength(), 1);
        assertEq(factory.getPool(address(gold), address(crystal)), address(pool));
    }

    function testFactoryDeterministicPredictionMatchesDeployment() public {
        ResourceToken wood = new ResourceToken("Wood", "WOOD", address(this));
        ResourceToken stone = new ResourceToken("Stone", "STONE", address(this));
        bytes32 salt = keccak256("WOOD_STONE");
        address predicted = factory.predictPoolAddress(address(wood), address(stone), salt);
        address deployed = factory.createPoolDeterministic(address(wood), address(stone), salt);
        assertEq(deployed, predicted);
    }

    function testFactoryRejectsDuplicatePool() public {
        vm.expectRevert("AMMPoolFactory: pool exists");
        factory.createPool(address(gold), address(crystal));
    }

    function testFactoryOnlyCreatorCanCreatePool() public {
        ResourceToken wood = new ResourceToken("Wood", "WOOD", address(this));
        ResourceToken stone = new ResourceToken("Stone", "STONE", address(this));
        vm.prank(alice);
        vm.expectRevert();
        factory.createPool(address(wood), address(stone));
    }

    function testFactoryCanPauseAndUnpausePool() public {
        factory.pausePool(address(pool));
        assertTrue(pool.paused());
        factory.unpausePool(address(pool));
        assertFalse(pool.paused());
    }

    function testAmmQuoteRejectsInvalidToken() public {
        vm.expectRevert("AMMPool: invalid token");
        pool.quote(address(0x1234), 1 ether);
    }

    function testAmmQuoteReturnsOutput() public {
        uint256 out = pool.quote(address(pool.token0()), 1 ether);
        assertGt(out, 0);
    }

    function testAmmSwapSlippageReverts() public {
        vm.prank(alice);
        vm.expectRevert("AMMPool: slippage");
        pool.swap(address(pool.token0()), 1 ether, 10_000 ether, alice);
    }

    function testAmmSwapInvalidTokenReverts() public {
        vm.prank(alice);
        vm.expectRevert("AMMPool: invalid token");
        pool.swap(address(0xBEEF), 1 ether, 0, alice);
    }

    function testAmmAddLiquidityRejectsZeroAmounts() public {
        vm.expectRevert("AMMPool: zero amount");
        pool.addLiquidity(0, 1 ether, 0, address(this));
    }

    function testAmmRemoveLiquidityReturnsAssets() public {
        uint256 liquidity = pool.balanceOf(address(this)) / 100;
        uint256 before0 = gold.balanceOf(address(this));
        uint256 before1 = crystal.balanceOf(address(this));
        pool.removeLiquidity(liquidity, 1, 1, address(this));
        assertGt(gold.balanceOf(address(this)), before0);
        assertGt(crystal.balanceOf(address(this)), before1);
    }

    function testAmmRemoveLiquiditySlippageReverts() public {
        uint256 liquidity = pool.balanceOf(address(this)) / 100;
        vm.expectRevert("AMMPool: slippage");
        pool.removeLiquidity(liquidity, type(uint256).max, 1, address(this));
    }

    function testAmmRemoveLiquidityRejectsZeroLiquidity() public {
        vm.expectRevert("AMMPool: zero liquidity");
        pool.removeLiquidity(0, 0, 0, address(this));
    }

    function testVaultDepositMintsShares() public {
        uint256 shares = vault.deposit(100 ether, alice);
        assertEq(vault.balanceOf(alice), shares);
        assertGt(shares, 0);
    }

    function testVaultMintPullsAssets() public {
        uint256 assets = vault.mint(50 ether, alice);
        assertEq(vault.balanceOf(alice), 50 ether);
        assertGt(assets, 0);
    }

    function testVaultWithdrawReturnsAssets() public {
        vault.deposit(100 ether, alice);
        vm.prank(alice);
        uint256 sharesBurned = vault.withdraw(25 ether, alice, alice);
        assertGt(sharesBurned, 0);
    }

    function testVaultRedeemBurnsShares() public {
        uint256 shares = vault.deposit(100 ether, alice);
        vm.prank(alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        assertGt(assets, 0);
        assertEq(vault.balanceOf(alice), 0);
    }

    function testVaultPauseBlocksDeposit() public {
        vault.pause();
        vm.expectRevert("Pausable: paused");
        vault.deposit(1 ether, alice);
        vault.unpause();
    }

    function testVaultReleaseTreasuryOnlyRole() public {
        vault.deposit(100 ether, address(this));
        vm.prank(alice);
        vm.expectRevert();
        vault.releaseToTreasury(alice, 1 ether);
    }

    function testPriceFeedLatestPrice() public {
        (int256 answer, uint8 decimals_, uint256 updatedAt) = priceFeed.latestPrice();
        assertEq(answer, 2_000e8);
        assertEq(decimals_, 8);
        assertGt(updatedAt, 0);
    }

    function testPriceFeedStalePriceReverts() public {
        vm.warp(10 days);
        mockFeed.updateAnswerWithTimestamp(2_000e8, block.timestamp - 2 days);
        vm.expectRevert("PriceFeedAdapter: stale price");
        priceFeed.latestPrice();
    }

    function testPriceFeedInvalidPriceReverts() public {
        mockFeed.updateAnswer(0);
        vm.expectRevert("PriceFeedAdapter: invalid price");
        priceFeed.latestPrice();
    }

    function testPriceFeedOnlyConfigCanSetStaleness() public {
        vm.prank(alice);
        vm.expectRevert();
        priceFeed.setMaxStaleness(2 days);
    }

    function testRentalFinishAfterExpiry() public {
        _mintRentable(alice, items.SWORD(), 1);
        vm.prank(alice);
        uint256 listingId = rentalVault.list(items.SWORD(), 1, 1 ether, 1 days);
        vm.prank(bob);
        rentalVault.rent{value: 1 ether}(listingId);
        vm.warp(block.timestamp + 1 days + 1);
        rentalVault.finishRental(listingId);
        (,,,,, RentalVault.ListingState state,,) = rentalVault.listings(listingId);
        assertEq(uint256(state), uint256(RentalVault.ListingState.Listed));
    }

    function testRentalWithdrawAfterExpiry() public {
        _mintRentable(alice, items.SWORD(), 1);
        vm.prank(alice);
        uint256 listingId = rentalVault.list(items.SWORD(), 1, 1 ether, 1 days);
        vm.prank(bob);
        rentalVault.rent{value: 1 ether}(listingId);
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(alice);
        rentalVault.withdrawListing(listingId);
        assertEq(items.balanceOf(alice, items.SWORD()), 1);
    }

    function testRentalClaimEarnings() public {
        _mintRentable(alice, items.SWORD(), 1);
        vm.prank(alice);
        uint256 listingId = rentalVault.list(items.SWORD(), 1, 1 ether, 1 days);
        vm.prank(bob);
        rentalVault.rent{value: 1 ether}(listingId);
        vm.prank(alice);
        rentalVault.claimEarnings();
        assertEq(rentalVault.pendingWithdrawals(alice), 0);
    }

    function testRentalSetFeeConfig() public {
        rentalVault.setFeeConfig(carol, 100);
        assertEq(rentalVault.feeRecipient(), carol);
        assertEq(rentalVault.feeBps(), 100);
    }

    function testRentalOnlyFeeSetterCanSetFeeConfig() public {
        vm.prank(alice);
        vm.expectRevert();
        rentalVault.setFeeConfig(alice, 100);
    }

    function testRentalReceiveCreditsFeeRecipient() public {
        (bool ok,) = payable(address(rentalVault)).call{value: 0.25 ether}("");
        assertTrue(ok);
        assertEq(rentalVault.pendingWithdrawals(address(this)), 0.25 ether);
    }

    function testLootSetVrfConfig() public {
        lootDrop.setVrfConfig(IVRFCoordinatorV2(address(mockVrf)), bytes32(uint256(123)), 42, 5, 300_000);
        assertEq(lootDrop.subscriptionId(), 42);
        assertEq(lootDrop.requestConfirmations(), 5);
    }

    function testLootSetVrfConfigRejectsLowGas() public {
        vm.expectRevert("LootDrop: gas too low");
        lootDrop.setVrfConfig(IVRFCoordinatorV2(address(mockVrf)), bytes32(0), 0, 3, 99_999);
    }

    function testItemsBatchMint() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = items.SWORD();
        ids[1] = items.SHIELD();
        amounts[0] = 1;
        amounts[1] = 2;
        items.mintBatch(alice, ids, amounts, "");
        assertEq(items.balanceOf(alice, items.SWORD()), 1);
        assertEq(items.balanceOf(alice, items.SHIELD()), 2);
    }

    function testItemsOnlyUriSetterCanSetUri() public {
        vm.prank(alice);
        vm.expectRevert();
        items.setURI("ipfs://blocked/{id}.json");
    }

    function testParametersRejectsZeroOutputAmount() public {
        vm.expectRevert("GameParameters: output amount zero");
        parameters.setRecipe(99, address(gold), 1, address(0), 0, items.SWORD(), 0, true);
    }

    function testParametersPauseBlocksPickLoot() public {
        parameters.pause();
        vm.expectRevert("Pausable: paused");
        parameters.pickLoot(1);
        parameters.unpause();
    }

    function testGovernorSettingsMatchSpecification() public {
        assertEq(governor.votingDelay(), 7_200);
        assertEq(governor.votingPeriod(), 50_400);
        assertEq(governor.proposalThreshold(), 1_000_000 ether);
    }

    function testTimelockDelayMatchesSpecification() public {
        assertEq(timelock.getMinDelay(), 2 days);
    }

    receive() external payable {}
}
