// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Circuit-Breaker WETH (cWETH)
contract cWETH is ERC20 {
    // ERC20 uses slots 0-4 (_balances, _allowances, _totalSupply, _name, _symbol)
    mapping(address => mapping(address => uint256)) public approvalBlock;         // slot 5
    mapping(address => uint256) public liquidationBlockedUntil;                  // slot 6

    uint256 public immutable cooldownBlocks;

    constructor(uint256 _cooldown)
        ERC20("Circuit Breaker WETH", "cWETH")
    {
        cooldownBlocks = _cooldown;
    }

    /// @notice Mint tokens (for testing purposes)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
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

        uint256 blocked = liquidationBlockedUntil[from];

        if (blocked == 0) {
            // First liquidation attempt - set the cooldown and return WITHOUT transferring
            liquidationBlockedUntil[from] = block.number + cooldownBlocks;
            // Don't call super._update, so no transfer happens
            // Just return silently (transfer of 0 tokens)
            return;
        }

        if (block.number < blocked) {
            // During cooldown period - revert
            revert("CircuitBreaker: liquidation blocked");
        }
        
        // Cooldown has passed, allow the transfer
        super._update(from, to, amount);
    }
}