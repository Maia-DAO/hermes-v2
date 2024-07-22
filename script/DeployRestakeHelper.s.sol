// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {RestakeHelper} from "@v3-staker/helpers/RestakeHelper.sol";

/*
forge script --broadcast \
--rpc-url <RPC-URL> \
script/deployParameters/Deploy<network>.s.sol:Deploy<network> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
 */

contract DeployRestakeHelper is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RestakeHelper restakeHelper = new RestakeHelper();
        console2.log("RestakeHelper Deployed:", address(restakeHelper));

        vm.stopBroadcast();
    }
}
