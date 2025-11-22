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
    
    // User collateral amounts
    mapping(address => uint256) public userCollateral;
    
    CircuitBreakerToken public collateralToken;
    
    constructor(address _collateralToken) {
        collateralToken = CircuitBreakerToken(_collateralToken);
    }
    
    /// @notice Set the collateral token (for testing)
    function setCollateralToken(address _collateralToken) external {
        collateralToken = CircuitBreakerToken(_collateralToken);
    }
    
    /// @notice Set health factor for a user (normally calculated from collateral/debt)
    /// @dev In a real protocol, this would be calculated based on collateral value and debt
    function setHealthFactor(address user, uint256 _healthFactor) external {
        healthFactor[user] = _healthFactor;
    }
    
    /// @notice Set collateral for a user (for testing)
    /// @dev In a real protocol, this would be tracked when depositing
    function setCollateral(address user, uint256 amount) external {
        userCollateral[user] = amount;
    }
    
    /// @notice Check if a user's position can be liquidated
    /// @param user The user address to check
    /// @return true if health factor is below threshold (position is unhealthy)
    function canLiquidate(address user) external view returns (bool) {
        return healthFactor[user] < LIQUIDATION_THRESHOLD;
    }
    
    /// @notice Get the user's collateral balance
    /// @param user The user address to check
    /// @return The amount of collateral the user has deposited
    function getUserCollateral(address user) external view returns (uint256) {
        return userCollateral[user];
    }
    
    /// @notice Deposit collateral (for testing)
    /// @param amount The amount of collateral to deposit
    function depositCollateral(uint256 amount) external {
        collateralToken.transferFrom(msg.sender, address(this), amount);
        userCollateral[msg.sender] += amount;
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
        // The circuit breaker will enforce the cooldown period and progressive limits
        collateralToken.transferFrom(user, liquidator, amount);
        
        // Update user's collateral
        userCollateral[user] -= amount;
        
        // In a real protocol, you would also:
        // - Repay user's debt
        // - Give liquidator a bonus
        // - Update health factor
    }
}
