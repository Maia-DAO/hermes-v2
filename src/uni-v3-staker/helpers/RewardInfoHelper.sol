// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {IncentiveId} from "../libraries/IncentiveId.sol";
import {IncentiveTime} from "../libraries/IncentiveTime.sol";
import {NFTPositionInfo} from "../libraries/NFTPositionInfo.sol";
import {RewardMath} from "../libraries/RewardMath.sol";

import {IUniswapV3Staker} from "../interfaces/IUniswapV3Staker.sol";

/// @title A helper contract to fetch information about rewards for a given token ID
/// @author Maia DAO
contract RewardInfoHelper {
    /*///////////////////////////////////////////////////////////////
                               IMMUTABLES
    ///////////////////////////////////////////////////////////////*/

    IUniswapV3Factory private immutable factory;

    INonfungiblePositionManager private immutable nonfungiblePositionManager;

    /// @notice The Uniswap V3 Staker contract
    IUniswapV3Staker private immutable staker;

    /*///////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    constructor(
        IUniswapV3Factory _factory,
        INonfungiblePositionManager _nonfungiblePositionManager,
        IUniswapV3Staker _staker
    ) {
        factory = _factory;
        nonfungiblePositionManager = _nonfungiblePositionManager;
        staker = _staker;
    }

    /*///////////////////////////////////////////////////////////////
                                REWARDS
    ///////////////////////////////////////////////////////////////*/

    function getRewardInfo(uint256 tokenId)
        external
        view
        returns (uint256 timestamp, uint256 reward, uint160 boostedInsideX128, uint160 secondsInsideX128)
    {
        timestamp = block.timestamp;

        (IUniswapV3Pool pool,,,) = NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId);

        (address owner, int24 tickLower, int24 tickUpper, uint40 stakedTimestamp) = staker.deposits(tokenId);

        if (stakedTimestamp == 0) return (timestamp, 0, 0, 0);

        IUniswapV3Staker.IncentiveKey memory key =
            IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeStart(stakedTimestamp)});

        (uint96 endTime, uint256 stakedDuration) =
            IncentiveTime.getEndAndDuration(key.startTime, stakedTimestamp, block.timestamp);

        bytes32 incentiveId = IncentiveId.compute(key);
        {
            uint128 boostAmount;
            uint128 boostTotalSupply;
            // If tokenId is attached to gauge
            if (staker.userAttachements(owner, key.pool) == tokenId) {
                // get boost amount and total supply
                (boostAmount, boostTotalSupply) =
                    staker.hermesGaugeBoost().getUserGaugeBoost(owner, address(staker.gauges(key.pool)));
            }

            (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) = staker.stakes(tokenId, incentiveId);
            if (liquidity == 0) revert IUniswapV3Staker.TokenNotStaked();

            (, uint160 secondsPerLiquidityInsideX128,) = key.pool.snapshotCumulativesInside(tickLower, tickUpper);

            unchecked {
                // this operation is safe, as the difference cannot be greater than 1/stake.liquidity
                secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128) * liquidity;
            }

            boostedInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
                stakedDuration,
                liquidity,
                uint128(boostAmount),
                uint128(boostTotalSupply),
                secondsPerLiquidityInsideInitialX128,
                secondsPerLiquidityInsideX128
            );
        }

        (uint256 totalRewardUnclaimed, uint160 totalSecondsClaimedX128,) = staker.incentives(incentiveId);
        reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, key.startTime, endTime, boostedInsideX128, block.timestamp
        );
    }
}
