// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IAlignmentEnforcer {
    function alignmentEnforcerHook(uint24 operation, address caller, address accountWorseOff, address accountBetterOff)
        external
        returns (bytes4);
}
