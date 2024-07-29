// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../evault/EVaultTestBase.t.sol";
import {EVaultEmergency} from "../../../src/emergency/EVaultEmergency.sol";

contract EVaultEmergencyTest is EVaultTestBase {
    address eVaultEmergencyImpl;

    function setUp() public override virtual {
        super.setUp();
        eVaultEmergencyImpl = address(new EVaultEmergency(integrations, modules));
    }

    function test_EVaultEmergency() public {
        assetTST.mint(address(this), type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);

        // the default implementation calls are successful
        eTST.disableController();
        eTST.deposit(1e18, address(this));
        assertEq(eTST.balanceOf(address(this)), 1e18);

        // replace the implementation to eVaultEmergencyImpl
        vm.prank(admin);
        factory.setImplementation(eVaultEmergencyImpl);

        // the next calls to the default implementation revert
        vm.expectRevert();
        eTST.disableController();
        vm.expectRevert();
        eTST.deposit(1e18, address(this));

        // but the view call still works
        assertEq(eTST.balanceOf(address(this)), 1e18);

        // install the old implementation
        vm.prank(admin);
        factory.setImplementation(eVaultImpl);

        // the calls to the old implementation are successful
        eTST.disableController();
        eTST.deposit(1e18, address(this));
        assertEq(eTST.balanceOf(address(this)), 2e18);
    }
}
