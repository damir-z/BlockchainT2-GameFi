// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {AMMMath} from "./math/AMMMath.sol";

/// @title AMMPool
/// @notice From-scratch constant product AMM for fungible game resources, with LP tokens.
contract AMMPool is ERC20, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public constant MINIMUM_LIQUIDITY = 1_000;

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint112 private reserve0;
    uint112 private reserve1;

    event LiquidityAdded(address indexed provider, address indexed to, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address indexed to, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed trader, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed to);
    event ReservesSynced(uint112 reserve0, uint112 reserve1);

    constructor(address token0_, address token1_, address admin)
        ERC20("GameFi Resource LP", "GFLP")
    {
        require(token0_ != address(0) && token1_ != address(0), "AMMPool: zero token");
        require(token0_ != token1_, "AMMPool: identical tokens");
        require(admin != address(0), "AMMPool: zero admin");
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function quote(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        require(tokenIn == address(token0) || tokenIn == address(token1), "AMMPool: invalid token");
        uint256 reserveIn;
        uint256 reserveOut;
        if (tokenIn == address(token0)) {
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else {
            reserveIn = reserve1;
            reserveOut = reserve0;
        }
        amountOut = AMMMath.quoteOutYul(amountIn, reserveIn, reserveOut);
    }

    function addLiquidity(uint256 amount0, uint256 amount1, uint256 minLiquidity, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 liquidity)
    {
        require(to != address(0), "AMMPool: zero to");
        require(amount0 != 0 && amount1 != 0, "AMMPool: zero amount");

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        uint256 supply = totalSupply();
        if (supply == 0) {
            liquidity = AMMMath.sqrt(amount0 * amount1);
            require(liquidity > MINIMUM_LIQUIDITY, "AMMPool: insufficient initial liquidity");
            _mint(address(1), MINIMUM_LIQUIDITY);
            liquidity -= MINIMUM_LIQUIDITY;
        } else {
            liquidity = AMMMath.min((amount0 * supply) / reserve0, (amount1 * supply) / reserve1);
        }

        require(liquidity >= minLiquidity && liquidity != 0, "AMMPool: insufficient liquidity minted");
        _mint(to, liquidity);
        _sync();
        emit LiquidityAdded(msg.sender, to, amount0, amount1, liquidity);
    }

    function removeLiquidity(uint256 liquidity, uint256 minAmount0, uint256 minAmount1, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        require(to != address(0), "AMMPool: zero to");
        require(liquidity != 0, "AMMPool: zero liquidity");
        uint256 supply = totalSupply();
        amount0 = (liquidity * reserve0) / supply;
        amount1 = (liquidity * reserve1) / supply;
        require(amount0 >= minAmount0 && amount1 >= minAmount1, "AMMPool: slippage");
        require(amount0 != 0 && amount1 != 0, "AMMPool: zero output");

        _burn(msg.sender, liquidity);
        _updateReserves(uint256(reserve0) - amount0, uint256(reserve1) - amount1);
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);
        emit LiquidityRemoved(msg.sender, to, amount0, amount1, liquidity);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        require(to != address(0), "AMMPool: zero to");
        bool zeroForOne = tokenIn == address(token0);
        require(zeroForOne || tokenIn == address(token1), "AMMPool: invalid token");
        require(amountIn != 0, "AMMPool: zero input");

        IERC20 input = zeroForOne ? token0 : token1;
        IERC20 output = zeroForOne ? token1 : token0;
        uint256 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;

        amountOut = AMMMath.quoteOutYul(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "AMMPool: slippage");
        require(amountOut < reserveOut, "AMMPool: insufficient liquidity");

        uint256 oldK = uint256(reserve0) * uint256(reserve1);
        input.safeTransferFrom(msg.sender, address(this), amountIn);
        output.safeTransfer(to, amountOut);
        _sync();
        require(uint256(reserve0) * uint256(reserve1) >= oldK, "AMMPool: k decreased");

        emit Swap(msg.sender, tokenIn, amountIn, amountOut, to);
    }

    function sync() external nonReentrant {
        _sync();
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _sync() internal {
        _updateReserves(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    function _updateReserves(uint256 balance0, uint256 balance1) internal {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "AMMPool: reserve overflow");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit ReservesSynced(reserve0, reserve1);
    }
}
