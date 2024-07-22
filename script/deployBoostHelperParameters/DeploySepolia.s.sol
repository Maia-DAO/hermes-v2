// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DeployBoostHelper.s.sol";

contract DeploySepolia is DeployBoostHelper {
    function setUp() public override {
        params = BoostHelperParameters({bHermesBoost: 0x8265Aa10EE11f57ed01Bf8ecE5BA57Ef75ED36dc});
    }
}
