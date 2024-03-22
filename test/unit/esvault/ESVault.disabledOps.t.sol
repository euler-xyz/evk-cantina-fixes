// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ESVaultTestBase, ESynth} from "./ESVaultTestBase.t.sol";
import {Errors} from "../../../src/EVault/shared/Errors.sol";

contract ESVaultTestDisabledOps is ESVaultTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_disabled_ops_after_init() public view {
        uint24 disabledOps = eTST.disabledOps();
        assertEq(disabledOps, SYNTH_VAULT_DISABLED_OPS);
    }

    function test_set_unsupported_ops_enabled() public {
        uint24 newDisabledOps = 0x1; // nothing disabled
        eTST.setDisabledOps(newDisabledOps);
        uint24 disabledOps = eTST.disabledOps();

        assertEq(disabledOps, newDisabledOps | SYNTH_VAULT_DISABLED_OPS);
    }
}
