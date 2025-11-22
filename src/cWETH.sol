// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface ILiquidationHelper {
    function markBlocked(address user, uint256 cooldownBlocks) external;
}

/// @title Circuit-Breaker WETH (cWETH)
/// @notice ERC20 wrapper token that protects Aave/Morpho/Compound collateral
///         by delaying liquidation attempts.
/// @dev Handle deposits normally, block liquidation attempts for N blocks.
contract cWETH is ERC20 {

    // -------------------------------------------------------------------------
    // Storage layout
    // -------------------------------------------------------------------------

    /// @notice Expected allowance amount after a user calls approve()
    /// @dev lastExpectedAllowance[owner][spender] = amount
    mapping(address => mapping(address => uint256)) public lastExpectedAllowance;

    /// @notice Per-user block height until which liquidation is blocked
    /// @dev slot index 2 (must match LiquidationHelper)
    mapping(address => uint256) public liquidationBlockedUntil;

    /// @notice Helper called via delegatecall
    ILiquidationHelper public immutable helper;

    /// @notice Number of blocks to block liquidation after a first attempt
    uint256 public immutable cooldownBlocks;


    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        address _helper,
        uint256 _cooldownBlocks
    )
        ERC20("Circuit Breaker WETH", "cWETH")
    {
        require(_helper != address(0), "zero helper");
        helper = ILiquidationHelper(_helper);
        cooldownBlocks = _cooldownBlocks;
    }


    // -------------------------------------------------------------------------
    // Approval tracking logic (detecting user-initiated deposits)
    // -------------------------------------------------------------------------

    /// @notice Override approve to track the expected post-deposit allowance
    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        lastExpectedAllowance[msg.sender][spender] = amount;
        return super.approve(spender, amount);
    }

    /// @notice For permit() flows, track expected allowance too
    function _approve(address owner, address spender, uint256 amount)
        internal
        override
    {
        lastExpectedAllowance[owner][spender] = amount;
        super._approve(owner, spender, amount);
    }


    // -------------------------------------------------------------------------
    // Core logic: detect user deposit vs liquidation
    // -------------------------------------------------------------------------

    /// @inheritdoc ERC20
    function _update(address from, address to, uint256 amount)
        internal
        override
    {
        // Detect if this transfer is the result of a *user-initiated deposit*.
        //
        // Deposit pattern:
        //   User sets allowance = X
        //   Aave pulls amount A (transferFrom)
        //   Allowance becomes X-A
        //
        // So if (currentAllowance + amount == lastExpectedAllowance),
        // it is a direct deposit flow triggered by the user.
        uint256 currentAllowance = allowance(from, msg.sender);
        uint256 expected = lastExpectedAllowance[from][msg.sender];

        bool isUserDeposit =
            (expected != 0) &&
            (currentAllowance + amount == expected);

        if (isUserDeposit) {
            // Normal deposit flow — skip liquidation logic.
            super._update(from, to, amount);
            return;
        }

        // Otherwise this is a forced token movement (liquidation/seizure).

        // STEP 1: Check if user is in cooldown
        uint256 blockedUntil = liquidationBlockedUntil[from];

        if (blockedUntil != 0) {
            // User has an active cooldown
            if (block.number < blockedUntil) {
                revert("CircuitBreaker: liquidation blocked");
            }
            // Cooldown over → allow liquidation
            super._update(from, to, amount);
            return;
        }

        // STEP 2: First liquidation attempt for this user → block it and set cooldown.
        _markCooldown(from);

        revert("CircuitBreaker: first liquidation attempt blocked");
    }


    // -------------------------------------------------------------------------
    // Internal: write cooldown via delegatecall
    // -------------------------------------------------------------------------

    function _markCooldown(address user) internal {
        // Will sstore(cooldown) then revert inside helper
        (bool ok,) = address(helper).delegatecall(
            abi.encodeWithSelector(
                ILiquidationHelper.markBlocked.selector,
                user,
                cooldownBlocks
            )
        );

        // ok == false is expected because helper always reverts.
        // We ignore it.
        ok;
    }
}