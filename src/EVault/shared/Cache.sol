// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Errors} from "./Errors.sol";
import {Events} from "./Events.sol";
import {RPow} from "./lib/RPow.sol";
import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {ProxyUtils} from "./lib/ProxyUtils.sol";

import "./types/Types.sol";

contract Cache is Storage, Errors, Events {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    function updateMarket() internal returns (MarketCache memory marketCache) {
        (bool dirty, Shares newFees) = initMarketCache(marketCache);
        if (dirty) {
            marketStorage.lastInterestAccumulatorUpdate = marketCache.lastInterestAccumulatorUpdate;

            marketStorage.totalShares = marketCache.totalShares;
            marketStorage.totalBorrows = marketCache.totalBorrows;

            marketStorage.interestAccumulator = marketCache.interestAccumulator;

            if (!newFees.isZero()) {
                marketStorage.users[FEES_ACCOUNT].setBalance(
                    marketStorage.users[FEES_ACCOUNT].getBalance() + newFees
                );

                emit Transfer(address(0), FEES_ACCOUNT, newFees.toUint());
            }
        }
    }

    function loadMarket() internal view returns (MarketCache memory marketCache) {
        initMarketCache(marketCache);
    }

    function initMarketCache(MarketCache memory marketCache) private view returns (bool dirty, Shares newFees) {
        dirty = false;

        // Proxy metadata

        (marketCache.asset) = ProxyUtils.metadata();

        // Storage loads

        marketCache.lastInterestAccumulatorUpdate = marketStorage.lastInterestAccumulatorUpdate;
        marketCache.poolSize = marketStorage.poolSize;

        marketCache.totalShares = marketStorage.totalShares;
        marketCache.totalBorrows = marketStorage.totalBorrows;

        marketCache.interestAccumulator = marketStorage.interestAccumulator;

        // Update interest  accumulator and fees balance

        if (block.timestamp != marketCache.lastInterestAccumulatorUpdate) {
            dirty = true;

            // Compute new values. Use full precision for intermediate results.

            uint72 interestRate = interestStorage.interestRate;
            uint16 interestFee = interestStorage.interestFee;

            uint256 deltaT = block.timestamp - marketCache.lastInterestAccumulatorUpdate;
            uint256 newInterestAccumulator =
                (RPow.rpow(uint256(interestRate) + 1e27, deltaT, 1e27) * marketCache.interestAccumulator) / 1e27;

            uint256 newTotalBorrows =
                marketCache.totalBorrows.toUint() * newInterestAccumulator / marketCache.interestAccumulator;

            uint256 newTotalShares = marketCache.totalShares.toUint();

            uint256 feeAmount = (newTotalBorrows - marketCache.totalBorrows.toUint()) * interestFee
                / (INTEREST_FEE_SCALE << INTERNAL_DEBT_PRECISION);

            if (feeAmount != 0) {
                uint256 poolAssets = marketCache.poolSize.toUint() + (newTotalBorrows >> INTERNAL_DEBT_PRECISION);
                newTotalShares = poolAssets * newTotalShares / (poolAssets - feeAmount);
            }

            // Store new values in marketCache, only if no overflows will occur

            if (newTotalShares <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                marketCache.totalBorrows = newTotalBorrows.toOwed();
                marketCache.interestAccumulator = newInterestAccumulator;
                marketCache.lastInterestAccumulatorUpdate = uint40(block.timestamp);

                if (newTotalShares != Shares.unwrap(marketCache.totalShares)) {
                    Shares newTotal = newTotalShares.toShares();
                    newFees = newTotal - marketCache.totalShares;
                    marketCache.totalShares = newTotal;
                }
            }
        }
    }
}
