// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Interface for protocols to determine if a user position can be liquidated
interface ILiquidationTarget {
    /// @notice Check if a user's position is eligible for liquidation
    /// @param user The user address to check
    /// @return true if the position can be liquidated, false otherwise
    function canLiquidate(address user) external view returns (bool);
    
    /// @notice Get the user's collateral balance in the protocol
    /// @param user The user address to check
    /// @return The amount of collateral the user has deposited
    function getUserCollateral(address user) external view returns (uint256);
}

/// @title Circuit Breaker Token
/// @notice Generic wrapper that adds circuit breaker liquidation protection to any ERC20 token
/// @dev Examples: cWETH (wraps WETH), cUSDC (wraps USDC), cDAI (wraps DAI)
contract CircuitBreakerToken is ERC20 {
    // ERC20 uses slots 0-4 (_balances, _allowances, _totalSupply, _name, _symbol)
    mapping(address => mapping(address => uint256)) public approvalBlock;         // slot 5
    mapping(address => uint256) public liquidationBlockedUntil;                  // slot 6
    mapping(address => uint256) public liquidationWindowEnd;                     // slot 7
    mapping(address => uint256) public maxLiquidatableAmount;                    // slot 8

    IERC20 public immutable underlying;
    uint256 public immutable cooldownBlocks;
    uint256 public immutable liquidationWindow;
    ILiquidationTarget public immutable liquidationTarget;
    
    // Liquidation curve parameters
    uint256 public constant MIN_LIQUIDATION_PCT = 10; // 10% minimum
    uint256 public constant MAX_LIQUIDATION_PCT = 100; // 100% maximum

    event LiquidationInitiated(address indexed user, uint256 canLiquidateAt, uint256 windowEndsAt, uint256 maxAmount);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        address _underlying,
        uint256 _cooldown,
        uint256 _liquidationWindow,
        address _liquidationTarget
    )
        ERC20(name, symbol)
    {
        underlying = IERC20(_underlying);
        cooldownBlocks = _cooldown;
        liquidationWindow = _liquidationWindow;
        liquidationTarget = ILiquidationTarget(_liquidationTarget);
    }

    /// @notice Deposit underlying tokens and receive wrapped tokens
    /// @param amount Amount of underlying tokens to deposit
    function deposit(uint256 amount) external {
        underlying.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    /// @notice Withdraw underlying tokens by burning wrapped tokens
    /// @param amount Amount of wrapped tokens to burn
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        underlying.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /// @notice Initiate liquidation (called by liquidation target protocol)
    /// @param user The user to liquidate
    function initiateLiquidation(address user) external {
        // Query msg.sender (the actual protocol calling this) for liquidation eligibility
        require(ILiquidationTarget(msg.sender).canLiquidate(user), "Position not liquidatable");
        
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
            delete maxLiquidatableAmount[user];
        }
        
        uint256 canLiquidateAt = block.number + cooldownBlocks;
        uint256 windowEnds = canLiquidateAt + liquidationWindow;
        
        // Query the caller (msg.sender is the protocol) for the user's collateral
        uint256 userCollateral = ILiquidationTarget(msg.sender).getUserCollateral(user);
        
        liquidationBlockedUntil[user] = canLiquidateAt;
        liquidationWindowEnd[user] = windowEnds;
        maxLiquidatableAmount[user] = userCollateral;
        
        emit LiquidationInitiated(user, canLiquidateAt, windowEnds, userCollateral);
    }
    
    /// @notice Calculate how much can be liquidated based on time elapsed and collateral
    /// @param user The user whose liquidation percentage to calculate
    /// @return percentage The percentage (0-100) that can be liquidated
    /// @return amount The actual amount that can be liquidated
    function getLiquidatableAmount(address user) public view returns (uint256 percentage, uint256 amount) {
        uint256 canLiquidateAt = liquidationBlockedUntil[user];
        uint256 windowEnds = liquidationWindowEnd[user];
        
        // No liquidation initiated
        if (canLiquidateAt == 0) {
            return (0, 0);
        }
        
        // Still in cooldown
        if (block.number < canLiquidateAt) {
            return (0, 0);
        }
        
        // Window expired
        if (block.number > windowEnds) {
            return (0, 0);
        }
        
        // Calculate progressive percentage based on blocks elapsed
        uint256 blocksIntoWindow = block.number - canLiquidateAt;
        uint256 totalWindowBlocks = liquidationWindow;
        
        // Linear progression from MIN_LIQUIDATION_PCT to MAX_LIQUIDATION_PCT
        percentage = MIN_LIQUIDATION_PCT + 
            ((MAX_LIQUIDATION_PCT - MIN_LIQUIDATION_PCT) * blocksIntoWindow) / totalWindowBlocks;
        
        // Consider user's wallet balance for potential collateral additions
        uint256 walletBalance = underlying.balanceOf(user);
        uint256 userCollateral = liquidationTarget.getUserCollateral(user);
        
        // If user has significant wallet balance, cap max liquidation BUT decay over time
        // This gives users with funds a grace period, but if they refuse to act,
        // the cap gradually increases until full liquidation is possible
        uint256 maxAllowedPct = MAX_LIQUIDATION_PCT;
        if (walletBalance > 0 && userCollateral > 0) {
            uint256 walletToCollateralRatio = (walletBalance * 100) / userCollateral;
            
            // Determine base cap based on wallet balance
            uint256 baseCap;
            if (walletToCollateralRatio >= 100) {
                baseCap = 50;  // Start at 50% if user has enough to fully cover
            } else if (walletToCollateralRatio >= 50) {
                baseCap = 70;  // Start at 70% if user has significant funds
            } else {
                baseCap = 100; // No cap if insufficient wallet balance
            }
            
            // Decay the protection over the window: cap increases from baseCap to 100%
            // This gives users time to act, but ensures eventual full liquidation if they don't
            if (baseCap < 100) {
                uint256 capIncrease = ((100 - baseCap) * blocksIntoWindow) / totalWindowBlocks;
                maxAllowedPct = baseCap + capIncrease;
            }
        }
        
        // Cap percentage at the maximum allowed based on wallet balance and time decay
        if (percentage > maxAllowedPct) {
            percentage = maxAllowedPct;
        }
        
        // Calculate actual amount based on percentage of max liquidatable amount
        amount = (maxLiquidatableAmount[user] * percentage) / 100;
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
        // Allow transfers initiated by contracts (protocol deposits)
        // EOAs can't have code, so if msg.sender has code, it's a contract
        uint256 senderCodeSize;
        assembly {
            senderCodeSize := extcodesize(caller())
        }
        if (senderCodeSize > 0) {
            super._update(from, to, amount);
            return;
        }
        
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
            delete maxLiquidatableAmount[from];
            revert("CircuitBreaker: liquidation window expired");
        }
        
        // Check if amount exceeds progressive liquidation limit
        (, uint256 maxAmount) = getLiquidatableAmount(from);
        require(amount <= maxAmount, "CircuitBreaker: exceeds liquidatable amount");
        
        // Within valid liquidation window - allow the transfer and reset state
        delete liquidationBlockedUntil[from];
        delete liquidationWindowEnd[from];
        delete maxLiquidatableAmount[from];
        super._update(from, to, amount);
    }
}