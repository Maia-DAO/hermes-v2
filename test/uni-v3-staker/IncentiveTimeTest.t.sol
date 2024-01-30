// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {stdError} from "forge-std/StdError.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "@v3-staker/libraries/IncentiveTime.sol";

contract IncentiveTimeTest is DSTestPlus {
    uint256 private constant INCENTIVES_DURATION = 1 weeks; // Incentives are 1 week long and start at wednesday 00:00:00 UTC + 12 hours (INCENTIVE_OFFSET)

    uint256 private constant INCENTIVES_OFFSET = 12 hours;

    function testComputeEndStart() public {
        uint256 timestamp = 1625000000;
        uint96 end = IncentiveTime.computeEnd(timestamp);
        assertEq(end, 1624536000 + 7 days);
        uint96 startOfEnd = IncentiveTime.computeStart(end);
        assertEq(startOfEnd, end);
    }

    function testComputeStartEnd() public {
        uint256 timestamp = 1625000000;
        uint96 start = IncentiveTime.computeStart(timestamp);
        assertEq(start, 1624536000);
        uint96 endOfStart = IncentiveTime.computeEnd(start);
        assertEq(endOfStart, start + 7 days);
    }

    function testComputeStart() public {
        uint256 timestamp = 1625000000;
        uint96 start = IncentiveTime.computeStart(timestamp);
        assertEq(start, 1624536000);
    }

    function testComputeEnd() public {
        uint256 timestamp = 1625000000;
        uint96 end = IncentiveTime.computeEnd(timestamp);
        assertEq(end, 1624536000 + 7 days);
    }

    function testFuzzComputeStart(uint64 timestamp) public {
        timestamp %= (type(uint64).max - uint64(INCENTIVES_DURATION));
        timestamp += uint64(INCENTIVES_DURATION);

        uint96 start = IncentiveTime.computeStart(timestamp);
        assertEq(
            uint256(start),
            ((timestamp - INCENTIVES_OFFSET) / INCENTIVES_DURATION) * INCENTIVES_DURATION + INCENTIVES_OFFSET
        );
    }

    event log(uint256);

    function testFuzzComputeEnd() public {
        testFuzzComputeEnd(18446744073709551615);
    }

    function testFuzzComputeEnd(uint64 timestamp) public {
        timestamp %= (type(uint64).max - uint64(INCENTIVES_DURATION + 1));
        timestamp += uint64(INCENTIVES_DURATION) + 1;

        uint96 end = IncentiveTime.computeEnd(timestamp);
        assertEq(
            uint256(end),
            (((timestamp - INCENTIVES_OFFSET) / INCENTIVES_DURATION) + 1) * INCENTIVES_DURATION + INCENTIVES_OFFSET
        );
    }

    function testFuzzComputeEndUnderflow(uint256 timestamp) public {
        if (timestamp >= INCENTIVES_OFFSET) timestamp = INCENTIVES_OFFSET - 1;

        hevm.expectRevert(stdError.arithmeticError);
        IncentiveTime.computeEnd(timestamp);
    }

    function testFuzzComputeStartUnderflow(uint256 timestamp) public {
        if (timestamp >= INCENTIVES_OFFSET) timestamp = INCENTIVES_OFFSET - 1;

        hevm.expectRevert(stdError.arithmeticError);
        IncentiveTime.computeStart(timestamp);
    }
}
