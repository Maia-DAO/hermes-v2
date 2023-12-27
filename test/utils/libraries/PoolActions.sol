// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/libraries/PoolActions.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {PoolVariables} from "./PoolVariables.sol";

/// @title Pool Actions - Library for conducting uniswap v3 pool actions
/// @author MaiaDAO
/// @notice This library is created to conduct a variety of swap, burn and add liquidity methods.
library PoolActions {
    using PoolVariables for IUniswapV3Pool;

    struct RerangeParams {
        function(
            IUniswapV3Pool,
            ERC20,
            ERC20,
            int24,
            int24,
            uint256,
            uint256
        ) internal view returns (uint256, uint256, int24, int24) getTicksAndAmounts;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
        uint24 poolFee;
    }

    function getThisPositionTicks(
        IUniswapV3Pool pool,
        ERC20 token0,
        ERC20 token1,
        int24 baseThreshold,
        int24 tickSpacing,
        uint256 protocolFees0,
        uint256 protocolFees1
    ) internal view returns (uint256 balance0, uint256 balance1, int24 tickLower, int24 tickUpper) {
        // Emit snapshot to record balances
        balance0 = token0.balanceOf(address(this)) - protocolFees0;
        balance1 = token1.balanceOf(address(this)) - protocolFees1;

        // Get exact ticks depending on Optimizer's balances
        (tickLower, tickUpper) = pool.getPositionTicks(balance0, balance1, baseThreshold, tickSpacing);
    }
}
