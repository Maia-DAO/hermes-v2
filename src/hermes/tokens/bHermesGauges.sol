// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20Gauges} from "@ERC20/ERC20Gauges.sol";

import {IbHermesUnderlying} from "../interfaces/IbHermesUnderlying.sol";

/**
 * @title bHermesGauges: Directs Hermes emissions and receives fees/bribes
 * @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Represents the underlying emission direction power of a BurntHermes token.
 *          bHermesGauges is an ERC-4626 compliant BurntHermes token which:
 *          votes on bribes rewards allocation for Hermes gauges in a
 *          manipulation-resistant manner.
 *
 *          The BurntHermes owner/authority ONLY control the maximum number
 *          and approved overrides of gauges and delegates, as well as the live gauge list.
 */
contract bHermesGauges is ERC20Gauges, IbHermesUnderlying {
    /// @inheritdoc IbHermesUnderlying
    address public immutable bHermes;

    constructor(address _owner, address _flywheelBooster)
        ERC20Gauges(_flywheelBooster)
        ERC20("BurntHermes Gauges", "bHERMES-G", 18)
    {
        _initializeOwner(_owner);
        bHermes = msg.sender;
    }

    /// @inheritdoc IbHermesUnderlying
    function mint(address to, uint256 amount) external onlybHermes {
        _mint(to, amount);
    }

    modifier onlybHermes() {
        if (msg.sender != bHermes) revert NotbHermes();
        _;
    }
}
