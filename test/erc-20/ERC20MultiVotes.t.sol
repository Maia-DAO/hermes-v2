// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";

import {MockERC20MultiVotes, IERC20MultiVotes, ERC20MultiVotes} from "./mocks/MockERC20MultiVotes.t.sol";

contract ERC20MultiVotesTest is Test {
    MockERC20MultiVotes token;
    address constant delegate1 = address(0xDEAD);
    address constant delegate2 = address(0xBEEF);

    function setUp() public {
        token = new MockERC20MultiVotes(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        TEST ADMIN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testSetMaxDelegates(uint256 max) public {
        token.setMaxDelegates(max);
        require(token.maxDelegates() == max);
    }

    function testSetMaxDelegatesNonOwnerFails() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.setMaxDelegates(7);
    }

    function testCanContractExceedMax() public {
        token.setContractExceedMaxDelegates(address(this), true);
        require(token.canContractExceedMaxDelegates(address(this)));
    }

    function testCanContractExceedMaxNonOwnerFails() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.setContractExceedMaxDelegates(address(this), true);
    }

    function testCanContractExceedMaxNonContractFails() public {
        vm.expectRevert(abi.encodeWithSignature("NonContractError()"));
        token.setContractExceedMaxDelegates(address(1), true);
    }

    /*///////////////////////////////////////////////////////////////
                        TEST USER DELEGATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice test delegating different delegatees 8 times by multiple users and amounts
    function testDelegate(address[8] memory from, address[8] memory delegates, uint224[8] memory amounts) public {
        token.setMaxDelegates(8);

        uint224 sum;
        for (uint256 i = 0; i < 8; i++) {
            if (from[i] == address(0)) from[i] = address(0xCAFE);
            if (delegates[i] == address(0)) delegates[i] = address(0xCAFE);

            if (sum == type(uint224).max) break;

            amounts[i] %= type(uint224).max - sum;
            amounts[i]++;

            sum += amounts[i];

            token.mint(from[i], amounts[i]);

            uint256 userDelegatedBefore = token.userDelegatedVotes(from[i]);
            uint256 delegateVotesBefore = token.delegatesVotesCount(from[i], delegates[i]);
            uint256 votesBefore = token.getVotes(delegates[i]);

            vm.prank(from[i]);
            token.incrementDelegation(delegates[i], amounts[i]);
            require(token.delegatesVotesCount(from[i], delegates[i]) == delegateVotesBefore + amounts[i]);
            require(token.userDelegatedVotes(from[i]) == userDelegatedBefore + amounts[i]);
            require(token.getVotes(delegates[i]) == votesBefore + amounts[i]);
        }
    }

    function testDelegateToAddressZeroFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        vm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        token.incrementDelegation(address(0), 50e18);
    }

    function testDelegateOverVotesFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 50e18);
        vm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        token.incrementDelegation(delegate2, 51e18);
    }

    function testDelegateOverMaxDelegatesFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 50e18);
        token.incrementDelegation(delegate2, 1e18);
        vm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        token.incrementDelegation(address(this), 1e18);
    }

    function testDelegateOverMaxDelegatesApproved() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.setContractExceedMaxDelegates(address(this), true);
        token.incrementDelegation(delegate1, 50e18);
        token.incrementDelegation(delegate2, 1e18);
        token.incrementDelegation(address(this), 1e18);

        require(token.delegateCount(address(this)) == 3);
        require(token.delegateCount(address(this)) > token.maxDelegates());
        require(token.userDelegatedVotes(address(this)) == 52e18);

        address[] memory delegates = token.delegates(address(this));

        require(delegates.length == 3);
        require(delegates[0] == delegate1);
        require(delegates[1] == delegate2);
        require(delegates[2] == address(this));
    }

    /// @notice test undelegate twice, 2 tokens each after delegating by 4.
    function testUndelegate() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 4e18);

        token.undelegate(delegate1, 2e18);
        require(token.delegatesVotesCount(address(this), delegate1) == 2e18);
        require(token.userDelegatedVotes(address(this)) == 2e18);
        require(token.getVotes(delegate1) == 2e18);
        require(token.freeVotes(address(this)) == 98e18);

        token.undelegate(delegate1, 2e18);
        require(token.delegatesVotesCount(address(this), delegate1) == 0);
        require(token.userDelegatedVotes(address(this)) == 0);
        require(token.getVotes(delegate1) == 0);
        require(token.freeVotes(address(this)) == 100e18);
    }

    function testDecrementOverWeightFails() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 50e18);
        vm.expectRevert(IERC20MultiVotes.UndelegationVoteError.selector);
        token.undelegate(delegate1, 51e18);
    }

    function testBackwardCompatibleDelegate(
        address oldDelegatee,
        uint112 beforeDelegateAmount,
        address newDelegatee,
        uint112 mintAmount
    ) public {
        mintAmount %= type(uint112).max;
        mintAmount++;

        beforeDelegateAmount %= mintAmount;
        beforeDelegateAmount++;

        token.mint(address(this), mintAmount);
        token.setMaxDelegates(2);

        if (oldDelegatee == address(0)) {
            vm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        }

        token.incrementDelegation(oldDelegatee, beforeDelegateAmount);

        token.delegate(newDelegatee);

        uint256 expected = newDelegatee == address(0) ? 0 : mintAmount;
        uint256 expectedFree = newDelegatee == address(0) ? mintAmount : 0;

        require(oldDelegatee == newDelegatee || token.delegatesVotesCount(address(this), oldDelegatee) == 0);
        require(token.delegatesVotesCount(address(this), newDelegatee) == expected);
        require(token.userDelegatedVotes(address(this)) == expected);
        require(token.getVotes(newDelegatee) == expected);
        require(token.freeVotes(address(this)) == expectedFree);
    }

    function testBackwardCompatibleDelegateBySig(
        uint128 delegatorPk,
        address oldDelegatee,
        uint112 beforeDelegateAmount,
        address newDelegatee,
        uint112 mintAmount
    ) public {
        if (delegatorPk == 0) delegatorPk++;
        address owner = vm.addr(delegatorPk);

        mintAmount %= type(uint112).max;
        mintAmount++;

        beforeDelegateAmount %= mintAmount;
        beforeDelegateAmount++;

        token.mint(owner, mintAmount);
        token.setMaxDelegates(2);

        if (oldDelegatee == address(0)) {
            vm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        }

        vm.prank(owner);
        token.incrementDelegation(oldDelegatee, beforeDelegateAmount);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            delegatorPk,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(token.DELEGATION_TYPEHASH(), newDelegatee, 0, block.timestamp))
                )
            )
        );

        uint256 expected = newDelegatee == address(0) ? 0 : mintAmount;
        uint256 expectedFree = newDelegatee == address(0) ? mintAmount : 0;

        token.delegateBySig(newDelegatee, 0, block.timestamp, v, r, s);
        require(oldDelegatee == newDelegatee || token.delegatesVotesCount(owner, oldDelegatee) == 0);
        require(token.delegatesVotesCount(owner, newDelegatee) == expected);
        require(token.userDelegatedVotes(owner) == expected);
        require(token.getVotes(newDelegatee) == expected);
        require(token.freeVotes(owner) == expectedFree);
    }

    struct DelegateAmountTestParams {
        uint128 delegatorPk;
        address oldDelegatee;
        uint112 beforeDelegateAmount;
        address newDelegatee;
        uint112 mintAmount;
        uint112 delegateAmountToIncrease;
    }

    function testBackwardCompatibleDelegateAmountBySig(DelegateAmountTestParams memory params) public {
        if (params.delegatorPk == 0) params.delegatorPk++;
        address owner = vm.addr(params.delegatorPk);

        params.mintAmount %= type(uint112).max;
        params.mintAmount++;

        params.beforeDelegateAmount %= params.mintAmount;
        params.beforeDelegateAmount++;

        token.mint(owner, params.mintAmount);
        token.setMaxDelegates(2);

        bool oldDelegateIsZeroAddress = params.oldDelegatee == address(0);
        uint256 expectedBefore = params.beforeDelegateAmount;

        if (oldDelegateIsZeroAddress) {
            expectedBefore = 0;
            vm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        }

        vm.prank(owner);
        token.incrementDelegation(params.oldDelegatee, params.beforeDelegateAmount);

        if (params.mintAmount == params.beforeDelegateAmount) params.delegateAmountToIncrease = 0;
        else params.delegateAmountToIncrease %= (params.mintAmount - params.beforeDelegateAmount);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            params.delegatorPk,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            token.DELEGATION_AMOUNT_TYPEHASH(),
                            params.newDelegatee,
                            params.delegateAmountToIncrease,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        bool newDelegateIsZeroAddress = params.newDelegatee == address(0);
        bool amountToIncreaseIsZero = params.delegateAmountToIncrease == 0;

        uint256 expected = params.delegateAmountToIncrease;

        if (newDelegateIsZeroAddress || amountToIncreaseIsZero) {
            expected = 0;
            vm.expectRevert(abi.encodeWithSignature("DelegationError()"));
        }

        uint256 expectedUsed = expected + expectedBefore;
        uint256 expectedFree = params.mintAmount - expectedUsed;

        token.delegateAmountBySig(params.newDelegatee, params.delegateAmountToIncrease, 0, block.timestamp, v, r, s);
        if (params.oldDelegatee == params.newDelegatee) {
            assertEq(token.delegatesVotesCount(owner, params.newDelegatee), expectedUsed);
            assertEq(token.getVotes(params.newDelegatee), expectedUsed);
        } else {
            assertEq(token.delegatesVotesCount(owner, params.oldDelegatee), expectedBefore);
            assertEq(token.delegatesVotesCount(owner, params.newDelegatee), expected);
            assertEq(token.getVotes(params.newDelegatee), expected);
        }
        assertEq(token.userDelegatedVotes(owner), expectedUsed);

        assertEq(token.freeVotes(owner), expectedFree);
    }

    /*///////////////////////////////////////////////////////////////
                            TEST PAST VOTES
    //////////////////////////////////////////////////////////////*/

    function testPastVotes() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 4e18);

        uint256 block1 = vm.getBlockNumber();
        assertEq(token.numCheckpoints(delegate1), 1);
        ERC20MultiVotes.Checkpoint memory checkpoint1 = token.checkpoints(delegate1, 0);
        assertEq(checkpoint1.fromBlock, block1);
        assertEq(checkpoint1.votes, 4e18);

        // Same block increase voting power
        token.incrementDelegation(delegate1, 4e18);

        assertEq(token.numCheckpoints(delegate1), 1);
        checkpoint1 = token.checkpoints(delegate1, 0);
        assertEq(checkpoint1.fromBlock, block1);
        assertEq(checkpoint1.votes, 8e18);

        vm.roll(2);
        uint256 block2 = vm.getBlockNumber();
        assertEq(block2, block1 + 1);

        // Next block decrease voting power
        token.undelegate(delegate1, 2e18);

        assertEq(token.numCheckpoints(delegate1), 2); // new checkpint

        // checkpoint 1 stays same
        checkpoint1 = token.checkpoints(delegate1, 0);
        assertEq(checkpoint1.fromBlock, block1);
        assertEq(checkpoint1.votes, 8e18);

        // new checkpoint 2
        ERC20MultiVotes.Checkpoint memory checkpoint2 = token.checkpoints(delegate1, 1);
        assertEq(checkpoint2.fromBlock, block2);
        assertEq(checkpoint2.votes, 6e18);

        vm.roll(10);
        uint256 block3 = vm.getBlockNumber();
        assertEq(block3, block2 + 8);

        // 10 blocks later increase voting power
        token.incrementDelegation(delegate1, 4e18);

        assertEq(token.numCheckpoints(delegate1), 3); // new checkpint

        // checkpoint 1 stays same
        checkpoint1 = token.checkpoints(delegate1, 0);
        assertEq(checkpoint1.fromBlock, block1);
        assertEq(checkpoint1.votes, 8e18);

        // checkpoint 2 stays same
        checkpoint2 = token.checkpoints(delegate1, 1);
        assertEq(checkpoint2.fromBlock, block2);
        assertEq(checkpoint2.votes, 6e18);

        // new checkpoint 3
        ERC20MultiVotes.Checkpoint memory checkpoint3 = token.checkpoints(delegate1, 2);
        assertEq(checkpoint3.fromBlock, block3);
        assertEq(checkpoint3.votes, 10e18);

        // finally, test getPriorVotes between checkpoints
        assertEq(token.getPriorVotes(delegate1, block1), 8e18);
        assertEq(token.getPriorVotes(delegate1, block2), 6e18);
        assertEq(token.getPriorVotes(delegate1, block2 + 4), 6e18);
        assertEq(token.getPriorVotes(delegate1, block3 - 1), 6e18);

        vm.expectRevert(abi.encodeWithSignature("BlockError()"));
        token.getPriorVotes(delegate1, block3); // revert same block

        vm.roll(11);
        assertEq(token.getPriorVotes(delegate1, block3), 10e18);
    }

    /*///////////////////////////////////////////////////////////////
                            TEST ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDecrementUntilFreeWhenFree() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 10e18);
        token.incrementDelegation(delegate2, 20e18);
        require(token.freeVotes(address(this)) == 70e18);

        token.burn(address(this), 50e18);
        require(token.freeVotes(address(this)) == 20e18);

        require(token.delegatesVotesCount(address(this), delegate1) == 10e18);
        require(token.userDelegatedVotes(address(this)) == 30e18);
        require(token.getVotes(delegate1) == 10e18);
        require(token.delegatesVotesCount(address(this), delegate2) == 20e18);
        require(token.getVotes(delegate2) == 20e18);
    }

    function testDecrementUntilFreeSingle() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 10e18);
        token.incrementDelegation(delegate2, 20e18);
        require(token.freeVotes(address(this)) == 70e18);

        token.transfer(address(1), 80e18);
        require(token.freeVotes(address(this)) == 0);

        require(token.delegatesVotesCount(address(this), delegate1) == 0);
        require(token.userDelegatedVotes(address(this)) == 20e18);
        require(token.getVotes(delegate1) == 0);
        require(token.delegatesVotesCount(address(this), delegate2) == 20e18);
        require(token.getVotes(delegate2) == 20e18);
    }

    function testDecrementUntilFreeDouble() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);

        token.incrementDelegation(delegate1, 10e18);
        token.incrementDelegation(delegate2, 20e18);
        require(token.freeVotes(address(this)) == 70e18);

        token.approve(address(1), 100e18);
        vm.prank(address(1));
        token.transferFrom(address(this), address(1), 90e18);

        require(token.freeVotes(address(this)) == 10e18);

        require(token.delegatesVotesCount(address(this), delegate1) == 0);
        require(token.userDelegatedVotes(address(this)) == 0);
        require(token.getVotes(delegate1) == 0);
        require(token.delegatesVotesCount(address(this), delegate2) == 0);
        require(token.getVotes(delegate2) == 0);
    }
}
