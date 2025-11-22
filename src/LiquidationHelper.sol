// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Helper {
    // storage slot 0 is A.hasFailed
    function markFailed() external {
        assembly {
            sstore(0, 1)       // write hasFailed = true
            revert(0, 0)       // revert only delegatecall frame
        }
    }
}