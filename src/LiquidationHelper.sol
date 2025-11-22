// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Writes per-user cooldown to caller storage, then reverts.
/// @dev This is invoked with DELEGATECALL from cWETH, so it writes to cWETH storage.
contract LiquidationHelper {
    // slot indices must match cWETH storage layout
    // liquidationBlockedUntil: mapping(address => uint256) is stored at slot 2

    uint256 public constant COOLDOWN_SLOT = 2; // for keccak(user,2)

    function markBlocked(address user, uint256 cooldownBlocks) external {
        uint256 unblockAt = block.number + cooldownBlocks;

        // Compute storage slot for liquidationBlockedUntil[user]
        uint256 slot = uint256(keccak256(abi.encode(user, COOLDOWN_SLOT)));

        assembly {
            sstore(slot, unblockAt)
            revert(0, 0)
        }
    }
}