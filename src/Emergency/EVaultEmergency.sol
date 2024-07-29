// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "../EVault/EVault.sol";

/// @title EVaultEmergency
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This contract is an emergency implementation of the EVault contract that should be set in the factory in case of an emergency.
contract EVaultEmergency is EVault {
    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    function delegateToModule(address) internal pure override {
        revert E_NotSupported();
    }

    function callThroughEVCInternal() internal pure override {
        revert E_NotSupported();
    }
}
