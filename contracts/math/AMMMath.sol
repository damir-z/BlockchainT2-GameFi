// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AMMMath
/// @notice Includes a pure Solidity path and an inline Yul path for gas benchmarking.
library AMMMath {
    uint256 internal constant FEE_NUMERATOR = 997;
    uint256 internal constant FEE_DENOMINATOR = 1_000;

    function quoteOutSolidity(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256)
    {
        require(amountIn != 0, "AMMMath: zero amount");
        require(reserveIn != 0 && reserveOut != 0, "AMMMath: zero reserves");
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    function quoteOutYul(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn != 0, "AMMMath: zero amount");
        require(reserveIn != 0 && reserveOut != 0, "AMMMath: zero reserves");
        assembly {
            let amountInWithFee := mul(amountIn, 997)
            let numerator := mul(amountInWithFee, reserveOut)
            let denominator := add(mul(reserveIn, 1000), amountInWithFee)
            amountOut := div(numerator, denominator)
        }
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
