// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC4626} from "@ERC4626/ERC4626.sol";

import {HERMES} from "@hermes/tokens/HERMES.sol";

import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {IBaseV2Minter} from "../interfaces/IBaseV2Minter.sol";

/// @title Base V2 Minter - Mints HERMES tokens for the B(3,3) system
contract BaseV2Minter is Ownable, IBaseV2Minter {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                         MINTER STATE
    ///////////////////////////////////////////////////////////////*/

    /// @dev 0.2% per week target emission
    uint256 internal constant BASE = 10000;

    uint256 internal constant MAX_TAIL_EMISSION = 100;
    uint256 internal constant MAX_DAO_SHARE = 3000;

    /// @inheritdoc IBaseV2Minter
    address public immutable override underlying;
    /// @inheritdoc IBaseV2Minter
    ERC4626 public immutable override vault;

    /// @inheritdoc IBaseV2Minter
    FlywheelGaugeRewards public override flywheelGaugeRewards;
    /// @inheritdoc IBaseV2Minter
    address public override dao;

    /// @inheritdoc IBaseV2Minter
    uint96 public override daoShare = 1000;

    /// @inheritdoc IBaseV2Minter
    uint256 public override weekly;
    /// @inheritdoc IBaseV2Minter
    uint256 public override activePeriod;

    /// @inheritdoc IBaseV2Minter
    uint96 public override tailEmission = 20;

    address internal initializer;

    constructor(
        address _vault, // the B(3,3) system that will be locked into
        address _dao,
        address _owner
    ) {
        _initializeOwner(_owner);
        initializer = msg.sender;
        dao = _dao;
        underlying = address(ERC4626(_vault).asset());
        vault = ERC4626(_vault);
    }

    /*//////////////////////////////////////////////////////////////
                         FALLBACK LOGIC
    ///////////////////////////////////////////////////////////////*/

    fallback() external {
        updatePeriod();
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Minter
    function initialize(FlywheelGaugeRewards _flywheelGaugeRewards) external override {
        if (initializer != msg.sender) revert NotInitializer();
        flywheelGaugeRewards = _flywheelGaugeRewards;
        initializer = address(0);
        activePeriod = (block.timestamp / 1 weeks) * 1 weeks;
    }

    /// @inheritdoc IBaseV2Minter
    function setDao(address _dao) external override onlyOwner {
        /// @dev DAO can be set to address(0) to disable DAO rewards.
        dao = _dao;
        if (_dao == address(0)) daoShare = 0;

        emit ChangedDao(_dao);
    }

    /// @inheritdoc IBaseV2Minter
    function setDaoShare(uint96 _daoShare) external override onlyOwner {
        if (_daoShare > MAX_DAO_SHARE) revert DaoShareTooHigh();
        if (dao == address(0)) revert DaoRewardsAreDisabled();
        daoShare = _daoShare;

        emit ChangedDaoShare(_daoShare);
    }

    /// @inheritdoc IBaseV2Minter
    function setTailEmission(uint96 _tailEmission) external override onlyOwner {
        if (_tailEmission > MAX_TAIL_EMISSION) revert TailEmissionTooHigh();
        tailEmission = _tailEmission;

        emit ChangedTailEmission(_tailEmission);
    }

    /*//////////////////////////////////////////////////////////////
                         EMISSION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Minter
    function circulatingSupply() public view override returns (uint256) {
        return HERMES(underlying).totalSupply() - vault.totalAssets();
    }

    /// @inheritdoc IBaseV2Minter
    function weeklyEmission() external view override returns (uint256) {
        return _weeklyEmission(circulatingSupply());
    }

    /// @inheritdoc IBaseV2Minter
    function calculateGrowth(uint256 _minted) external view override returns (uint256) {
        return (vault.totalAssets() * _minted) / HERMES(underlying).totalSupply();
    }

    function _weeklyEmission(uint256 _circulatingSupply) private view returns (uint256) {
        return (_circulatingSupply * tailEmission) / BASE;
    }

    function _calculateGrowth(uint256 totalSupply, uint256 totalAssets, uint256 _minted)
        private
        pure
        returns (uint256)
    {
        return (totalAssets * _minted) / totalSupply;
    }

    /// @inheritdoc IBaseV2Minter
    function updatePeriod() public override {
        // only trigger if new week
        if (block.timestamp >= activePeriod + 1 weeks) {
            if (initializer == address(0)) {
                unchecked {
                    activePeriod = (block.timestamp / 1 weeks) * 1 weeks;
                }

                uint256 totalSupply = HERMES(underlying).totalSupply();
                uint256 totalAssets = vault.totalAssets();

                uint256 _circulatingSupply = totalSupply - totalAssets;
                uint256 newWeeklyEmission = _weeklyEmission(_circulatingSupply);
                weekly += newWeeklyEmission;

                uint256 _growth = _calculateGrowth(totalSupply, totalAssets, newWeeklyEmission);
                /// @dev share of newWeeklyEmission emissions sent to DAO.
                uint256 share = (newWeeklyEmission * daoShare) / BASE;

                uint256 _required = weekly + _growth + share;
                uint256 _balanceOf = underlying.balanceOf(address(this));

                if (_balanceOf < _required) {
                    HERMES(underlying).mint(address(this), _required - _balanceOf);
                }

                underlying.safeTransfer(address(vault), _growth);

                address _dao = dao;

                if (_dao != address(0)) underlying.safeTransfer(_dao, share);

                emit Mint(newWeeklyEmission, _circulatingSupply, _growth, share);

                /// @dev queue rewards for the cycle, anyone can call if fails
                ///      queueRewardsForCycle will call this function but won't enter
                ///      here because activePeriod was updated
                try flywheelGaugeRewards.queueRewardsForCycle() {} catch {}
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                         REWARDS STREAM LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Minter
    function getRewards() external override returns (uint256 totalQueuedForCycle) {
        if (address(flywheelGaugeRewards) != msg.sender) revert NotFlywheelGaugeRewards();
        totalQueuedForCycle = weekly;
        delete weekly;
        underlying.safeTransfer(msg.sender, totalQueuedForCycle);
    }
}
