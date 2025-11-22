// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Interface for protocols to determine if a user position can be liquidated
interface ILiquidationTarget {
    /// @notice Check if a user's position is eligible for liquidation
    /// @param user The user address to check
    /// @return true if the position can be liquidated, false otherwise
    function canLiquidate(address user) external view returns (bool);
}

/// @title Circuit-Breaker WETH (cWETH)
contract cWETH is ERC20 {
    // ERC20 uses slots 0-4 (_balances, _allowances, _totalSupply, _name, _symbol)
    mapping(address => mapping(address => uint256)) public approvalBlock;         // slot 5
    mapping(address => uint256) public liquidationBlockedUntil;                  // slot 6
    mapping(address => uint256) public liquidationWindowEnd;                     // slot 7

    uint256 public immutable cooldownBlocks;
    uint256 public immutable liquidationWindow;
    ILiquidationTarget public immutable liquidationTarget;

    event LiquidationInitiated(address indexed user, uint256 canLiquidateAt, uint256 windowEndsAt);

    constructor(uint256 _cooldown, uint256 _liquidationWindow, address _liquidationTarget)
        ERC20("Circuit Breaker WETH", "cWETH")
    {
        cooldownBlocks = _cooldown;
        liquidationWindow = _liquidationWindow;
        liquidationTarget = ILiquidationTarget(_liquidationTarget);
    }

    /// @notice Mint tokens (for testing purposes)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Initiate liquidation for a user, starting the cooldown period
    /// @param user The user whose position may be liquidated
    function initiateLiquidation(address user) external {
        // Check if the position is actually liquidatable
        require(liquidationTarget.canLiquidate(user), "Position not liquidatable");
        
        uint256 existingCooldown = liquidationBlockedUntil[user];
        
        // Check if liquidation window has expired, if so, allow re-initiation
        if (existingCooldown != 0) {
            uint256 existingWindowEnd = liquidationWindowEnd[user];
            if (block.number <= existingWindowEnd) {
                revert("Liquidation already initiated");
            }
            // Window expired, clean up old state
            delete liquidationBlockedUntil[user];
            delete liquidationWindowEnd[user];
        }
        
        uint256 canLiquidateAt = block.number + cooldownBlocks;
        uint256 windowEnds = canLiquidateAt + liquidationWindow;
        
        liquidationBlockedUntil[user] = canLiquidateAt;
        liquidationWindowEnd[user] = windowEnds;
        
        emit LiquidationInitiated(user, canLiquidateAt, windowEnds);
    }

    function approve(address spender, uint256 amount)
        public override returns (bool)
    {
        approvalBlock[msg.sender][spender] = block.number;
        return super.approve(spender, amount);
    }

    function _update(address from, address to, uint256 amount)
        internal override
    {
        // Skip circuit breaker for mints and burns
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Skip circuit breaker for direct transfers (when msg.sender == from)
        if (msg.sender == from) {
            super._update(from, to, amount);
            return;
        }

        // Circuit breaker logic only applies to transferFrom by third parties
        // Check if this is a user-initiated deposit (same block as approval)
        bool isUserDeposit = (approvalBlock[from][msg.sender] == block.number);

        if (isUserDeposit) {
            super._update(from, to, amount);
            return;
        }

        uint256 canLiquidateAt = liquidationBlockedUntil[from];
        uint256 windowEnds = liquidationWindowEnd[from];

        if (canLiquidateAt == 0) {
            // No liquidation initiated - block the transfer
            revert("CircuitBreaker: must initiate liquidation first");
        }

        if (block.number < canLiquidateAt) {
            // Still in cooldown period - block the transfer
            revert("CircuitBreaker: liquidation in cooldown");
        }

        if (block.number > windowEnds) {
            // Window expired - reset and block the transfer
            delete liquidationBlockedUntil[from];
            delete liquidationWindowEnd[from];
            revert("CircuitBreaker: liquidation window expired");
        }
        
        // Within valid liquidation window - allow the transfer and reset state
        delete liquidationBlockedUntil[from];
        delete liquidationWindowEnd[from];
        super._update(from, to, amount);
    }
}