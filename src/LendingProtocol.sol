// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CircuitBreakerToken, ILiquidationTarget} from "./CircuitBreakerToken.sol";

/// @title Example Lending Protocol
/// @notice Example implementation showing how a lending protocol would integrate with circuit breaker tokens
contract LendingProtocol is ILiquidationTarget {
    // Health factor threshold (1e18 = 100%)
    uint256 public constant LIQUIDATION_THRESHOLD = 1e18;
    
    // User health factors (simplified for example)
    mapping(address => uint256) public healthFactor;
    
    CircuitBreakerToken public immutable collateralToken;
    
    constructor(address _collateralToken) {
        collateralToken = CircuitBreakerToken(_collateralToken);
    }
    
    /// @notice Set health factor for a user (normally calculated from collateral/debt)
    /// @dev In a real protocol, this would be calculated based on collateral value and debt
    function setHealthFactor(address user, uint256 _healthFactor) external {
        healthFactor[user] = _healthFactor;
    }
    
    /// @notice Check if a user's position can be liquidated
    /// @param user The user address to check
    /// @return true if health factor is below threshold (position is unhealthy)
    function canLiquidate(address user) external view returns (bool) {
        return healthFactor[user] < LIQUIDATION_THRESHOLD;
    }
    
    /// @notice Initiate liquidation process for an unhealthy position
    /// @param user The user to liquidate
    function initiateLiquidation(address user) external {
        collateralToken.initiateLiquidation(user);
    }
    
    /// @notice Execute liquidation after cooldown period
    /// @param user The user being liquidated
    /// @param liquidator The address receiving the liquidated collateral
    /// @param amount The amount to liquidate
    function liquidate(address user, address liquidator, uint256 amount) external {
        // The circuit breaker will enforce the cooldown period
        collateralToken.transferFrom(user, liquidator, amount);
        
        // In a real protocol, you would also:
        // - Repay user's debt
        // - Update user's position
        // - Give liquidator a bonus
        // - Update health factor
    }
}
