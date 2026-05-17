// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseGameFiTest} from "./BaseGameFiTest.sol";
import {GameItems1155} from "../contracts/GameItems1155.sol";

contract GameFiFuzzTest is BaseGameFiTest {
    function testFuzzAmmSwapToken0(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 1_000 ether);
        uint256 oldK = _poolK();
        vm.prank(alice);
        uint256 out = pool.swap(address(pool.token0()), amountIn, 0, alice);
        assertGt(out, 0);
        assertGe(_poolK(), oldK);
    }

    function testFuzzAmmSwapToken1(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 1_000 ether);
        uint256 oldK = _poolK();
        vm.prank(alice);
        uint256 out = pool.swap(address(pool.token1()), amountIn, 0, alice);
        assertGt(out, 0);
        assertGe(_poolK(), oldK);
    }

    function testFuzzAmmAddLiquidity(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 1 ether, 500 ether);
        amount1 = bound(amount1, 1 ether, 500 ether);
        vm.prank(alice);
        uint256 liquidity = pool.addLiquidity(amount0, amount1, 1, alice);
        assertGt(liquidity, 0);
    }

    function testFuzzVaultDeposit(uint256 assets) public {
        assets = bound(assets, 1, 1_000 ether);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertGt(shares, 0);
        assertLe(vault.previewRedeem(shares), assets);
    }

    function testFuzzVaultWithdraw(uint256 assets) public {
        assets = bound(assets, 1 ether, 1_000 ether);
        vm.startPrank(alice);
        vault.deposit(assets, alice);
        uint256 sharesBurned = vault.withdraw(assets / 2, alice, alice);
        vm.stopPrank();
        assertGt(sharesBurned, 0);
    }

    function testFuzzVaultRedeem(uint256 sharesTarget) public {
        uint256 assets = bound(sharesTarget, 1 ether, 1_000 ether);
        vm.startPrank(alice);
        uint256 shares = vault.deposit(assets, alice);
        uint256 redeemed = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertGt(redeemed, 0);
    }

    function testFuzzGovernanceVotingPower(uint256 transferAmount) public {
        transferAmount = bound(transferAmount, 1 ether, 1_000_000 ether);
        gameToken.transfer(alice, transferAmount);
        vm.prank(alice);
        gameToken.delegate(alice);
        vm.roll(block.number + 1);
        assertEq(gameToken.getVotes(alice), transferAmount);
    }

    function testFuzzCraftingResources(uint256 multiplier) public {
        multiplier = bound(multiplier, 1, 20);
        parameters.setRecipe(
            9,
            address(gold),
            multiplier * 10 ether,
            address(crystal),
            multiplier * 1 ether,
            items.SHIELD(),
            1,
            true
        );
        vm.prank(alice);
        crafting.craft(9);
        assertEq(items.balanceOf(alice, items.SHIELD()), 1);
    }

    function testFuzzLootDropRoll(uint256 randomWord) public {
        _mintLootBox(alice, 1);
        vm.prank(alice);
        uint256 requestId = lootDrop.openLootBox();
        mockVrf.fulfill(requestId, randomWord);
        uint256 totalRewards = items.balanceOf(alice, items.SWORD())
            + items.balanceOf(alice, items.SHIELD())
            + items.balanceOf(alice, items.DRAGON_ARMOR());
        assertEq(totalRewards, 1);
    }

    function testFuzzRentalPrice(uint256 priceWei) public {
        priceWei = bound(priceWei, 1 wei, 10 ether);
        _mintRentable(alice, items.SWORD(), 1);
        vm.prank(alice);
        uint256 listingId = rentalVault.list(items.SWORD(), 1, priceWei, 1 days);
        vm.deal(bob, priceWei);
        vm.prank(bob);
        rentalVault.rent{value: priceWei}(listingId);
        assertEq(rentalVault.pendingWithdrawals(alice), priceWei - ((priceWei * rentalVault.feeBps()) / 10_000));
    }

    function testFuzzPriceFeedStaleness(uint256 age) public {
        age = bound(age, 0, 1 days);
        vm.warp(10 days);
        mockFeed.updateAnswerWithTimestamp(2_000e8, block.timestamp - age);
        (int256 answer,,) = priceFeed.latestPrice();
        assertEq(answer, int256(2_000e8));
    }

    function testFuzzYulMathMatchesSolidity(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public {
        amountIn = bound(amountIn, 1, 1e24);
        reserveIn = bound(reserveIn, 1, 1e24);
        reserveOut = bound(reserveOut, 1, 1e24);
        assertEq(
            mathHarness.quoteYul(amountIn, reserveIn, reserveOut),
            mathHarness.quoteSolidity(amountIn, reserveIn, reserveOut)
        );
    }
}
