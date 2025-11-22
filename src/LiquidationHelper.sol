// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Writes per-user cooldown to caller storage, then reverts.
/// @dev Invoked with DELEGATECALL from cWETH.
contract LiquidationHelper {
    // Must match cWETH storage slot index for liquidationBlockedUntil
    uint256 public constant COOLDOWN_SLOT = 2;

    function markBlocked(address user, uint256 cooldownBlocks) external {
        uint256 unblockAt = block.number + cooldownBlocks;

        uint256 slot = uint256(keccak256(abi.encode(user, COOLDOWN_SLOT)));

        assembly {
            sstore(slot, unblockAt)
            revert(0,0)
        }
    }
}