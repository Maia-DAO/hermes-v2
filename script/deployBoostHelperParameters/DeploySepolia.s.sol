// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DeployBoostHelper.s.sol";

contract DeploySepolia is DeployBoostHelper {
    function setUp() public override {
        params = BoostHelperParameters({bHermesBoost: 0xE2eaCd92208E81c88E629682aeab5646E4f8ed69});
    }
}
