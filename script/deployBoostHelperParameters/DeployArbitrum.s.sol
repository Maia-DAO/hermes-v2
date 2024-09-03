// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DeployBoostHelper.s.sol";

contract DeployArbitrum is DeployBoostHelper {
    function setUp() public override {
        params = BoostHelperParameters({bHermesBoost: 0xeA017393Cc43a3c4da9B63A723e20a20c5951573});
    }
}
