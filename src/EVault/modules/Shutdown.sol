// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";

import "../shared/types/Types.sol";

abstract contract ShutdownModule is Base, AssetTransfers, BorrowUtils, BalanceUtils {
    using TypesLib for uint256;

    function emergencyRepay(address receiver) external virtual nonReentrant {
        if (marketStorage.disabledOps.toUint32() != OP_SHUTDOWN) revert(); // TODO revert with custom error

        MarketCache memory marketCache = updateMarket();
        address account = EVCAuthenticate();

        // repay all debt
        Assets assets = getCurrentOwed(marketCache, receiver).toAssetsUp();
        if (!assets.isZero()) {
            pullAssets(marketCache, account, assets);
            decreaseBorrow(marketCache, receiver, assets);

            // at this point, the receiver should have no debt hence release control
            disableControllerInternal(receiver);
        }
    }

    function emergencyRedeem(address receiver) external virtual nonReentrant {
        if (marketStorage.disabledOps.toUint32() != OP_SHUTDOWN) revert(); // TODO revert with custom error

        MarketCache memory marketCache = updateMarket();
        address account = EVCAuthenticate();

        // ensure that the account is not controller by any vault
        if (getController(account) != address(0)) revert(); // TODO revert with custom error

        // redeem as much shares as possible
        Shares shares = marketStorage.users[account].getBalance();
        if (!shares.isZero()) {
            Assets assets = shares.toAssetsDown(marketCache);

            if (assets > marketCache.cash) {
                assets = marketCache.cash;
                shares = assets.toSharesUp(marketCache);
            }

            decreaseBalance(marketCache, account, account, receiver, shares, assets);
            pushAssets(marketCache, receiver, assets);
        }
    }
}

contract Shutdown is ShutdownModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}
