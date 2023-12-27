// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/libraries/PoolVariables.sol)
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import {PositionKey} from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

/// @title Pool Variables - Library for computing liquidity and ticks for token amounts and prices
/// @notice Provides functions for computing liquidity and ticks for token amounts and prices
library PoolVariables {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint128;

    uint24 private constant GLOBAL_DIVISIONER = 2 * 1e6; // for basis point (0.0001%)

    /// @notice Shows current Optimizer's balances
    /// @param totalAmount0 Current token0 Optimizer's balance
    /// @param totalAmount1 Current token1 Optimizer's balance
    event Snapshot(uint256 indexed totalAmount0, uint256 indexed totalAmount1);

    // Cache struct for calculations
    struct Info {
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0;
        uint256 amount1;
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
    }

    function getInitialTicks(
        IUniswapV3Pool pool,
        ERC20 token0,
        ERC20 token1,
        int24 baseThreshold,
        int24 tickSpacing,
        uint256,
        uint256
    ) internal view returns (uint256 balance0, uint256 balance1, int24 tickLower, int24 tickUpper) {
        (, int24 currentTick,,,,,) = pool.slot0();

        (tickLower, tickUpper) = baseTicks(currentTick, baseThreshold, tickSpacing);

        checkRange(tickLower, tickUpper); // Check ticks also for overflow/underflow

        // Emit snapshot to record balances
        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));
    }

    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    /// @param pool Uniswap V3 pool
    /// @param liquidity  The liquidity being valued
    /// @param _tickLower The lower tick of the range
    /// @param _tickUpper The upper tick of the range
    /// @return amounts of token0 and token1 that corresponds to liquidity
    function amountsForLiquidity(IUniswapV3Pool pool, uint128 liquidity, int24 _tickLower, int24 _tickUpper)
        internal
        view
        returns (uint256, uint256)
    {
        // Get the current price from the pool
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96, TickMath.getSqrtRatioAtTick(_tickLower), TickMath.getSqrtRatioAtTick(_tickUpper), liquidity
        );
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    /// @param pool Uniswap V3 pool
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    /// @param _tickLower The lower tick of the range
    /// @param _tickUpper The upper tick of the range
    /// @return The maximum amount of liquidity that can be held amount0 and amount1
    function liquidityForAmounts(
        IUniswapV3Pool pool,
        uint256 amount0,
        uint256 amount1,
        int24 _tickLower,
        int24 _tickUpper
    ) internal view returns (uint128) {
        // Get the current price from the pool
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();

        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(_tickLower),
            TickMath.getSqrtRatioAtTick(_tickUpper),
            amount0,
            amount1
        );
    }

    /// @dev Common checks for valid tick inputs.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    function checkRange(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert LowerTickMustBeLessThanUpperTick();
        if (tickLower < TickMath.MIN_TICK) revert LowerTickMustBeGreaterThanMinTick();
        if (tickUpper > TickMath.MAX_TICK) revert UpperTickMustBeLessThanMaxTick();
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0) if (tick % tickSpacing != 0) compressed--;

        return compressed * tickSpacing;
    }

    /// @dev Gets ticks with proportion equivalent to the desired amount
    /// @param pool Uniswap V3 pool
    /// @param amount0Desired The desired amount of token0
    /// @param amount1Desired The desired amount of token1
    /// @param baseThreshold The range for upper and lower ticks
    /// @param tickSpacing The pool tick spacing
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function getPositionTicks(
        IUniswapV3Pool pool,
        uint256 amount0Desired,
        uint256 amount1Desired,
        int24 baseThreshold,
        int24 tickSpacing
    ) internal view returns (int24 tickLower, int24 tickUpper) {
        Info memory cache = Info(amount0Desired, amount1Desired, 0, 0, 0, 0, 0);
        // Get the current price and tick from the pool
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();
        // Calc base ticks
        (cache.tickLower, cache.tickUpper) = baseTicks(currentTick, baseThreshold, tickSpacing);
        // Calc amounts of token0, token1 that can be stored in the base range
        // and liquidity that can be stored in the base range
        (cache.amount0, cache.amount1, cache.liquidity) =
            amountsForTicks(sqrtPriceX96, cache.amount0Desired, cache.amount1Desired, cache.tickLower, cache.tickUpper);

        // Get the imbalanced token
        bool zeroGreaterOne = amountsDirection(cache.amount0Desired, cache.amount1Desired, cache.amount0, cache.amount1);
        // Calc new tick(upper or lower) for imbalanced token
        if (zeroGreaterOne) {
            uint160 nextSqrtPrice0 = SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96, cache.liquidity, cache.amount0Desired, false
            );
            cache.tickUpper = floor(TickMath.getTickAtSqrtRatio(nextSqrtPrice0), tickSpacing);
        } else {
            uint160 nextSqrtPrice1 = SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceX96, cache.liquidity, cache.amount1Desired, false
            );
            cache.tickLower = floor(TickMath.getTickAtSqrtRatio(nextSqrtPrice1), tickSpacing);
        }
        checkRange(cache.tickLower, cache.tickUpper);

        tickLower = cache.tickLower;
        tickUpper = cache.tickUpper;
    }

    /// @dev Gets amounts of token0 and token1 that can be stored in range of upper and lower ticks
    /// @param sqrtRatioX96 The current price of Uniswap V3 pool
    /// @param amount0Desired The desired amount of token0
    /// @param amount1Desired The desired amount of token1
    /// @param _tickLower The lower tick of the range
    /// @param _tickUpper The upper tick of the range
    /// @return amount0 amounts of token0 that can be stored in range
    /// @return amount1 amounts of token1 that can be stored in range
    function amountsForTicks(
        uint160 sqrtRatioX96,
        uint256 amount0Desired,
        uint256 amount1Desired,
        int24 _tickLower,
        int24 _tickUpper
    ) internal pure returns (uint256 amount0, uint256 amount1, uint128 liquidity) {
        uint160 lowerSqrtRatio = TickMath.getSqrtRatioAtTick(_tickLower);
        uint160 upperSqrtRatio = TickMath.getSqrtRatioAtTick(_tickUpper);

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96, lowerSqrtRatio, upperSqrtRatio, amount0Desired, amount1Desired
        );

        (amount0, amount1) =
            LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, lowerSqrtRatio, upperSqrtRatio, liquidity);

        // Liquidity that can be stored in base range
        liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, lowerSqrtRatio, upperSqrtRatio, amount0, amount1);
    }

    /// @dev Calc base ticks depending on base threshold and tickspacing
    function baseTicks(int24 currentTick, int24 baseThreshold, int24 tickSpacing)
        private
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        int24 tickFloor = floor(currentTick, tickSpacing);

        tickLower = tickFloor - baseThreshold;
        tickUpper = tickFloor + baseThreshold;
    }

    /// @dev Get imbalanced token
    /// @param amount0Desired The desired amount of token0
    /// @param amount1Desired The desired amount of token1
    /// @param amount0 Amounts of token0 that can be stored in base range
    /// @param amount1 Amounts of token1 that can be stored in base range
    /// @return zeroGreaterOne true if token0 is imbalanced. False if token1 is imbalanced
    function amountsDirection(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0, uint256 amount1)
        internal
        pure
        returns (bool zeroGreaterOne)
    {
        // From: amount0Desired.sub(amount0).mul(amount1Desired) > amount1Desired.sub(amount1).mul(amount0Desired) ?  true : false
        zeroGreaterOne = (amount0Desired - amount0) * amount1Desired > (amount1Desired - amount1) * amount0Desired;
    }

    error DeviationTooHigh();

    // Check price has not moved a lot recently. This mitigates price
    // manipulation during rebalance and also prevents placing orders
    // when it's too volatile.
    function checkDeviation(IUniswapV3Pool pool, int24 maxTwapDeviation, uint32 twapDuration) public view {
        (, int24 currentTick,,,,,) = pool.slot0();
        int24 twap = getTwap(pool, twapDuration);
        int24 deviation = currentTick > twap ? currentTick - twap : twap - currentTick;
        if (deviation > maxTwapDeviation) revert DeviationTooHigh();
    }

    /// @dev Fetches time-weighted average price in ticks from Uniswap pool for a specified duration
    function getTwap(IUniswapV3Pool pool, uint32 twapDuration) private view returns (int24) {
        uint32 _twapDuration = twapDuration;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapDuration;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);
        return int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int32(_twapDuration)));
    }

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    ///////////////////////////////////////////////////////////////*/

    error LowerTickMustBeLessThanUpperTick();
    error LowerTickMustBeGreaterThanMinTick();
    error UpperTickMustBeLessThanMaxTick();
}
