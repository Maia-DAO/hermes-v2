// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20Boost} from "@ERC20/ERC20Boost.sol";

import {IbHermesUnderlying} from "../interfaces/IbHermesUnderlying.sol";

/// @title Library for bHermesBoost deployment
library DeployBurntHermesBoost {
    function deploy(address _owner) external returns (bHermesBoost) {
        return new bHermesBoost(_owner);
    }
}

/**
 * @title bHermesBoost: Earns rights to boosted Hermes yield
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice An ERC20 with an embedded attachment mechanism to
 *          keep track of boost allocations to gauges.
 */
contract bHermesBoost is ERC20Boost, IbHermesUnderlying {
    /// @inheritdoc IbHermesUnderlying
    address public immutable override bHermes;

    constructor(address _owner) ERC20("BurntHermes Boost", "bHERMES-B", 18) {
        _initializeOwner(_owner);
        bHermes = msg.sender;
    }

    /// @inheritdoc IbHermesUnderlying
    function mint(address to, uint256 amount) external override onlybHermes {
        _mint(to, amount);
    }

    modifier onlybHermes() {
        if (msg.sender != bHermes) revert NotbHermes();
        _;
    }
}
