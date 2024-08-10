// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {UniswapV3Factory, UniswapV3Pool} from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";

import {IWETH9} from "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {
    UniswapV3GaugeFactory,
    FlywheelGaugeRewards,
    BaseV2GaugeManager
} from "@gauges/factories/UniswapV3GaugeFactory.sol";
import {BribesFactory, FlywheelBoosterGaugeWeight} from "@gauges/factories/BribesFactory.sol";
import {UniswapV3Gauge, BaseV2Gauge} from "@gauges/UniswapV3Gauge.sol";

import {BaseV2Minter} from "@hermes/minters/BaseV2Minter.sol";
import {BurntHermes} from "@hermes/BurntHermes.sol";

import {UniswapV3Assistant} from "@test/utils/UniswapV3Assistant.t.sol";

import {PoolVariables} from "@test/utils/libraries/PoolVariables.sol";

import {
    IUniswapV3Pool,
    UniswapV3Staker,
    IUniswapV3Staker,
    IncentiveTime,
    NFTPositionInfo
} from "@v3-staker/UniswapV3Staker.sol";

contract UniswapV3StakerTest is Test, IERC721Receiver {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint160;
    using FixedPointMathLib for uint128;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for MockERC20;

    //////////////////////////////////////////////////////////////////
    //                          VARIABLES
    //////////////////////////////////////////////////////////////////
    BurntHermes bHermesToken;

    BaseV2Minter baseV2Minter;

    FlywheelGaugeRewards flywheelGaugeRewards;
    BribesFactory bribesFactory;

    FlywheelBoosterGaugeWeight flywheelGaugeWeightBooster;

    UniswapV3GaugeFactory uniswapV3GaugeFactory;
    UniswapV3Gauge gauge;

    MockERC20 token0;
    MockERC20 token1;

    MockERC20 rewardToken;

    UniswapV3Factory uniswapV3Factory;
    INonfungiblePositionManager nonfungiblePositionManager;

    IUniswapV3Pool pool;
    UniswapV3Pool poolContract;

    IWETH9 WETH9 = IWETH9(address(0));

    address constant user0 = address(0xDEAD);
    address constant user1 = address(0xBEEF);
    address constant user2 = address(0xCAFE);

    IUniswapV3Staker uniswapV3Staker;
    UniswapV3Staker uniswapV3StakerContract;

    IUniswapV3Staker.IncentiveKey key;
    bytes32 incentiveId;

    uint24 constant poolFee = 3000;

    //////////////////////////////////////////////////////////////////
    //                          SET UP
    //////////////////////////////////////////////////////////////////

    function setUp() public {
        vm.selectFork(vm.createFork(vm.envString("ARBITRUM_RPC_URL"), 154344948));

        (uniswapV3Factory, nonfungiblePositionManager) = UniswapV3Assistant.deployUniswapV3();

        token1 = new MockERC20("test token", "TKN", 18);
        token0 = new MockERC20("test token", "TKN", 18);
        rewardToken = new MockERC20("test reward token", "RTKN", 18);

        bHermesToken = new BurntHermes(rewardToken, address(this), address(this));

        flywheelGaugeWeightBooster = new FlywheelBoosterGaugeWeight(address(this));

        bribesFactory = flywheelGaugeWeightBooster.bribesFactory();

        baseV2Minter = new BaseV2Minter(address(bHermesToken), address(flywheelGaugeRewards), address(this));

        flywheelGaugeRewards = new FlywheelGaugeRewards(address(rewardToken), bHermesToken.gaugeWeight(), baseV2Minter);
        baseV2Minter.initialize(flywheelGaugeRewards);

        uniswapV3GaugeFactory = new UniswapV3GaugeFactory(
            BaseV2GaugeManager(address(0)),
            bHermesToken.gaugeBoost(),
            uniswapV3Factory,
            nonfungiblePositionManager,
            flywheelGaugeRewards,
            bribesFactory,
            address(this)
        );

        vm.mockCall(address(0), abi.encodeWithSignature("addGauge(address)"), abi.encode(""));

        uniswapV3StakerContract = uniswapV3GaugeFactory.uniswapV3Staker();

        uniswapV3Staker = IUniswapV3Staker(address(uniswapV3StakerContract));
    }

    // Create a new Uniswap V3 Gauge from a Uniswap V3 pool
    function createGaugeAndAddToGaugeBoost(IUniswapV3Pool _pool, uint256 minWidth)
        internal
        returns (UniswapV3Gauge _gauge)
    {
        uniswapV3GaugeFactory.createGauge(address(_pool), abi.encode(uint24(minWidth)));
        _gauge = UniswapV3Gauge(address(uniswapV3GaugeFactory.strategyGauges(address(_pool))));
        bHermesToken.gaugeBoost().addGauge(address(_gauge));
    }

    // Create a Uniswap V3 Staker incentive
    function createIncentive(IUniswapV3Staker.IncentiveKey memory _key, uint256 amount) internal {
        uniswapV3Staker.createIncentive(_key, amount);
    }

    // Create a Uniswap V3 Staker incentive with the gauge as msg.sender
    function createIncentiveFromGauge(uint256 amount) internal {
        uniswapV3Staker.createIncentiveFromGauge(amount);
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function newNFT(int24 tickLower, int24 tickUpper, uint128 liquidity) internal returns (uint256 tokenId) {
        (uint256 amount0, uint256 amount1) = PoolVariables.amountsForLiquidity(pool, liquidity, tickLower, tickUpper);

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);
        token0.approve(address(nonfungiblePositionManager), amount0);
        token1.approve(address(nonfungiblePositionManager), amount1);

        pool.slot0();

        tokenId = UniswapV3Assistant.mintPosition(
            nonfungiblePositionManager,
            address(token0),
            address(token1),
            poolFee,
            tickLower,
            tickUpper,
            amount0,
            amount1
        );
        vm.warp(block.timestamp + 100);
    }

    //////////////////////////////////////////////////////////////////
    //                      TESTS DEPOSIT
    //////////////////////////////////////////////////////////////////

    // Test minting a position and transferring it to Uniswap V3 Staker, before creating a gauge
    function testNoGauge() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        // Transfer and stake the position in Uniswap V3 Staker
        vm.expectRevert(IUniswapV3Staker.NonExistentIncentiveError.selector);
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);
    }

    function testGaugeNoIncentive() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        uint256 minWidth = 10;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Transfer and stake the position in Uniswap V3 Staker
        vm.expectRevert(IUniswapV3Staker.NonExistentIncentiveError.selector);
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);
    }

    // Test minting a position and transferring it to Uniswap V3 Staker, after creating a gauge
    function testRangeTooSmall() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        uint256 minWidth = 121;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key, rewardAmount);
        vm.warp(key.startTime);

        // Transfer and stake the position in Uniswap V3 Staker
        vm.expectRevert(abi.encodeWithSignature("RangeTooSmallError()"));
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);
    }

    // Test minting a position and transferring it to Uniswap V3 Staker, after creating a gauge
    function testDeposit() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        uint256 minWidth = 10;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key, rewardAmount);
        vm.warp(key.startTime);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        // Check that the position is in Uniswap V3 Staker
        assertEq(nonfungiblePositionManager.ownerOf(tokenId), address(uniswapV3Staker));
        (address owner,,, uint256 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);
        assertEq(owner, address(this));
        assertEq(stakedTimestamp, block.timestamp);
    }

    // Test minting a position and transferring it to Uniswap V3 Staker, after creating a gauge
    function testDepositTwiceError() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        uint256 minWidth = 10;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key, rewardAmount);
        vm.warp(key.startTime);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        // Check that the position is in Uniswap V3 Staker
        assertEq(nonfungiblePositionManager.ownerOf(tokenId), address(uniswapV3Staker));
        (address owner,,, uint256 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);
        assertEq(owner, address(this));
        assertEq(stakedTimestamp, block.timestamp);

        vm.expectRevert(IUniswapV3Staker.TokenStakedError.selector);
        uniswapV3Staker.stakeToken(tokenId);
    }

    // Test minting a position and transferring it to Uniswap V3 Staker, after creating a gauge
    function testFullIncentiveNoBoost() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        uint256 minWidth = 10;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key, rewardAmount);
        vm.warp(key.startTime);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        // Check that the position is in Uniswap V3 Staker
        assertEq(nonfungiblePositionManager.ownerOf(tokenId), address(uniswapV3Staker));
        (address owner,,, uint256 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);
        assertEq(owner, address(this));
        assertEq(stakedTimestamp, block.timestamp);

        vm.warp(block.timestamp + 1 weeks);

        (uint256 reward,) = uniswapV3Staker.getRewardInfo(tokenId);
        assertEq(reward, ((1 ether * 4) / 10));

        uniswapV3Staker.unstakeToken(tokenId);

        assertEq(uniswapV3StakerContract.tokenIdRewards(tokenId), ((1 ether * 4) / 10));

        uniswapV3Staker.claimAllRewards(address(this));

        assertEq(rewardToken.balanceOf(address(this)), ((1 ether * 4) / 10));
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), 0);

        uniswapV3Staker.endIncentive(key);

        assertEq(rewardToken.balanceOf(address(baseV2Minter)), (1 ether * 6) / 10);
    }

    // Test minting a position and transferring it to Uniswap V3 Staker, after creating a gauge
    function testFullIncentiveFullBoost() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        uint256 minWidth = 10;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key, rewardAmount);

        rewardToken.mint(address(this), 1 ether);
        rewardToken.approve(address(bHermesToken), 1 ether);
        bHermesToken.deposit(1 ether, address(this));
        bHermesToken.claimBoost(1 ether);
        vm.warp(key.startTime);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        // Check that the position is in Uniswap V3 Staker
        assertEq(nonfungiblePositionManager.ownerOf(tokenId), address(uniswapV3Staker));
        (address owner,,, uint256 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);
        assertEq(owner, address(this));
        assertEq(stakedTimestamp, block.timestamp);

        vm.warp(block.timestamp + 1 weeks);

        (uint256 reward,) = uniswapV3Staker.getRewardInfo(tokenId);
        assertEq(reward, 1 ether);

        uniswapV3Staker.unstakeToken(tokenId);

        assertEq(uniswapV3StakerContract.tokenIdRewards(tokenId), 1 ether);

        uniswapV3Staker.claimAllRewards(address(this));

        assertEq(rewardToken.balanceOf(address(this)), 1 ether);
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), 0);

        vm.expectRevert(abi.encodeWithSignature("EndIncentiveNoRefundAvailable()"));
        uniswapV3Staker.endIncentive(key);
    }

    // Test minting a position and transferring it to Uniswap V3 Staker, after creating a gauge
    function testHalfIncentiveFullBoost() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        uint256 minWidth = 10;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key, rewardAmount);

        rewardToken.mint(address(this), 1 ether);
        rewardToken.approve(address(bHermesToken), 1 ether);
        bHermesToken.deposit(1 ether, address(this));
        bHermesToken.claimBoost(1 ether);
        vm.warp(key.startTime + 1 weeks / 2);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        // Check that the position is in Uniswap V3 Staker
        assertEq(nonfungiblePositionManager.ownerOf(tokenId), address(uniswapV3Staker));
        (address owner,,, uint256 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);
        assertEq(owner, address(this));
        assertEq(stakedTimestamp, block.timestamp);

        vm.warp(block.timestamp + 1 weeks / 2);

        (uint256 reward,) = uniswapV3Staker.getRewardInfo(tokenId);
        assertEq(reward, 1 ether / 2);

        uniswapV3Staker.unstakeToken(tokenId);

        assertEq(uniswapV3StakerContract.tokenIdRewards(tokenId), 1 ether / 2);

        uniswapV3Staker.claimAllRewards(address(this));

        assertEq(rewardToken.balanceOf(address(this)), 1 ether / 2);
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), 0);

        uniswapV3Staker.endIncentive(key);

        assertEq(rewardToken.balanceOf(address(baseV2Minter)), 1 ether / 2);
    }

    struct SwapCallbackData {
        bool zeroForOne;
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external {
        require(msg.sender == address(pool), "FP");
        require(amount0 > 0 || amount1 > 0, "LEZ"); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        bool zeroForOne = data.zeroForOne;

        if (zeroForOne) {
            token0.mint(address(this), uint256(amount0));
            token0.transfer(msg.sender, uint256(amount0));
        } else {
            token1.mint(address(this), uint256(amount1));
            token1.transfer(msg.sender, uint256(amount1));
        }
    }

    // Test minting a position and transferring it to Uniswap V3 Staker, after creating a gauge
    function testAudit1() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        // 3338502497096994491500 to give 1 ether per token with 0.3% fee and -60,60 ticks
        newNFT(-180, 180, 3338502497096994491500);
        newNFT(-60, 60, 3338502497096994491500);

        vm.warp(block.timestamp + 100);

        // @audit Step 1: Swap to make currentTick go to (60, 180) range
        uint256 amountSpecified = 30 ether;
        bool zeroForOne = false;
        pool.swap(
            address(this),
            zeroForOne,
            int256(amountSpecified),
            1461446703485210103287273052203988822378723970342 - 1, // MAX_SQRT_RATIO - 1
            abi.encode(SwapCallbackData({zeroForOne: zeroForOne}))
        );
        (, int24 _currentTick,,,,,) = pool.slot0();
        console2.logInt(int256(_currentTick));

        vm.warp(block.timestamp + 100);

        // @audit Step 2: Swap back to make currentTick go back to (-60, 60) range
        zeroForOne = true;
        pool.swap(
            address(this),
            zeroForOne,
            int256(amountSpecified),
            4295128739 + 1, // MIN_SQRT_RATIO + 1
            abi.encode(SwapCallbackData({zeroForOne: zeroForOne}))
        );

        (, _currentTick,,,,,) = pool.slot0();
        console2.logInt(int256(_currentTick));

        vm.warp(block.timestamp + 100);

        // @audit Step 3: Create normal Incentive
        uint256 minWidth = 10;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);
        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1000 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key, rewardAmount);

        // @audit Step 4: Now we have secondsPerLiquidity of tick 60 is not equal to 0.
        //        We just need to create a position with range [-120, 60],
        //        then secondsPerLiquidityInside of this position will be overflow
        vm.warp(key.startTime + 1);
        int24 tickLower = -120;
        int24 tickUpper = 60;
        uint256 tokenId = newNFT(tickLower, tickUpper, 3338502497096994491500);
        (, uint160 secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(tickLower, tickUpper);
        console2.logUint(uint256(secondsPerLiquidityInsideX128));

        // @audit Step 5: Stake the position
        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        // @audit Step 6: Increase time to make `secondsPerLiquidity` go from negative to positive value
        //        Then `unstakeToken` will revert
        vm.warp(block.timestamp + 5 weeks);

        (, secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(tickLower, tickUpper);
        console2.logUint(uint256(secondsPerLiquidityInsideX128));

        uniswapV3Staker.unstakeToken(tokenId);
    }

    // Test creating a gauge and an incentive
    function testCreateIncentive() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);
        uint256 minWidth = 120;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        uint256 balanceBefore = rewardToken.balanceOf(address(uniswapV3Staker));

        createIncentive(key, rewardAmount);

        assertEq(uniswapV3Staker.poolsMinimumWidth(pool), minWidth);
        assertEq(address(uniswapV3Staker.bribeDepots(pool)), address(gauge.multiRewardsDepot()));

        (uint256 totalRewardUnclaimed, uint160 totalSecondsClaimedX128, uint96 numberOfStakes) =
            uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(totalRewardUnclaimed, rewardAmount);
        assertEq(totalSecondsClaimedX128, 0);
        assertEq(numberOfStakes, 0);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceBefore + rewardAmount);
    }

    // Test creating a gauge and an incentive, then depositing an NFT in the incentive
    function testCreateIncentiveAndDeposit() public {
        testCreateIncentive();

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        (, int24 _tickLower, int24 _tickUpper, uint128 _liquidity) =
            NFTPositionInfo.getPositionInfo(uniswapV3Factory, nonfungiblePositionManager, tokenId);

        vm.warp(key.startTime);

        (, uint160 secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(_tickLower, _tickUpper);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        (address owner, int24 tickLower, int24 tickUpper, uint40 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);

        assertEq(owner, address(this));
        assertEq(tickLower, _tickLower);
        assertEq(tickUpper, _tickUpper);
        assertEq(stakedTimestamp, block.timestamp);

        assertEq(uniswapV3Staker.userAttachements(address(this), pool), tokenId);

        (,, uint96 numberOfStakes) = uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(numberOfStakes, 1);

        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) =
            uniswapV3Staker.stakes(tokenId, keccak256(abi.encode(key)));

        assertEq(secondsPerLiquidityInsideInitialX128, secondsPerLiquidityInsideX128);
        assertEq(liquidity, _liquidity);
    }

    // Test creating a gauge and an incentive, then depositing an NFT in the incentive with liquidity > type(uint96).max
    function testCreateIncentiveAndDepositHighLiquidity() public {
        testCreateIncentive();

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        uint256 tokenId = newNFT(-60, 60, type(uint112).max);

        (, int24 _tickLower, int24 _tickUpper, uint128 _liquidity) =
            NFTPositionInfo.getPositionInfo(uniswapV3Factory, nonfungiblePositionManager, tokenId);

        vm.warp(key.startTime);

        (, uint160 secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(_tickLower, _tickUpper);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        (address owner, int24 tickLower, int24 tickUpper, uint40 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);

        assertEq(owner, address(this));
        assertEq(tickLower, _tickLower);
        assertEq(tickUpper, _tickUpper);
        assertEq(stakedTimestamp, block.timestamp);

        assertEq(uniswapV3Staker.userAttachements(address(this), pool), tokenId);

        (,, uint96 numberOfStakes) = uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(numberOfStakes, 1);

        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) =
            uniswapV3Staker.stakes(tokenId, keccak256(abi.encode(key)));

        assertEq(secondsPerLiquidityInsideInitialX128, secondsPerLiquidityInsideX128);
        assertEq(liquidity, _liquidity);
    }

    // Test creating a gauge and then throw when creating an incentive with error: IncentiveStartTimeNotAtEndOfAnEpoch
    function testCreateIncentiveIncentiveStartTimeNotAtEndOfAnEpoch() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);
        uint256 minWidth = 120;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp) + 1});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        vm.expectRevert(IUniswapV3Staker.IncentiveStartTimeNotAtEndOfAnEpoch.selector);
        createIncentive(key, rewardAmount);
    }

    // Test creating a gauge and then throw when creating an incentive with error: IncentiveStartTimeMustBeNowOrInTheFuture
    function testCreateIncentiveIncentiveStartTimeMustBeNowOrInTheFuture() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);
        uint256 minWidth = 120;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeStart(block.timestamp - 1)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        vm.expectRevert(IUniswapV3Staker.IncentiveStartTimeMustBeNowOrInTheFuture.selector);
        createIncentive(key, rewardAmount);
    }

    // Test creating a gauge and then throw when creating an incentive with error: IncentiveStartTimeTooFarIntoFuture
    function testCreateIncentiveIncentiveStartTimeTooFarIntoFuture() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);
        uint256 minWidth = 120;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key =
            IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp) + 52 weeks});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        vm.expectRevert(IUniswapV3Staker.IncentiveStartTimeTooFarIntoFuture.selector);
        createIncentive(key, rewardAmount);
    }

    // Test creating a gauge and then throw when creating an incentive with error: IncentiveCannotBeCreatedForPoolWithNoGauge
    function testCreateIncentiveIncentiveCannotBeCreatedForPoolWithNoGauge() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        vm.expectRevert(IUniswapV3Staker.IncentiveCannotBeCreatedForPoolWithNoGauge.selector);
        createIncentive(key, rewardAmount);
    }

    // Test creating a gauge and an incentive from the created gauge
    function testCreateIncentiveFromGauge() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);
        uint256 minWidth = 120;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(gauge), rewardAmount);

        vm.startPrank(address(gauge));

        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        uint256 balanceBefore = rewardToken.balanceOf(address(uniswapV3Staker));

        createIncentiveFromGauge(rewardAmount);
        vm.stopPrank();

        assertEq(uniswapV3Staker.poolsMinimumWidth(pool), minWidth);
        assertEq(address(uniswapV3Staker.bribeDepots(pool)), address(gauge.multiRewardsDepot()));

        (uint256 totalRewardUnclaimed, uint160 totalSecondsClaimedX128, uint96 numberOfStakes) =
            uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(totalRewardUnclaimed, rewardAmount);
        assertEq(totalSecondsClaimedX128, 0);
        assertEq(numberOfStakes, 0);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceBefore + rewardAmount);
    }

    // Test creating a gauge and an incentive from the created gauge with error: IncentiveCallerMustBeRegisteredGauge
    function testCreateIncentiveFromGaugeIncentiveCallerMustBeRegisteredGauge() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);

        // Create a Uniswap V3 Staker incentive
        key = IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(gauge), rewardAmount);

        vm.startPrank(address(gauge));

        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        vm.expectRevert(IUniswapV3Staker.IncentiveCallerMustBeRegisteredGauge.selector);
        createIncentiveFromGauge(rewardAmount);
        vm.stopPrank();
    }

    // Test end an incentive
    function testEndIncentive() public {
        testCreateIncentiveFromGauge();

        vm.warp(key.startTime + 1 weeks);

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceMinterBefore = rewardToken.balanceOf(address(baseV2Minter));

        (uint256 totalRewardUnclaimedBefore, uint160 totalSecondsClaimedX128Before, uint96 numberOfStakesBefore) =
            uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(numberOfStakesBefore, 0);

        uniswapV3Staker.endIncentive(key);

        (uint256 totalRewardUnclaimed, uint160 totalSecondsClaimedX128, uint96 numberOfStakes) =
            uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(totalRewardUnclaimed, 0);
        assertEq(totalSecondsClaimedX128, totalSecondsClaimedX128Before);
        assertEq(numberOfStakes, numberOfStakesBefore);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore - totalRewardUnclaimedBefore);
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), balanceMinterBefore + totalRewardUnclaimedBefore);
    }

    // Test end an incentive with error: EndIncentiveBeforeEndTime
    function testEndIncentiveEndIncentiveBeforeEndTime() public {
        testCreateIncentiveFromGauge();

        vm.expectRevert(IUniswapV3Staker.EndIncentiveBeforeEndTime.selector);
        uniswapV3Staker.endIncentive(key);
    }

    // Test end an incentive with error: EndIncentiveNoRefundAvailable
    function testEndIncentiveEndIncentiveNoRefundAvailable() public {
        testCreateIncentiveFromGauge();

        vm.warp(key.startTime + 1 weeks);

        uniswapV3Staker.endIncentive(key);

        vm.expectRevert(IUniswapV3Staker.EndIncentiveNoRefundAvailable.selector);
        uniswapV3Staker.endIncentive(key);
    }

    // Test end an incentive with error: EndIncentiveWhileStakesArePresent
    function testEndIncentiveEndIncentiveWhileStakesArePresent() public {
        testCreateIncentiveFromGauge();

        // Initialize 1:1 0.3% fee pool
        UniswapV3Assistant.initializeBalanced(poolContract);
        vm.warp(block.timestamp + 100);

        uint256 tokenId = newNFT(-60, 60, 3338502497096994491500);

        vm.warp(key.startTime);

        // Transfer and stake the position in Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        vm.warp(key.startTime + 1 weeks);

        vm.expectRevert(IUniswapV3Staker.EndIncentiveWhileStakesArePresent.selector);
        uniswapV3Staker.endIncentive(key);
    }

    // Test unstaking a token from an incentive
    function testUnstakeTokenHalfIncentive() public returns (uint256 tokenId) {
        testCreateIncentiveAndDeposit();

        tokenId = uniswapV3Staker.userAttachements(address(this), pool);

        vm.warp(key.startTime + 0.5 weeks);

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceMinterBefore = rewardToken.balanceOf(address(baseV2Minter));

        (uint256 totalRewardUnclaimedBefore,, uint96 numberOfStakesBefore) =
            uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        uniswapV3Staker.unstakeToken(tokenId);

        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) =
            uniswapV3Staker.stakes(tokenId, keccak256(abi.encode(key)));

        (uint256 totalRewardUnclaimed,, uint96 numberOfStakes) = uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(totalRewardUnclaimed, totalRewardUnclaimedBefore * 8 / 10);
        assertEq(numberOfStakes, numberOfStakesBefore - 1);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore);
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), balanceMinterBefore);

        assertEq(secondsPerLiquidityInsideInitialX128, 0);
        assertEq(liquidity, 0);
    }

    // Test unstaking a token from an incentive
    function testUnstakeTokenHalfIncentiveWithKey() public returns (uint256 tokenId) {
        testCreateIncentiveAndDeposit();

        tokenId = uniswapV3Staker.userAttachements(address(this), pool);

        vm.warp(key.startTime + 0.5 weeks);

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceMinterBefore = rewardToken.balanceOf(address(baseV2Minter));

        (uint256 totalRewardUnclaimedBefore,, uint96 numberOfStakesBefore) =
            uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        uniswapV3Staker.unstakeToken(key, tokenId);

        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) =
            uniswapV3Staker.stakes(tokenId, keccak256(abi.encode(key)));

        (uint256 totalRewardUnclaimed,, uint96 numberOfStakes) = uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(totalRewardUnclaimed, totalRewardUnclaimedBefore * 8 / 10);
        assertEq(numberOfStakes, numberOfStakesBefore - 1);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore);
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), balanceMinterBefore);

        assertEq(secondsPerLiquidityInsideInitialX128, 0);
        assertEq(liquidity, 0);
    }

    // Test unstaking a token from an incentive and then staking it again
    function testUnstakeTokenHalfIncentiveAndStakeAgain() public {
        uint256 tokenId = testUnstakeTokenHalfIncentive();

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceMinterBefore = rewardToken.balanceOf(address(baseV2Minter));

        (uint256 totalRewardUnclaimedBefore,, uint96 numberOfStakesBefore) =
            uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        (, int24 _tickLower, int24 _tickUpper, uint128 _liquidity) =
            NFTPositionInfo.getPositionInfo(uniswapV3Factory, nonfungiblePositionManager, tokenId);

        (, uint160 secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(_tickLower, _tickUpper);

        uniswapV3Staker.stakeToken(tokenId);

        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) =
            uniswapV3Staker.stakes(tokenId, keccak256(abi.encode(key)));

        (uint256 totalRewardUnclaimed,, uint96 numberOfStakes) = uniswapV3Staker.incentives(keccak256(abi.encode(key)));

        assertEq(totalRewardUnclaimed, totalRewardUnclaimedBefore);
        assertEq(numberOfStakes, numberOfStakesBefore + 1);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore);
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), balanceMinterBefore);

        assertEq(secondsPerLiquidityInsideInitialX128, secondsPerLiquidityInsideX128);
        assertEq(liquidity, _liquidity);
    }

    // Test restaking a token from an incentive to another incentive
    function testRestakeToken() public {
        testCreateIncentiveAndDeposit();

        uint256 tokenId = uniswapV3Staker.userAttachements(address(this), pool);

        vm.warp(key.startTime + 0.5 weeks);

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceMinterBefore = rewardToken.balanceOf(address(baseV2Minter));

        // Create a Uniswap V3 Staker incentive
        IUniswapV3Staker.IncentiveKey memory key2 =
            IUniswapV3Staker.IncentiveKey({pool: pool, startTime: IncentiveTime.computeEnd(block.timestamp)});

        uint256 rewardAmount = 1 ether;
        rewardToken.mint(address(this), rewardAmount);
        rewardToken.approve(address(uniswapV3Staker), rewardAmount);

        createIncentive(key2, rewardAmount);

        vm.warp(key2.startTime);

        (, int24 _tickLower, int24 _tickUpper, uint128 _liquidity) =
            NFTPositionInfo.getPositionInfo(uniswapV3Factory, nonfungiblePositionManager, tokenId);

        (, uint160 secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(_tickLower, _tickUpper);

        uniswapV3Staker.restakeToken(tokenId);

        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) =
            uniswapV3Staker.stakes(tokenId, keccak256(abi.encode(key2)));

        (uint256 totalRewardUnclaimed,, uint96 numberOfStakes) = uniswapV3Staker.incentives(keccak256(abi.encode(key2)));

        assertEq(totalRewardUnclaimed, rewardAmount);
        assertEq(numberOfStakes, 1);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore + rewardAmount);
        assertEq(rewardToken.balanceOf(address(baseV2Minter)), balanceMinterBefore);

        assertEq(secondsPerLiquidityInsideInitialX128, secondsPerLiquidityInsideX128);
        assertEq(liquidity, _liquidity);
    }

    // Test withdraw a token from the staker
    function testWithdraw() public {
        uint256 tokenId = testUnstakeTokenHalfIncentive();

        uniswapV3Staker.withdrawToken(tokenId, address(this), "");

        (address owner, int24 tickLower, int24 tickUpper, uint40 stakedTimestamp) = uniswapV3Staker.deposits(tokenId);

        assertEq(owner, address(0));
        assertEq(tickLower, 0);
        assertEq(tickUpper, 0);
        assertEq(stakedTimestamp, 0);
    }

    // Test withdraw a token from the staker and revert with error: InvalidRecipient
    function testWithdrawInvalidRecipient() public {
        uint256 tokenId = testUnstakeTokenHalfIncentive();

        vm.expectRevert(IUniswapV3Staker.InvalidRecipient.selector);
        uniswapV3Staker.withdrawToken(tokenId, address(0), "");
    }

    // Test withdraw a token from the staker and revert with error: NotCalledByOwner
    function testWithdrawNotCalledByOwner() public {
        uint256 tokenId = testUnstakeTokenHalfIncentive();

        vm.expectRevert(IUniswapV3Staker.NotCalledByOwner.selector);
        vm.prank(address(1));
        uniswapV3Staker.withdrawToken(tokenId, address(this), "");
    }

    // Test claim rewards
    function testClaimRewards() public {
        testUnstakeTokenHalfIncentive();

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceThisBefore = rewardToken.balanceOf(address(this));

        uint256 earnedRewards = uniswapV3Staker.rewards(address(this));

        uniswapV3Staker.claimReward(address(this), 0);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore - earnedRewards);
        assertEq(rewardToken.balanceOf(address(this)), balanceThisBefore + earnedRewards);
    }

    // Test claim rewards with a specific amount
    function testClaimRewardsWithAmount() public {
        testUnstakeTokenHalfIncentive();

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceThisBefore = rewardToken.balanceOf(address(this));

        uint256 earnedRewards = uniswapV3Staker.rewards(address(this));

        uniswapV3Staker.claimReward(address(this), earnedRewards / 2);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore - earnedRewards / 2);
        assertEq(rewardToken.balanceOf(address(this)), balanceThisBefore + earnedRewards / 2);
        assertEq(uniswapV3Staker.rewards(address(this)), earnedRewards / 2);
    }

    // Test claim rewards with a specific amount
    function testClaimRewardsWithAmountGreater() public {
        testUnstakeTokenHalfIncentive();

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceThisBefore = rewardToken.balanceOf(address(this));

        uint256 earnedRewards = uniswapV3Staker.rewards(address(this));

        uniswapV3Staker.claimReward(address(this), earnedRewards * 2);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore - earnedRewards);
        assertEq(rewardToken.balanceOf(address(this)), balanceThisBefore + earnedRewards);
        assertEq(uniswapV3Staker.rewards(address(this)), 0);
    }

    // Test claim rewards twice
    function testClaimRewardsTwice() public {
        testClaimRewards();

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceThisBefore = rewardToken.balanceOf(address(this));

        uniswapV3Staker.claimReward(address(this), 0);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore);
        assertEq(rewardToken.balanceOf(address(this)), balanceThisBefore);
        assertEq(uniswapV3Staker.rewards(address(this)), 0);
    }

    // Test claim rewards twice
    function testClaimRewardsWithAmountGreaterTwice() public {
        testClaimRewardsWithAmountGreater();

        uint256 balanceStakerBefore = rewardToken.balanceOf(address(uniswapV3Staker));
        uint256 balanceThisBefore = rewardToken.balanceOf(address(this));

        uint256 earnedRewards = uniswapV3Staker.rewards(address(this));

        uniswapV3Staker.claimReward(address(this), earnedRewards * 2);

        assertEq(rewardToken.balanceOf(address(uniswapV3Staker)), balanceStakerBefore);
        assertEq(rewardToken.balanceOf(address(this)), balanceThisBefore);
        assertEq(uniswapV3Staker.rewards(address(this)), 0);
    }

    // Test remove gauge
    function testRemoveGauge() public {
        // Create a Uniswap V3 pool
        (pool, poolContract) =
            UniswapV3Assistant.createPool(uniswapV3Factory, address(token0), address(token1), poolFee);
        uint256 minWidth = 120;
        // Create a gauge
        gauge = createGaugeAndAddToGaugeBoost(pool, minWidth);

        assertEq(uniswapV3Staker.poolsMinimumWidth(pool), minWidth);

        uniswapV3GaugeFactory.removeGauge(gauge);

        uniswapV3Staker.updateGauges(pool);

        assertEq(uniswapV3Staker.poolsMinimumWidth(pool), type(uint24).max);
        assertEq(uniswapV3Staker.bribeDepots(pool), address(0));
    }
}
