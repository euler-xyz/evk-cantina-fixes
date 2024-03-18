// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ESVaultTestBase, ESynth} from "./ESVaultTestBase.t.sol";
import {Errors} from "../../../src/Evault/shared/Errors.sol";

contract ESVaultTestDisabledOps is ESVaultTestBase {
    
        function setUp() public override {
            super.setUp();
        }
    
        function test_disabled_ops_after_init() public {
            uint32 disabledOps = eTST.disabledOps();
            assertEq(disabledOps, eTSTAsESVault.SYNTH_VAULT_DISABLED_OPS());
        }

        function test_set_unsupported_ops_enabled() public {
            uint32 newDisabledOps = 0x1; // nothing disabled
            eTST.setDisabledOps(newDisabledOps);
            uint32 disabledOps = eTST.disabledOps();

            assertEq(disabledOps, newDisabledOps | eTSTAsESVault.SYNTH_VAULT_DISABLED_OPS());
        }

}