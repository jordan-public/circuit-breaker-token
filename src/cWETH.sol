// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ILiquidationHelper {
    function markBlocked(address user, uint256 cooldownBlocks) external;
}

/// @title Circuit-Breaker WETH (cWETH)
contract cWETH is ERC20 {
    mapping(address => mapping(address => uint256)) public lastExpectedAllowance; // slot 1
    mapping(address => uint256) public liquidationBlockedUntil;                  // slot 2

    ILiquidationHelper public immutable helper;
    uint256 public immutable cooldownBlocks;

    constructor(address _helper, uint256 _cooldown)
        ERC20("Circuit Breaker WETH", "cWETH")
    {
        helper = ILiquidationHelper(_helper);
        cooldownBlocks = _cooldown;
    }

    function approve(address spender, uint256 amount)
        public override returns (bool)
    {
        lastExpectedAllowance[msg.sender][spender] = amount;
        return super.approve(spender, amount);
    }

    function _approve(address owner, address spender, uint256 amount)
        internal override
    {
        lastExpectedAllowance[owner][spender] = amount;
        super._approve(owner, spender, amount);
    }

    function _update(address from, address to, uint256 amount)
        internal override
    {
        uint256 currentAllowance = allowance(from, msg.sender);
        uint256 expected = lastExpectedAllowance[from][msg.sender];

        bool isUserDeposit =
            (expected != 0) &&
            (currentAllowance + amount == expected);

        if (isUserDeposit) {
            super._update(from, to, amount);
            return;
        }

        uint256 blocked = liquidationBlockedUntil[from];

        if (blocked != 0) {
            if (block.number < blocked) {
                revert("CircuitBreaker: liquidation blocked");
            }
            super._update(from, to, amount);
            return;
        }

        _markCooldown(from);

        revert("CircuitBreaker: first liquidation attempt blocked");
    }

    function _markCooldown(address user) internal {
        (bool ok,) = address(helper).delegatecall(
            abi.encodeWithSelector(
                ILiquidationHelper.markBlocked.selector,
                user,
                cooldownBlocks
            )
        );
        ok; // ignore failure (expected)
    }
}