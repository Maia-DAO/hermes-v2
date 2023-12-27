// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@gauges/factories/BribesFactory.sol";

contract MockBribesFactory is BribesFactory {
    constructor(address _owner) BribesFactory(_owner) {}
}
