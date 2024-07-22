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
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        FlyWheelHelper flywheelHelper = new FlyWheelHelper();
        console2.log("FlyWheelHelper Deployed:", address(flywheelHelper));

        vm.stopBroadcast();
    }
}
