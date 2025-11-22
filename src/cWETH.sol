// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IHelper {
    function markFailed() external;
}

contract Wrapper is ERC20 {

    IHelper public immutable helper;

    // Storage slot 5 is used by Helper to write this.
    // We must anchor it to slot 5.
    bool public firstLiquidationAttemptDone; // slot 5

    constructor(address _helper)
        ERC20("Wrapped Collateral", "wCOL")
    {
        helper = IHelper(_helper);
    }

    // -----------------------------------------------------
    //  🔥 Detection of liquidation attempts
    // -----------------------------------------------------
    //
    // You must adapt this function to how *your* lending protocol
    // triggers liquidation transfers.
    //
    // For example:
    // - Aave v2: transferFrom(borrower → aToken contract)
    // - Compound: seize() calls transfer(borrower → liquidator)
    //
    // For now we assume ANY transfer that moves tokens FROM a borrower
    // to ANY address inside a lending protocol is considered liquidation.
    // -----------------------------------------------------

    function _isLiquidation(address from, address to) internal view returns (bool) {
        // Example placeholder for logic you define:
        // - Check if `msg.sender` is Aave's pool
        // - Check if `to` is the protocol
        // - Check if `from` is undercollateralized
        // etc.

        // For demonstration, treat "from != msg.sender" as liquidation attempt.
        // Replace with real logic!
        return from != msg.sender;
    }

    // -----------------------------------------------------
    //  🔥 ERC20 transfer logic override
    // -----------------------------------------------------

    function _update(address from, address to, uint256 amount)
        internal
        override
    {
        // Detect liquidation attempt
        if (_isLiquidation(from, to)) {

            // FIRST liquidation attempt → perform special behavior
            if (!firstLiquidationAttemptDone) {

                // 1. Use delegatecall to write the flag in THIS contract
                //    even though helper will revert internally.
                (bool ok, ) = address(helper).delegatecall(
                    abi.encodeWithSelector(
                        IHelper.markFailed.selector
                    )
                );

                // ok == false is expected. Ignore.

                // 2. NOW revert *this* call
                revert("Liquidation temporarily disabled");
            }
        }

        // SECOND attempt → succeed normally
        super._update(from, to, amount);
    }
}