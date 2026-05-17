// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../contracts/interfaces/AggregatorV3Interface.sol";

interface IUniswapV2Router02 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
}

contract GameFiForkTest is Test {
    address internal constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant MAINNET_CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant MAINNET_UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function _selectForkOrSkip() internal returns (bool) {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return false;
        uint256 forkId = vm.createFork(rpc);
        vm.selectFork(forkId);
        return true;
    }

    function testForkReadsUSDCMainnetSupply() public {
        if (!_selectForkOrSkip()) return;
        uint256 supply = IERC20(MAINNET_USDC).totalSupply();
        assertGt(supply, 0);
    }

    function testForkReadsChainlinkEthUsdFeed() public {
        if (!_selectForkOrSkip()) return;
        AggregatorV3Interface feed = AggregatorV3Interface(MAINNET_CHAINLINK_ETH_USD);
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
    }

    function testForkReadsUniswapV2Router() public {
        if (!_selectForkOrSkip()) return;
        IUniswapV2Router02 router = IUniswapV2Router02(MAINNET_UNISWAP_V2_ROUTER);
        assertTrue(router.factory() != address(0));
        assertTrue(router.WETH() != address(0));
    }
}
