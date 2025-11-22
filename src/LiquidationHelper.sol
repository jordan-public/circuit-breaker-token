// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Helper {
    // slot 5 used for `firstLiquidationAttemptDone` in Wrapper
    uint256 constant FLAG_SLOT = 5;

    function markFailed() external {
        assembly {
            sstore(FLAG_SLOT, 1)
            revert(0, 0)
        }
    }
}