// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AMMMath} from "./AMMMath.sol";

contract AMMMathHarness {
    function quoteSolidity(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256) {
        return AMMMath.quoteOutSolidity(amountIn, reserveIn, reserveOut);
    }

    function quoteYul(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256) {
        return AMMMath.quoteOutYul(amountIn, reserveIn, reserveOut);
    }
}
