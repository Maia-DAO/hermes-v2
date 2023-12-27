// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20MultiVotes} from "@ERC20/ERC20MultiVotes.sol";

import {IbHermesUnderlying} from "../interfaces/IbHermesUnderlying.sol";

/**
 * @title bHermesVotes: Have power over Hermes' governance
 * @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Represents the underlying governance power of a BurntHermes token.
 */
contract bHermesVotes is ERC20MultiVotes, IbHermesUnderlying {
    /// @inheritdoc IbHermesUnderlying
    address public immutable override bHermes;

    constructor(address _owner) ERC20("BurntHermes Votes", "bHERMES-V", 18) {
        _initializeOwner(_owner);
        bHermes = msg.sender;
    }

    /// @inheritdoc IbHermesUnderlying
    function mint(address to, uint256 amount) external override onlybHermes {
        _mint(to, amount);
    }

    /**
     * @notice Burns Burnt Hermes gauge tokens
     * @param from account to burn tokens from
     * @param amount amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlybHermes {
        _burn(from, amount);
    }

    modifier onlybHermes() {
        if (msg.sender != bHermes) revert NotbHermes();
        _;
    }
}
