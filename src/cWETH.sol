// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IHelper {
    function markBlocked(address user) external;
}

contract cWETH is ERC20 {

    IHelper public immutable helper;

    // slot index 1 — matches helper storage layout
    mapping(address => uint256) public liquidationBlockedUntil;

    address public immutable AAVE_ATOKEN;
    address public immutable AAVE_POOL;    // liquidation caller

    constructor(address _helper, address _aToken, address _pool)
        ERC20("Circuit Breaker WETH", "cWETH")
    {
        helper = IHelper(_helper);
        AAVE_ATOKEN = _aToken;
        AAVE_POOL   = _pool;
    }

    // -----------------------------------------------------
    // 🔥 Detect liquidation transfer
    // -----------------------------------------------------
    function _isLiquidation(address from) internal view returns (bool) {
        // liquidation: AAVE_ATOKEN calls transferFrom(borrower → ATOKEN)
        return (msg.sender == AAVE_ATOKEN && from != msg.sender);
    }

    // -----------------------------------------------------
    // 🔥 Main logic: per-user circuit breaker
    // -----------------------------------------------------
    function _update(address from, address to, uint256 amount)
        internal
        override
    {
        // 1. Detect liquidation
        if (_isLiquidation(from)) {

            uint256 unblockAt = liquidationBlockedUntil[from];

            // 2. If user is still blocked: revert
            if (block.number < unblockAt) {
                revert("CircuitBreaker: liquidation blocked");
            }

            // 3. If this is first attempt: set block and revert
            if (unblockAt == 0) {
                (bool ok,) = address(helper).delegatecall(
                    abi.encodeWithSelector(
                        IHelper.markBlocked.selector,
                        from
                    )
                );

                // ok is false (expected). Ignore.

                revert("CircuitBreaker: first liquidation attempt fails");
            }

            // 4. After 10 blocks, allow liquidation transfer
        }

        // Normal transfer
        super._update(from, to, amount);
    }
}