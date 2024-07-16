// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

/// @title IBalanceTracker
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Provides an interface for tracking the balance of accounts.
interface IBalanceTracker {
    /// @notice Executes the balance tracking hook for an account.
    /// @dev This function must be called with the current balance of the account when enabling the balance forwarding
    /// for it. This function must be called with 0 balance of the account when disabling the balance forwarding for it.
    /// This function allows to be called on zero balance transfers, when the newAccountBalance is the same as the
    /// previous one. To prevent DOS attacks, forfeitRecentReward should be used appropriately. The forwarding contract
    /// might opt-in for checkpointing balances by passing true for checkpointBalances. If checkpointBalances is true,
    /// the balance tracker contract will checkpoint both the individual accounts balances and the total balance. This
    /// might be useful for i.e. building governance systems on top of the IBalanceTracker. When checkpointing balances,
    /// the balance forwarding contract must take care for the total balances not to exceed type(uint208).max value.
    /// @param account The account address to execute the hook for.
    /// @param newAccountBalance The new balance of the account.
    /// @param checkpointBalances Whether to checkpoint the balances.
    /// @param forfeitRecentReward Whether to forfeit the most recent reward and not update the accumulator.
    function balanceTrackerHook(
        address account,
        uint256 newAccountBalance,
        bool checkpointBalances,
        bool forfeitRecentReward
    ) external;
}
