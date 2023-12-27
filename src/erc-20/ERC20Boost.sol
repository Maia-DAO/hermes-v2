// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {EnumerableSet} from "@lib/EnumerableSet.sol";

import {IERC20Boost} from "./interfaces/IERC20Boost.sol";

/// @title An ERC20 with an embedded attachment mechanism to keep track of boost
///        allocations to gauges.
abstract contract ERC20Boost is ERC20, Ownable, IERC20Boost {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCastLib for *;

    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    mapping(address user => mapping(address gauge => GaugeState userGaugeState)) public override getUserGaugeBoost;

    /// @inheritdoc IERC20Boost
    mapping(address user => uint256 boost) public override getUserBoost;

    mapping(address user => EnumerableSet.AddressSet userGaugeSet) internal _userGauges;

    EnumerableSet.AddressSet internal _gauges;

    // Store deprecated gauges in case a user needs to free dead boost
    EnumerableSet.AddressSet internal _deprecatedGauges;

    /*///////////////////////////////////////////////////////////////
                            VIEW HELPERS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function gauges() external view override returns (address[] memory) {
        return _gauges.values();
    }

    /// @inheritdoc IERC20Boost
    function gauges(uint256 offset, uint256 num) external view override returns (address[] memory values) {
        values = new address[](num);
        for (uint256 i = 0; i < num;) {
            unchecked {
                values[i] = _gauges.at(offset + i); // will revert if out of bounds
                i++;
            }
        }
    }

    /// @inheritdoc IERC20Boost
    function isGauge(address gauge) external view override returns (bool) {
        return _gauges.contains(gauge) && !_deprecatedGauges.contains(gauge);
    }

    /// @inheritdoc IERC20Boost
    function numGauges() external view override returns (uint256) {
        return _gauges.length();
    }

    /// @inheritdoc IERC20Boost
    function deprecatedGauges() external view override returns (address[] memory) {
        return _deprecatedGauges.values();
    }

    /// @inheritdoc IERC20Boost
    function numDeprecatedGauges() external view override returns (uint256) {
        return _deprecatedGauges.length();
    }

    /// @inheritdoc IERC20Boost
    function freeGaugeBoost(address user) public view override returns (uint256) {
        return balanceOf[user] - getUserBoost[user];
    }

    /// @inheritdoc IERC20Boost
    function userGauges(address user) external view override returns (address[] memory) {
        return _userGauges[user].values();
    }

    /// @inheritdoc IERC20Boost
    function isUserGauge(address user, address gauge) external view override returns (bool) {
        return _userGauges[user].contains(gauge);
    }

    /// @inheritdoc IERC20Boost
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

    /// @inheritdoc IERC20Boost
    function numUserGauges(address user) external view override returns (uint256) {
        return _userGauges[user].length();
    }

    /*///////////////////////////////////////////////////////////////
                        GAUGE OPERATIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function attach(address user) external override {
        if (!_gauges.contains(msg.sender) || _deprecatedGauges.contains(msg.sender)) {
            revert InvalidGauge();
        }

        // idempotent add
        if (!_userGauges[user].add(msg.sender)) revert GaugeAlreadyAttached();

        uint128 userGaugeBoost = balanceOf[user].toUint128();

        if (getUserBoost[user] < userGaugeBoost) {
            getUserBoost[user] = userGaugeBoost;
            emit UpdateUserBoost(user, userGaugeBoost);
        }

        uint256 _totalSupply = totalSupply;
        if (_totalSupply > 0) {
            GaugeState storage userBoost = getUserGaugeBoost[user][msg.sender];
            userBoost.userGaugeBoost = userGaugeBoost;
            userBoost.totalGaugeBoost = _totalSupply.toUint128();
        }

        emit Attach(user, msg.sender, userGaugeBoost);
    }

    /// @inheritdoc IERC20Boost
    function detach(address user) external {
        require(_userGauges[user].remove(msg.sender)); // Remove from set. Should never fail.
        delete getUserGaugeBoost[user][msg.sender];

        emit Detach(user, msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        USER GAUGE OPERATIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function updateUserBoost(address user) external override {
        uint256 userBoost;

        address[] memory gaugeList = _userGauges[user].values();

        uint256 length = gaugeList.length;
        for (uint256 i = 0; i < length;) {
            uint256 gaugeBoost = getUserGaugeBoost[user][gaugeList[i]].userGaugeBoost;

            if (userBoost < gaugeBoost) userBoost = gaugeBoost;

            unchecked {
                i++;
            }
        }
        getUserBoost[user] = userBoost;

        emit UpdateUserBoost(user, userBoost);
    }

    /// @inheritdoc IERC20Boost
    function decrementGaugeBoost(address gauge, uint256 boost) public override {
        GaugeState storage gaugeState = getUserGaugeBoost[msg.sender][gauge];
        uint256 _userGaugeBoost = gaugeState.userGaugeBoost;

        if (_deprecatedGauges.contains(gauge) || boost >= _userGaugeBoost) {
            require(_userGauges[msg.sender].remove(gauge)); // Remove from set. Should never fail.
            delete getUserGaugeBoost[msg.sender][gauge];

            emit Detach(msg.sender, gauge);
        } else {
            _userGaugeBoost = _userGaugeBoost - boost;
            gaugeState.userGaugeBoost = _userGaugeBoost.toUint128();

            emit DecrementUserGaugeBoost(msg.sender, gauge, _userGaugeBoost);
        }
    }

    /// @inheritdoc IERC20Boost
    function decrementGaugeAllBoost(address gauge) external override {
        require(_userGauges[msg.sender].remove(gauge)); // Remove from set. Should never fail.
        delete getUserGaugeBoost[msg.sender][gauge];

        emit Detach(msg.sender, gauge);
    }

    /// @inheritdoc IERC20Boost
    function decrementAllGaugesBoost(uint256 boost) external override {
        decrementGaugesBoostIndexed(boost, 0, _userGauges[msg.sender].length());
    }

    /// @inheritdoc IERC20Boost
    function decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num) public override {
        EnumerableSet.AddressSet storage userGaugesSet = _userGauges[msg.sender];

        address[] memory gaugeList = userGaugesSet.values();

        uint256 length = gaugeList.length;
        for (uint256 i = 0; i < num && i < length;) {
            address gauge = gaugeList[offset + i];

            GaugeState storage gaugeState = getUserGaugeBoost[msg.sender][gauge];
            uint256 _userGaugeBoost = gaugeState.userGaugeBoost;

            if (_deprecatedGauges.contains(gauge) || boost >= _userGaugeBoost) {
                require(userGaugesSet.remove(gauge)); // Remove from set. Should never fail.
                delete getUserGaugeBoost[msg.sender][gauge];

                emit Detach(msg.sender, gauge);
            } else {
                _userGaugeBoost = _userGaugeBoost - boost;
                gaugeState.userGaugeBoost = _userGaugeBoost.toUint128();

                emit DecrementUserGaugeBoost(msg.sender, gauge, _userGaugeBoost);
            }

            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IERC20Boost
    function decrementAllGaugesAllBoost() external override {
        EnumerableSet.AddressSet storage userGaugesSet = _userGauges[msg.sender];

        // Loop through all user gauges, live and deprecated
        address[] memory gaugeList = userGaugesSet.values();

        // Free gauges until through the entire list
        uint256 size = gaugeList.length;
        for (uint256 i = 0; i < size;) {
            address gauge = gaugeList[i];

            require(userGaugesSet.remove(gauge)); // Remove from set. Should never fail.
            delete getUserGaugeBoost[msg.sender][gauge];

            emit Detach(msg.sender, gauge);

            unchecked {
                i++;
            }
        }

        delete getUserBoost[msg.sender];

        emit UpdateUserBoost(msg.sender, 0);
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN GAUGE OPERATIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function addGauge(address gauge) external override onlyOwner {
        _addGauge(gauge);
    }

    function _addGauge(address gauge) internal {
        // add and fail loud if zero address or already present and not deprecated
        if (gauge == address(0) || !(_gauges.add(gauge) || _deprecatedGauges.remove(gauge))) revert InvalidGauge();

        emit AddGauge(gauge);
    }

    /// @inheritdoc IERC20Boost
    function removeGauge(address gauge) external override onlyOwner {
        _removeGauge(gauge);
    }

    function _removeGauge(address gauge) internal {
        // add to deprecated and fail loud if not present
        if (!_deprecatedGauges.add(gauge)) revert InvalidGauge();

        emit RemoveGauge(gauge);
    }

    /// @inheritdoc IERC20Boost
    function replaceGauge(address oldGauge, address newGauge) external override onlyOwner {
        _removeGauge(oldGauge);
        _addGauge(newGauge);
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires notAttached < amount.

    /**
     * @notice Burns `amount` of tokens from `from` address.
     * @dev User must have enough free boost.
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address from, uint256 amount) internal override notAttached(from, amount) {
        super._burn(from, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `msg.sender` to `to` address.
     * @dev User must have enough free boost.
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transfer(address to, uint256 amount) public override notAttached(msg.sender, amount) returns (bool) {
        return super.transfer(to, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `from` address to `to` address.
     * @dev User must have enough free boost.
     * @param from the address to transfer from.
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        notAttached(from, amount)
        returns (bool)
    {
        if (from == msg.sender) return super.transfer(to, amount);

        return super.transferFrom(from, to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                             MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Reverts if the user does not have enough free boost.
     * @param user The user address.
     * @param amount The amount of boost.
     */
    modifier notAttached(address user, uint256 amount) {
        if (freeGaugeBoost(user) < amount) revert AttachedBoost();
        _;
    }
}
