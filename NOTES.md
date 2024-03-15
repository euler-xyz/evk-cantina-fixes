NORMAL TESTS

// setCapacity
1. set capacity should revert if capacity > uint128 max
2. capacity set of uint128 max should be max set to minter
// mint
3. mint should revert if amount > uint128 max
4. cast if uint128 max should not overflow
5. minterCache.minted + amount128 should not overflow ! probably will
// burn
6. amount > uint128 max should revert
7. if account != sender allowance should decrease by amount
8. amount cast should not overflow
9. 
