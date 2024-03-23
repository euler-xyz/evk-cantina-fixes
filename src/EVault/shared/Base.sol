// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCClient} from "./EVCClient.sol";
import {Cache} from "./Cache.sol";
import {RevertBytes} from "./lib/RevertBytes.sol";

import {IProtocolConfig} from "../../ProtocolConfig/IProtocolConfig.sol";
import {IBalanceTracker} from "../../interfaces/IBalanceTracker.sol";

import "./types/Types.sol";

abstract contract Base is EVCClient, Cache {
    IProtocolConfig immutable protocolConfig;
    IBalanceTracker immutable balanceTracker;
    address immutable permit2;

    struct Integrations {
        address evc;
        address protocolConfig;
        address balanceTracker;
        address permit2;
    }

    constructor(Integrations memory integrations) EVCClient(integrations.evc) {
        protocolConfig = IProtocolConfig(integrations.protocolConfig);
        balanceTracker = IBalanceTracker(integrations.balanceTracker);
        permit2 = integrations.permit2;
    }

    modifier reentrantOK() {
        _;
    } // documentation only

    modifier nonReentrant() {
        if (marketStorage.reentrancyLocked) revert E_Reentrancy();

        marketStorage.reentrancyLocked = true;
        _;
        marketStorage.reentrancyLocked = false;
    }

    modifier nonReentrantView() {
        if (marketStorage.reentrancyLocked) revert E_Reentrancy();
        _;
    }

    // Generate a market snapshot and store it.
    // Queue vault and maybe account checks in the EVC (caller, current, onBehalfOf or none).
    // If needed, revert if this contract is not the controller of the authenticated account.
    // Returns the MarketCache and active account.
    function initOperation(uint24 operation, address accountToCheck)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        marketCache = updateMarket();

        account = EVCAuthenticateDeferred(~CONTROLLER_REQUIRED_OPS & operation == 0);

        validateOperation(marketCache, operation, account);

        // The snapshot is used only to verify that supply increased when checking the supply cap, and to verify that the borrows
        // increased when checking the borrowing cap. Caps are not checked when the capped variables decrease (become safer).
        // For this reason, the snapshot is disabled if both caps are disabled.
        if (
            !marketCache.snapshotInitialized
                && (marketCache.supplyCap < type(uint256).max || marketCache.borrowCap < type(uint256).max)
        ) {
            marketStorage.snapshotInitialized = marketCache.snapshotInitialized = true;
            snapshot.set(marketCache.cash, marketCache.totalBorrows.toAssetsUp());
        }

        EVCRequireStatusChecks(accountToCheck == CHECKACCOUNT_CALLER ? account : accountToCheck);
    }

    // Checks whether the operation is disabled or requires alignment enforcement.
    // Reverts if the operation is disabled or alignment enforcement fails.
    function validateOperation(
        MarketCache memory marketCache,
        uint24 operation,
        address account
    ) internal {
        if (marketCache.disabledOps.isSet(operation)) {
            revert E_OperationDisabled();
        }

        if (marketCache.alignedOps.isNotSet(operation)) return;

        address alignmentEnforcer = marketStorage.alignmentEnforcer;

        if (alignmentEnforcer != address(0)) {
            // It's up to the governance to ensure there is code under the address
            (bool success, bytes memory data) = alignmentEnforcer.call(abi.encodePacked(msg.data, account));

            if (!success) {
                RevertBytes.revertBytes(data);
            } 
        }
    }

    function logMarketStatus(MarketCache memory a, uint256 interestRate) internal {
        emit MarketStatus(
            a.totalShares.toUint(),
            a.totalBorrows.toAssetsUp().toUint(),
            a.accumulatedFees.toUint(),
            a.cash.toUint(),
            a.interestAccumulator,
            interestRate,
            block.timestamp
        );
    }
}