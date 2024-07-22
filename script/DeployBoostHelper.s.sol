// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {IERC20Boost, ERC20BoostHelper} from "../src/erc-20/helpers/ERC20BoostHelper.sol";

struct BoostHelperParameters {
    address bHermesBoost;
}

/*
forge script --broadcast \
--rpc-url <RPC-URL> \
script/deployParameters/Deploy<network>.s.sol:Deploy<network> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
 */

abstract contract DeployBoostHelper is Script {
    BoostHelperParameters internal params;

    // set values for params and unsupported
    function setUp() public virtual;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        logParams();

        IERC20Boost bHermesBoost = IERC20Boost(params.bHermesBoost);
        console2.log("bHermesBoost:", address(bHermesBoost));

        ERC20BoostHelper boostHelper = new ERC20BoostHelper(bHermesBoost);
        console2.log("ERC20BoostHelper Deployed:", address(boostHelper));

        vm.stopBroadcast();
    }

    function logParams() internal view {
        console2.log("bHermesBoost:", address(params.bHermesBoost));
    }
}
