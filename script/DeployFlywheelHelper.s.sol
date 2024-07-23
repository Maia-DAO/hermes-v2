// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {FlyWheelHelper} from "@rewards/helpers/FlyWheelHelper.sol";

/*
forge script --broadcast \
--rpc-url <RPC-URL> \
script/deployParameters/Deploy<network>.s.sol:Deploy<network> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
 */

contract DeployFlywheelHelper is Script {
    function run() external {
        vm.startBroadcast();

        FlyWheelHelper flywheelHelper = new FlyWheelHelper();
        console2.log("FlyWheelHelper Deployed:", address(flywheelHelper));

        vm.stopBroadcast();
    }
}
