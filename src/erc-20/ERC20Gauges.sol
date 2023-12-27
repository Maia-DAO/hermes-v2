// SPDX-License-Identifier: MIT
// Gauge weight logic inspired by Tribe DAO Contracts (flywheel-v2/src/token/ERC20Gauges.sol)
pragma solidity ^0.8.0;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {EnumerableSet} from "@lib/EnumerableSet.sol";

import {IFlywheelBooster} from "@rewards/interfaces/IFlywheelBooster.sol";

import {ERC20MultiVotes} from "./ERC20MultiVotes.sol";

import {Errors} from "./interfaces/Errors.sol";
import {IERC20Gauges} from "./interfaces/IERC20Gauges.sol";

/// @title  An ERC20 with an embedded "Gauge" style vote with liquid weights
abstract contract ERC20Gauges is ERC20MultiVotes, ReentrancyGuard, IERC20Gauges {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCastLib for *;

    /**
     * @notice Construct a new ERC20Gauges
     * @param _flywheelBooster the flywheel booster contract to accrue bribes
     */
    constructor(address _flywheelBooster) {
        if (_flywheelBooster == address(0)) revert InvalidBooster();
        flywheelBooster = IFlywheelBooster(_flywheelBooster);

        emit SetFlywheelBooster(_flywheelBooster);
    }

    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice 12 hours period at the end of a cycle where votes cannot increment
    uint256 private constant INCREMENT_FREEZE_WINDOW = 12 hours;

    /// @inheritdoc IERC20Gauges
    IFlywheelBooster public override flywheelBooster;

    /// @inheritdoc IERC20Gauges
    mapping(address user => mapping(address gauge => uint112 weight)) public override getUserGaugeWeight;

    /// @inheritdoc IERC20Gauges
    /// @dev NOTE this may contain weights for deprecated gauges
    mapping(address user => uint112 weight) public override getUserWeight;

    /// @notice a mapping from a gauge to the total weight allocated to it
    /// @dev NOTE this may contain weights for deprecated gauges
    mapping(address gauge => Weight gaugeWeight) internal _getGaugeWeight;

    /// @notice the total global allocated weight ONLY of live gauges
    Weight internal _totalWeight;

    mapping(address user => EnumerableSet.AddressSet userGaugeSet) internal _userGauges;

    EnumerableSet.AddressSet internal _gauges;

    // Store deprecated gauges in case a user needs to free dead weight
    EnumerableSet.AddressSet internal _deprecatedGauges;

    /*///////////////////////////////////////////////////////////////
                              VIEW HELPERS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Gauges
    function getGaugeCycleEnd() external view override returns (uint32) {
        return _getGaugeCycleEnd();
    }

    function _getGaugeCycleEnd() internal view returns (uint32) {
        uint256 nowPlusOneCycle = block.timestamp + 1 weeks;
        unchecked {
            // cannot divide by zero and always <= nowPlusOneCycle so no overflow
            return ((nowPlusOneCycle / 1 weeks) * 1 weeks).toUint32();
        }
    }

    /// @inheritdoc IERC20Gauges
    function getGaugeWeight(address gauge) external view override returns (uint112) {
        return _getGaugeWeight[gauge].currentWeight;
    }

    /// @inheritdoc IERC20Gauges
    function getStoredGaugeWeight(address gauge) external view override returns (uint112) {
        if (_deprecatedGauges.contains(gauge)) return 0;
        return _getStoredWeight(_getGaugeWeight[gauge], _getGaugeCycleEnd());
    }

    function _getStoredWeight(Weight storage gaugeWeight, uint32 currentCycle) internal view returns (uint112) {
        return gaugeWeight.currentCycle < currentCycle ? gaugeWeight.currentWeight : gaugeWeight.storedWeight;
    }

    /// @inheritdoc IERC20Gauges
    function totalWeight() external view override returns (uint112) {
        return _totalWeight.currentWeight;
    }

    /// @inheritdoc IERC20Gauges
    function storedTotalWeight() external view override returns (uint112) {
        return _getStoredWeight(_totalWeight, _getGaugeCycleEnd());
    }

    /// @inheritdoc IERC20Gauges
    function gauges() external view override returns (address[] memory) {
        return _gauges.values();
    }

    /// @inheritdoc IERC20Gauges
    function gauges(uint256 offset, uint256 num) external view override returns (address[] memory values) {
        values = new address[](num);
        for (uint256 i = 0; i < num;) {
            unchecked {
                values[i] = _gauges.at(offset + i); // will revert if out of bounds
                i++;
            }
        }
    }

    /// @inheritdoc IERC20Gauges
    function isGauge(address gauge) external view override returns (bool) {
        return _gauges.contains(gauge) && !_deprecatedGauges.contains(gauge);
    }

    /// @inheritdoc IERC20Gauges
    function numGauges() external view override returns (uint256) {
        return _gauges.length();
    }

    /// @inheritdoc IERC20Gauges
    function deprecatedGauges() external view override returns (address[] memory) {
        return _deprecatedGauges.values();
    }

    /// @inheritdoc IERC20Gauges
    function numDeprecatedGauges() external view override returns (uint256) {
        return _deprecatedGauges.length();
    }

    /// @inheritdoc IERC20Gauges
    function userGauges(address user) external view override returns (address[] memory) {
        return _userGauges[user].values();
    }

    /// @inheritdoc IERC20Gauges
    function isUserGauge(address user, address gauge) external view override returns (bool) {
        return _userGauges[user].contains(gauge);
    }

    /// @inheritdoc IERC20Gauges
    function userGauges(address user, uint256 offset, uint256 num)
        external
        view
        override
        returns (address[] memory values)
    {
        values = new address[](num);
        EnumerableSet.AddressSet storage userGaugesSet = _userGauges[user];
        for (uint256 i = 0; i < num;) {
            unchecked {
                values[i] = userGaugesSet.at(offset + i); // will revert if out of bounds
                i++;
            }
        }
    }

    /// @inheritdoc IERC20Gauges
    function numUserGauges(address user) external view override returns (uint256) {
        return _userGauges[user].length();
    }

    /// @inheritdoc ERC20MultiVotes
    function userUnusedVotes(address user) public view override returns (uint256) {
        return super.userUnusedVotes(user) - getUserWeight[user];
    }

    /// @inheritdoc IERC20Gauges
    function calculateGaugeAllocation(address gauge, uint256 quantity) external view override returns (uint256) {
        if (_deprecatedGauges.contains(gauge)) return 0;
        uint32 currentCycle = _getGaugeCycleEnd();

        // quantity * gauge weight / total weight
        return (quantity * _getStoredWeight(_getGaugeWeight[gauge], currentCycle))
            / _getStoredWeight(_totalWeight, currentCycle);
    }

    /*///////////////////////////////////////////////////////////////
                        USER GAUGE OPERATIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Gauges
    function incrementGauge(address gauge, uint112 weight) external nonReentrant returns (uint112 newUserWeight) {
        uint32 currentCycle = _getGaugeCycleEnd();
        _incrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
        return _incrementUserAndGlobalWeights(msg.sender, weight, currentCycle);
    }

    /**
     * @notice Increment the weight of a gauge for a user
     * @dev This function calls accrueBribes for the gauge to ensure the gauge handles the balance change.
     * @param user the user to increment the weight of
     * @param gauge the gauge to increment the weight of
     * @param weight the weight to increment by
     * @param cycle the cycle to increment the weight for
     */
    function _incrementGaugeWeight(address user, address gauge, uint112 weight, uint32 cycle) internal {
        if (!_gauges.contains(gauge) || _deprecatedGauges.contains(gauge)) revert InvalidGaugeError();
        unchecked {
            if (cycle - block.timestamp <= INCREMENT_FREEZE_WINDOW) revert IncrementFreezeError();
        }

        flywheelBooster.accrueBribesPositiveDelta(user, ERC20(gauge), weight);

        EnumerableSet.AddressSet storage userGaugeSet = _userGauges[user];

        // idempotent add
        if (userGaugeSet.add(gauge)) {
            if (userGaugeSet.length() > maxGauges) {
                if (!canContractExceedMaxGauges[user]) {
                    revert MaxGaugeError();
                }
            }
        }

        getUserGaugeWeight[user][gauge] += weight;

        _writeGaugeWeight(_getGaugeWeight[gauge], _add112, weight, cycle);

        emit IncrementGaugeWeight(user, gauge, weight);
    }

    /**
     * @notice Increment the weight of a gauge for a user and the total weight
     * @param user the user to increment the weight of
     * @param weight the weight to increment by
     * @param cycle the cycle to increment the weight for
     * @return newUserWeight the new user's weight
     */
    function _incrementUserAndGlobalWeights(address user, uint112 weight, uint32 cycle)
        internal
        returns (uint112 newUserWeight)
    {
        newUserWeight = getUserWeight[user] + weight;

        // new user weight must be less than or equal to the total user weight
        if (newUserWeight > getVotes(user)) revert OverWeightError();

        // Update gauge state
        getUserWeight[user] = newUserWeight;

        _writeGaugeWeight(_totalWeight, _add112, weight, cycle);
    }

    /// @inheritdoc IERC20Gauges
    function incrementGauges(address[] calldata gaugeList, uint112[] calldata weights)
        external
        nonReentrant
        returns (uint256 newUserWeight)
    {
        uint256 size = gaugeList.length;
        if (weights.length != size) revert SizeMismatchError();

        // store total in summary for a batch update on user/global state
        uint112 weightsSum;

        uint32 currentCycle = _getGaugeCycleEnd();

        // Update a gauge's specific state
        for (uint256 i = 0; i < size;) {
            address gauge = gaugeList[i];
            uint112 weight = weights[i];
            weightsSum += weight;

            _incrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
            unchecked {
                i++;
            }
        }
        return _incrementUserAndGlobalWeights(msg.sender, weightsSum, currentCycle);
    }

    /// @inheritdoc IERC20Gauges
    function decrementGauge(address gauge, uint112 weight) external nonReentrant returns (uint112 newUserWeight) {
        uint32 currentCycle = _getGaugeCycleEnd();

        // All operations will revert on underflow, protecting against bad inputs
        _decrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
        if (!_deprecatedGauges.contains(gauge)) {
            _writeGaugeWeight(_totalWeight, _subtract112, weight, currentCycle);
        }
        return _decrementUserWeights(msg.sender, weight);
    }

    /**
     * @notice Decrement the weight of a gauge for a user
     * @dev This function calls accrueBribes for the gauge to ensure the gauge handles the balance change.
     * @param user the user to decrement the weight of
     * @param gauge the gauge to decrement the weight of
     * @param weight the weight to decrement by
     * @param cycle the cycle to decrement the weight for
     */
    function _decrementGaugeWeight(address user, address gauge, uint112 weight, uint32 cycle) internal {
        if (!_gauges.contains(gauge)) revert InvalidGaugeError();

        uint112 oldWeight = getUserGaugeWeight[user][gauge];

        flywheelBooster.accrueBribesNegativeDelta(user, ERC20(gauge), weight);

        getUserGaugeWeight[user][gauge] = oldWeight - weight;
        if (oldWeight == weight) {
            // If removing all weight, remove gauge from user list.
            require(_userGauges[user].remove(gauge));
        }

        _writeGaugeWeight(_getGaugeWeight[gauge], _subtract112, weight, cycle);

        emit DecrementGaugeWeight(user, gauge, weight);
    }

    /**
     * @notice Decrement the weight of a gauge for a user and the total weight
     * @param user the user to decrement the weight of
     * @param weight the weight to decrement by
     * @return newUserWeight the new user's weight
     */
    function _decrementUserWeights(address user, uint112 weight) internal returns (uint112 newUserWeight) {
        newUserWeight = getUserWeight[user] - weight;
        getUserWeight[user] = newUserWeight;
    }

    /// @inheritdoc IERC20Gauges
    function decrementGauges(address[] calldata gaugeList, uint112[] calldata weights)
        external
        override
        nonReentrant
        returns (uint112 newUserWeight)
    {
        uint256 size = gaugeList.length;
        if (weights.length != size) revert SizeMismatchError();

        // store total in summary for the batch update on user and global state
        uint112 weightsSum;
        uint112 globalWeightsSum;

        uint32 currentCycle = _getGaugeCycleEnd();

        // Update the gauge's specific state
        // All operations will revert on underflow, protecting against bad inputs
        for (uint256 i = 0; i < size;) {
            address gauge = gaugeList[i];
            uint112 weight = weights[i];
            weightsSum += weight;
            if (!_deprecatedGauges.contains(gauge)) globalWeightsSum += weight;

            _decrementGaugeWeight(msg.sender, gauge, weight, currentCycle);
            unchecked {
                i++;
            }
        }
        _writeGaugeWeight(_totalWeight, _subtract112, globalWeightsSum, currentCycle);

        return _decrementUserWeights(msg.sender, weightsSum);
    }

    /**
     * @dev this function is the key to the entire contract.
     *  The storage weight it operates on is either a global or gauge-specific weight.
     *  The operation applied is either addition for incrementing gauges or subtraction for decrementing a gauge.
     * @param weight the weight to apply the operation to
     * @param op the operation to apply
     * @param delta the amount to apply the operation by
     * @param cycle the cycle to apply the operation for
     */
    function _writeGaugeWeight(
        Weight storage weight,
        function(uint112, uint112) view returns (uint112) op,
        uint112 delta,
        uint32 cycle
    ) private {
        uint112 currentWeight = weight.currentWeight;
        // If the last cycle of the weight is before the current cycle, use the current weight as the stored.
        uint112 stored = weight.currentCycle < cycle ? currentWeight : weight.storedWeight;
        uint112 newWeight = op(currentWeight, delta);

        weight.storedWeight = stored;
        weight.currentWeight = newWeight;
        weight.currentCycle = cycle;
    }

    function _add112(uint112 a, uint112 b) private pure returns (uint112) {
        return a + b;
    }

    function _subtract112(uint112 a, uint112 b) private pure returns (uint112) {
        return a - b;
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN GAUGE OPERATIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Gauges
    uint256 public override maxGauges;

    /// @inheritdoc IERC20Gauges
    mapping(address contractAddress => bool canExceedMaxGauges) public override canContractExceedMaxGauges;

    /// @inheritdoc IERC20Gauges
    function addGauge(address gauge) external override onlyOwner returns (uint112) {
        return _addGauge(gauge);
    }

    /**
     * @notice Add a gauge to the contract
     * @param gauge the gauge to add
     * @return weight the previous weight of the gauge, if it was already added
     */
    function _addGauge(address gauge) internal returns (uint112 weight) {
        // add and fail loud if zero address or already present and not deprecated
        if (gauge == address(0) || !(_gauges.add(gauge) || _deprecatedGauges.remove(gauge))) revert InvalidGaugeError();

        // Check if some previous weight exists and re-add to the total. Gauge and user weights are preserved.
        weight = _getGaugeWeight[gauge].currentWeight;
        if (weight > 0) {
            _writeGaugeWeight(_totalWeight, _add112, weight, _getGaugeCycleEnd());
        }

        emit AddGauge(gauge);
    }

    /// @inheritdoc IERC20Gauges
    function removeGauge(address gauge) external override onlyOwner {
        _removeGauge(gauge);
    }

    /**
     * @notice Remove a gauge from the contract
     * @param gauge the gauge to remove
     */
    function _removeGauge(address gauge) internal {
        // add to deprecated and fail loud if not present
        if (!_deprecatedGauges.add(gauge)) revert InvalidGaugeError();

        uint32 currentCycle = _getGaugeCycleEnd();

        // Remove weight from total but keep the gauge and user weights in storage in case the gauge is re-added.
        uint112 weight = _getGaugeWeight[gauge].currentWeight;
        if (weight > 0) {
            _writeGaugeWeight(_totalWeight, _subtract112, weight, currentCycle);
        }

        emit RemoveGauge(gauge);
    }

    /// @inheritdoc IERC20Gauges
    function replaceGauge(address oldGauge, address newGauge) external override onlyOwner {
        _removeGauge(oldGauge);
        _addGauge(newGauge);
    }

    /// @inheritdoc IERC20Gauges
    function setMaxGauges(uint256 newMax) external override onlyOwner {
        uint256 oldMax = maxGauges;
        maxGauges = newMax;

        emit MaxGaugesUpdate(oldMax, newMax);
    }

    /// @inheritdoc IERC20Gauges
    function setContractExceedMaxGauges(address account, bool canExceedMax) external override onlyOwner {
        if (canExceedMax) if (account.code.length == 0) revert Errors.NonContractError(); // can only approve contracts

        canContractExceedMaxGauges[account] = canExceedMax;

        emit CanContractExceedMaxGaugesUpdate(account, canExceedMax);
    }

    function setFlywheelBooster(address newFlywheelBooster) external onlyOwner {
        if (newFlywheelBooster == address(0)) revert InvalidBooster();
        flywheelBooster = IFlywheelBooster(newFlywheelBooster);

        emit SetFlywheelBooster(newFlywheelBooster);
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires userUnusedVotes < amount.
    /// _decrementWeightUntilFree is called as a greedy algorithm to free up weight.
    /// It may be more gas efficient to free weight before burning or transferring tokens.

    /**
     * @notice Burns `amount` of tokens from `from` address.
     * @dev Frees weights and votes with a greedy algorithm if needed to burn tokens
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address from, uint256 amount) internal virtual override {
        _decrementWeightUntilFree(from, amount);
        super._burn(from, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `msg.sender` to `to` address.
     * @dev Frees weights and votes with a greedy algorithm if needed to burn tokens
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _decrementWeightUntilFree(msg.sender, amount);
        return super.transfer(to, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `from` address to `to` address.
     * @dev Frees weights and votes with a greedy algorithm if needed to burn tokens
     * @param from the address to transfer from.
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _decrementWeightUntilFree(from, amount);

        if (from == msg.sender) return super.transfer(to, amount);

        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice A greedy algorithm for freeing weight before a token burn/transfer
     * @dev Frees up entire gauges, so likely will free more than `weight`
     * @param user the user to free weight for
     * @param weight the weight to free
     */
    function _decrementWeightUntilFree(address user, uint256 weight) internal nonReentrant {
        uint256 userFreeWeight = freeVotes(user) + userUnusedVotes(user);

        // early return if already free
        if (userFreeWeight >= weight) return;

        uint32 currentCycle = _getGaugeCycleEnd();

        // cache totals for batch updates
        uint112 userFreed;
        uint112 totalFreed;

        // Loop through all user gauges, live and deprecated
        address[] memory gaugeList = _userGauges[user].values();

        // Free gauges through the entire list or until underweight
        uint256 size = gaugeList.length;
        for (uint256 i = 0; i < size && (userFreeWeight + userFreed) < weight;) {
            address gauge = gaugeList[i];
            uint112 userGaugeWeight = getUserGaugeWeight[user][gauge];
            if (userGaugeWeight != 0) {
                // If the gauge is live (not deprecated), include its weight in the total to remove
                if (!_deprecatedGauges.contains(gauge)) {
                    totalFreed += userGaugeWeight;
                }
                userFreed += userGaugeWeight;
                _decrementGaugeWeight(user, gauge, userGaugeWeight, currentCycle);
            }

            unchecked {
                i++;
            }
        }

        getUserWeight[user] = getUserWeight[user] - userFreed;
        _writeGaugeWeight(_totalWeight, _subtract112, totalFreed, currentCycle);
    }
}
