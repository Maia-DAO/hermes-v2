// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {UniswapV3Factory, UniswapV3Pool} from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {IUniswapV3Pool} from "@v3-staker/UniswapV3Staker.sol";

library UniswapV3Assistant {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint160;
    using FixedPointMathLib for uint128;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using SafeTransferLib for ERC20;

    //////////////////////////////////////////////////////////////////
    //                          STRUCTS
    //////////////////////////////////////////////////////////////////

    // Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    struct SwapCallbackData {
        bool zeroForOne;
    }

    //////////////////////////////////////////////////////////////////
    //                          VARIABLES
    //////////////////////////////////////////////////////////////////

    // Equilibrium price for balanced pool
    uint160 public constant balancedSqrtPriceX96 = 79228162514264337593543950336;

    //////////////////////////////////////////////////////////////////
    //                          Deploy
    //////////////////////////////////////////////////////////////////

    // Deploy Uniswap V3 contracts
    function deployUniswapV3()
        internal
        pure
        returns (UniswapV3Factory factory, INonfungiblePositionManager nftManager)
    {
        /// @dev ! If reverting on minting check POOL_INIT_CODE_HASH in PoolAddress.sol
        factory = UniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        nftManager = INonfungiblePositionManager(payable(0xC36442b4a4522E871399CD717aBDD847Ab11FE88));
    }

    //////////////////////////////////////////////////////////////////
    //                          POOL
    //////////////////////////////////////////////////////////////////

    // Create a pool
    function createPool(UniswapV3Factory factory, address token0, address token1, uint24 fee)
        internal
        returns (IUniswapV3Pool pool, UniswapV3Pool poolContract)
    {
        pool = IUniswapV3Pool(factory.createPool(token0, token1, fee));
        poolContract = UniswapV3Pool(address(pool));
    }

    // Initialize a pool
    function initialize(UniswapV3Pool pool, uint160 sqrtPriceX96) internal {
        pool.initialize(sqrtPriceX96);
        pool.increaseObservationCardinalityNext(100);
    }

    // Initialize a pool
    function initializeBalanced(UniswapV3Pool pool) internal {
        pool.initialize(balancedSqrtPriceX96);
        pool.increaseObservationCardinalityNext(100);
    }

    //////////////////////////////////////////////////////////////////
    //                          NFT
    //////////////////////////////////////////////////////////////////

    // Mint a position
    function mintPosition(
        INonfungiblePositionManager nftManager,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal returns (uint256 tokenId) {
        (tokenId,,,) = nftManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 100
            })
        );
    }

    // Mint a position max range
    function mintPositionMaxRange(
        INonfungiblePositionManager nftManager,
        address token0,
        address token1,
        uint24 fee,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal returns (uint256 tokenId) {
        (tokenId,,,) = nftManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
    }
}
