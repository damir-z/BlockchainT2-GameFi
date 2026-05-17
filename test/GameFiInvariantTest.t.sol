// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AMMPool} from "../contracts/AMMPool.sol";
import {ResourceToken} from "../contracts/ResourceToken.sol";
import {BaseGameFiTest} from "./BaseGameFiTest.sol";

contract AMMHandler {
    AMMPool public immutable pool;
    uint256 public immutable initialK;
    uint256 public successfulSwaps;

    constructor(AMMPool pool_) {
        pool = pool_;
        (uint256 r0, uint256 r1) = pool.getReserves();
        initialK = r0 * r1;
    }

    function swapToken0(uint256 amountIn) external {
        amountIn = _bound(amountIn, 1 ether, 500 ether);
        ResourceToken token = ResourceToken(address(pool.token0()));
        token.mint(address(this), amountIn);
        token.approve(address(pool), amountIn);
        pool.swap(address(pool.token0()), amountIn, 0, address(this));
        successfulSwaps++;
    }

    function swapToken1(uint256 amountIn) external {
        amountIn = _bound(amountIn, 1 ether, 500 ether);
        ResourceToken token = ResourceToken(address(pool.token1()));
        token.mint(address(this), amountIn);
        token.approve(address(pool), amountIn);
        pool.swap(address(pool.token1()), amountIn, 0, address(this));
        successfulSwaps++;
    }

    function currentK() public view returns (uint256) {
        (uint256 r0, uint256 r1) = pool.getReserves();
        return r0 * r1;
    }

    function _bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (x < min) return min;
        if (x > max) return min + (x % (max - min + 1));
        return x;
    }
}

contract GameFiInvariantTest is StdInvariant, BaseGameFiTest {
    AMMHandler internal handler;

    function setUp() public override {
        BaseGameFiTest.setUp();
        handler = new AMMHandler(pool);
        ResourceToken(address(pool.token0())).grantRole(gold.MINTER_ROLE(), address(handler));
        ResourceToken(address(pool.token1())).grantRole(gold.MINTER_ROLE(), address(handler));
        targetContract(address(handler));
    }

    function invariant_KNeverDecreasesOnSwap() public view {
        assertGe(handler.currentK(), handler.initialK());
    }

    function invariant_ReservesMatchBalances() public view {
        (uint256 r0, uint256 r1) = pool.getReserves();
        assertEq(IERC20(address(pool.token0())).balanceOf(address(pool)), r0);
        assertEq(IERC20(address(pool.token1())).balanceOf(address(pool)), r1);
    }

    function invariant_LpSupplyConservation() public view {
        assertGe(pool.totalSupply(), pool.MINIMUM_LIQUIDITY());
        assertEq(pool.balanceOf(address(1)), pool.MINIMUM_LIQUIDITY());
    }

    function invariant_TreasuryAccountingNonNegative() public view {
        assertGe(address(rentalVault).balance, rentalVault.pendingWithdrawals(alice));
    }

    function invariant_VaultRoundingWithinAssets() public view {
        if (vault.totalSupply() == 0) return;
        assertLe(vault.previewRedeem(vault.totalSupply()), vault.totalAssets());
    }

    function invariant_ResourceSupplyCoversPoolReserves() public view {
        (uint256 r0, uint256 r1) = pool.getReserves();
        assertGe(ResourceToken(address(pool.token0())).totalSupply(), r0);
        assertGe(ResourceToken(address(pool.token1())).totalSupply(), r1);
    }
}
