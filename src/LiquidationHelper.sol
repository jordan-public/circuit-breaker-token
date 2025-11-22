// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidationHelper {
    // writes: liquidationBlockedUntil[user] = block.number + 10
    function markBlocked(address user) external {
        uint256 unblockBlock = block.number + 10;

        // slot = keccak256(user . slot_index)
        uint256 slot = uint256(keccak256(abi.encode(user, uint256(1))));

        assembly {
            sstore(slot, unblockBlock)
            revert(0,0) // inner revert only
        }
    }
}