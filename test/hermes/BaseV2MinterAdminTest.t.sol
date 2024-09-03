// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {BaseV2MinterAdmin} from "@hermes/minters/BaseV2MinterAdmin.sol";
import {BaseV2Minter} from "@hermes/minters/BaseV2Minter.sol";

contract BaseV2MinterAdminTest is Test {
    // Mock minter address
    BaseV2Minter mockMinter;
    address vault = address(0xBEEF);
    address asset = address(0xDEAD);

    // Mock governor  address
    address mockGovernor = address(2);

    // Minter Admin
    BaseV2MinterAdmin minterAdmin;

    function setUp() public {
        vm.mockCall(address(vault), abi.encodeWithSignature("asset()"), abi.encode(asset));

        mockMinter = new BaseV2Minter(vault, mockGovernor, address(this));

        minterAdmin = new BaseV2MinterAdmin(mockGovernor, mockMinter, address(this));

        mockMinter.transferOwnership(address(minterAdmin));
    }

    function test_returnOwnershipToGovernance() public {
        vm.expectCall(address(mockMinter), abi.encodeWithSelector(mockMinter.transferOwnership.selector, mockGovernor));

        minterAdmin.returnOwnershipToGovernance();
    }

    function test_returnOwnershipToGovernance_notOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);

        vm.prank(mockGovernor);

        minterAdmin.returnOwnershipToGovernance();
    }

    function test_renounceOwnership() public {
        vm.expectRevert(BaseV2MinterAdmin.RenounceOwnershipNotAllowed.selector);

        minterAdmin.renounceOwnership();
    }

    function test_setOwnershipToGovernance() public {
        vm.expectCall(address(mockMinter), abi.encodeWithSelector(mockMinter.transferOwnership.selector, mockGovernor));

        vm.prank(mockGovernor);
        minterAdmin.setOwnershipToGovernance();
    }

    function test_setOwnershipToGovernance_notGovernance() public {
        vm.expectRevert(BaseV2MinterAdmin.OnlyGovernanceCanCall.selector);

        minterAdmin.setOwnershipToGovernance();
    }

    function test_setDao() public {
        address newDao = address(3);

        vm.expectCall(address(mockMinter), abi.encodeWithSelector(mockMinter.setDao.selector, newDao));

        vm.prank(mockGovernor);
        minterAdmin.setDao(newDao);
    }

    function test_setDao_notGovernance() public {
        address newDao = address(3);

        vm.expectRevert(BaseV2MinterAdmin.OnlyGovernanceCanCall.selector);

        minterAdmin.setDao(newDao);
    }

    function test_setDaoShare() public {
        uint96 newDaoShare = uint96(500);

        vm.expectCall(address(mockMinter), abi.encodeWithSelector(mockMinter.setDaoShare.selector, newDaoShare));

        vm.prank(mockGovernor);

        minterAdmin.setDaoShare(newDaoShare);
    }

    function test_setDaoShare_notGovernance() public {
        uint96 newDaoShare = uint96(500);

        vm.expectRevert(BaseV2MinterAdmin.OnlyGovernanceCanCall.selector);

        minterAdmin.setDaoShare(newDaoShare);
    }

    function test_setTailEmission() public {
        uint96 newTailEmission = uint96(100);

        test_setTailEmission(newTailEmission);
    }

    function test_setTailEmission_tooLow() public {
        uint96 newTailEmission = uint96(9);

        test_setTailEmission(newTailEmission);
    }

    function test_setTailEmission(uint96 newTailEmission) public {
        if (newTailEmission < 10) {
            vm.expectRevert(BaseV2MinterAdmin.TailEmissionTooLow.selector);
        } else {
            if (newTailEmission > 100) newTailEmission = (newTailEmission % 90) + 10;

            vm.expectCall(
                address(mockMinter), abi.encodeWithSelector(mockMinter.setTailEmission.selector, newTailEmission)
            );
        }

        minterAdmin.setTailEmission(newTailEmission);
    }

    function test_setDaoShare_notOwner() public {
        uint96 newTailEmission = uint96(100);

        vm.expectRevert(Ownable.Unauthorized.selector);

        vm.prank(mockGovernor);

        minterAdmin.setTailEmission(newTailEmission);
    }
}
