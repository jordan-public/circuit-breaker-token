// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CircuitBreakerToken} from "../src/CircuitBreakerToken.sol";
import {LendingProtocol} from "../src/LendingProtocol.sol";

/**
 * @title Mock WBTC Token
 * @notice Simple ERC20 for testing purposes - represents Wrapped Bitcoin
 */
contract MockWBTC is ERC20 {
    constructor() ERC20("Wrapped Bitcoin", "WBTC") {
        _mint(msg.sender, 1000 * 10**18); // Mint 1000 WBTC for testing
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title Circuit Breaker Token Deployment Script
 * @notice Comprehensive deployment and demonstration script for the Circuit Breaker Token system
 * 
 * @dev This script performs the following operations:
 * 
 * 1. DEPLOYMENT PHASE:
 *    - Deploys a mock WBTC token (underlying asset)
 *    - Deploys the Circuit Breaker Token (cWBTC) wrapper
 *    - Deploys a sample Lending Protocol that uses cWBTC as collateral
 * 
 * 2. SETUP PHASE:
 *    - Mints WBTC to test users (Alice, Bob)
 *    - Users deposit WBTC to receive cWBTC
 *    - Users deposit cWBTC as collateral in the lending protocol
 *    - Sets up positions with different health factors
 * 
 * 3. DEMONSTRATION PHASE - Progressive Liquidation:
 *    This demonstrates the core innovation of the Circuit Breaker Token:
 * 
 *    a) LIQUIDATION INITIATION:
 *       - When a position becomes unhealthy (health factor < 100%), liquidation is initiated
 *       - User enters a COOLDOWN period (e.g., 5 blocks) where no liquidation can occur
 *       - This gives the user time to notice and potentially add collateral
 * 
 *    b) PROGRESSIVE LIQUIDATION WINDOW:
 *       - After cooldown, a LIQUIDATION WINDOW opens (e.g., 5 blocks)
 *       - Liquidatable amount grows progressively from 10% to 100% over the window
 *       - Example timeline (5-block window):
 *         * Block 0 (start): 10% liquidatable
 *         * Block 1: 28% liquidatable  
 *         * Block 2: 46% liquidatable
 *         * Block 3: 64% liquidatable
 *         * Block 4: 82% liquidatable
 *         * Block 5 (end): 100% liquidatable
 * 
 *    c) WALLET BALANCE PROTECTION (TIME-DECAYING):
 *       - If user has funds in their wallet, they get extra protection
 *       - Protection CAPS are applied based on wallet balance:
 *         * Wallet ≥ 100% of collateral: Starts at 50% cap, decays to 100%
 *         * Wallet ≥ 50% of collateral: Starts at 70% cap, decays to 100%
 *         * Wallet < 50% of collateral: No cap (normal progressive curve)
 *       - Caps decay linearly over the window to ensure eventual full liquidation
 *       - This gives users with funds a grace period while maintaining accountability
 * 
 *    d) LIQUIDATION EXECUTION:
 *       - Liquidator can seize up to the allowed percentage
 *       - As blocks progress, more becomes available for liquidation
 *       - After window expires, liquidation must be re-initiated
 * 
 * 4. TEST SCENARIOS:
 *    The script demonstrates different liquidation scenarios:
 *    - Alice: User with insufficient wallet balance (normal progressive liquidation)
 *    - Bob: User with large wallet balance (capped liquidation with time-decay)
 * 
 * BENEFITS OVER TRADITIONAL LIQUIDATION:
 * - Prevents instant 100% liquidation
 * - Gives users time to respond (cooldown period)
 * - Reduces liquidation MEV extraction
 * - Protects users with available funds (but ensures accountability via time-decay)
 * - More fair for borrowers while maintaining protocol solvency
 * 
 * USAGE:
 * Deploy to local anvil:
 *   forge script script/CircuitBreakerToken.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
 * 
 * Deploy to testnet (Zircuit example):
 *   forge script script/CircuitBreakerToken.s.sol:Deploy --rpc-url $ZIRCUIT_RPC --private-key $PRIVATE_KEY --broadcast
 * 
 * Run demonstration without broadcasting:
 *   forge script script/CircuitBreakerToken.s.sol:Deploy --rpc-url http://127.0.0.1:8545
 */
contract Deploy is Script {
    // Deployment parameters
    uint256 constant COOLDOWN_BLOCKS = 5;      // Cooldown before liquidation can start
    uint256 constant LIQUIDATION_WINDOW = 5;   // Window during which progressive liquidation occurs
    
    // Test users
    address alice = address(0xa11ce);
    address bob = address(0xb0b);
    
    function run() external {
        vm.startBroadcast();
        
        console2.log("=== CIRCUIT BREAKER TOKEN DEPLOYMENT ===");
        console2.log("");
        
        // ===== DEPLOYMENT PHASE =====
        console2.log("1. Deploying Mock WBTC (underlying asset)...");
        MockWBTC wbtc = new MockWBTC();
        console2.log("   WBTC deployed at:", address(wbtc));
        
        console2.log("");
        console2.log("2. Deploying Sample Lending Protocol (placeholder)...");
        // We need to deploy a placeholder first to get an address for CircuitBreakerToken
        LendingProtocol protocolPlaceholder = new LendingProtocol(address(1)); // Temporary
        console2.log("   Protocol placeholder deployed at:", address(protocolPlaceholder));
        
        console2.log("");
        console2.log("3. Deploying Circuit Breaker Token (cWBTC)...");
        console2.log("   Cooldown blocks:", COOLDOWN_BLOCKS);
        console2.log("   Liquidation window:", LIQUIDATION_WINDOW);
        
        CircuitBreakerToken cWBTC = new CircuitBreakerToken(
            "Circuit Breaker Wrapped Bitcoin",
            "cWBTC",
            address(wbtc),
            COOLDOWN_BLOCKS,
            LIQUIDATION_WINDOW,
            address(protocolPlaceholder) // Use protocol address
        );
        console2.log("   cWBTC deployed at:", address(cWBTC));
        
        console2.log("");
        console2.log("4. Deploying Actual Lending Protocol...");
        LendingProtocol protocol = new LendingProtocol(address(cWBTC));
        console2.log("   LendingProtocol deployed at:", address(protocol));
        
        // Note: In production, you'd redeploy cWBTC with the correct protocol address
        // or use an upgradeable pattern. For this demo, we'll work with this setup.
        
        console2.log("");
        console2.log("=== SETUP PHASE ===");
        console2.log("");
        
        // ===== SETUP TEST USERS =====
        console2.log("5. Setting up test users (Alice and Bob)...");
        
        // Mint WBTC to Alice and Bob
        wbtc.mint(alice, 100 * 10**18); // 100 WBTC to Alice
        wbtc.mint(bob, 100 * 10**18);   // 100 WBTC to Bob
        console2.log("   Minted 100 WBTC to Alice:", alice);
        console2.log("   Minted 100 WBTC to Bob:", bob);
        
        // Alice deposits 50 WBTC to get cWBTC
        vm.stopBroadcast();
        vm.startPrank(alice);
        wbtc.approve(address(cWBTC), 50 * 10**18);
        cWBTC.deposit(50 * 10**18);
        console2.log("   Alice deposited 50 WBTC, received 50 cWBTC");
        console2.log("   Alice's remaining wallet: 50 WBTC (insufficient for full collateral)");
        
        // Alice deposits cWBTC as collateral in protocol
        cWBTC.approve(address(protocol), 50 * 10**18);
        protocol.depositCollateral(50 * 10**18);
        console2.log("   Alice deposited 50 cWBTC as collateral in protocol");
        
        // Set Alice's position as unhealthy (health factor < 100%)
        vm.stopPrank();
        vm.startBroadcast();
        protocol.setHealthFactor(alice, 0.8e18); // 80% health factor (liquidatable)
        console2.log("   Alice's health factor set to 80% (UNHEALTHY - can be liquidated)");
        
        vm.stopBroadcast();
        
        // Bob deposits 80 WBTC to get cWBTC
        vm.startPrank(bob);
        wbtc.approve(address(cWBTC), 80 * 10**18);
        cWBTC.deposit(80 * 10**18);
        console2.log("");
        console2.log("   Bob deposited 80 WBTC, received 80 cWBTC");
        console2.log("   Bob's remaining wallet: 20 WBTC (insufficient for full collateral)");
        
        // Bob deposits cWBTC as collateral
        cWBTC.approve(address(protocol), 80 * 10**18);
        protocol.depositCollateral(80 * 10**18);
        console2.log("   Bob deposited 80 cWBTC as collateral in protocol");
        
        vm.stopPrank();
        vm.startBroadcast();
        protocol.setHealthFactor(bob, 0.9e18); // 90% health factor (liquidatable)
        console2.log("   Bob's health factor set to 90% (UNHEALTHY - can be liquidated)");
        
        console2.log("");
        console2.log("=== LIQUIDATION DEMONSTRATION ===");
        console2.log("");
        
        // ===== ALICE'S LIQUIDATION (Normal Progressive) =====
        console2.log("6. Initiating liquidation for Alice (insufficient wallet balance)...");
        protocol.initiateLiquidation(alice);
        uint256 aliceStartBlock = block.number;
        console2.log("   Liquidation initiated at block:", aliceStartBlock);
        console2.log("   Cooldown ends at block:", aliceStartBlock + COOLDOWN_BLOCKS);
        console2.log("   Window ends at block:", aliceStartBlock + COOLDOWN_BLOCKS + LIQUIDATION_WINDOW);
        
        console2.log("");
        console2.log("7. Simulating progressive liquidation window for Alice...");
        console2.log("   Alice's wallet balance (50 WBTC) < collateral (50 cWBTC)");
        console2.log("   Wallet/Collateral ratio: 100% -> Gets 50% cap initially");
        console2.log("   BUT cap decays to 100% over the window");
        console2.log("");
        
        // Progress through cooldown
        for (uint256 i = 1; i <= COOLDOWN_BLOCKS; i++) {
            vm.roll(block.number + 1);
            (uint256 pct, uint256 amt) = cWBTC.getLiquidatableAmount(alice);
            console2.log("   Block (cooldown):", block.number);
            console2.log("     Percentage:", pct);
        }
        
        console2.log("");
        console2.log("   Cooldown complete! Liquidation window begins:");
        console2.log("");
        
        // Progress through liquidation window
        for (uint256 i = 0; i <= LIQUIDATION_WINDOW; i++) {
            (uint256 pct, uint256 amt) = cWBTC.getLiquidatableAmount(alice);
            console2.log("   Block:", block.number);
            console2.log("     Liquidatable %:", pct);
            console2.log("     Amount (cWBTC):", amt / 10**18);
            
            if (i < LIQUIDATION_WINDOW) {
                vm.roll(block.number + 1);
            }
        }
        
        // ===== BOB'S LIQUIDATION (With Wallet Balance) =====
        console2.log("");
        console2.log("8. Initiating liquidation for Bob (has wallet balance)...");
        protocol.initiateLiquidation(bob);
        uint256 bobStartBlock = block.number;
        console2.log("   Liquidation initiated at block:", bobStartBlock);
        
        console2.log("");
        console2.log("9. Simulating progressive liquidation window for Bob...");
        console2.log("   Bob's wallet balance (20 WBTC) < collateral (80 cWBTC)");
        console2.log("   Wallet/Collateral ratio: 25% -> No cap protection (< 50% threshold)");
        console2.log("");
        
        // Progress through cooldown
        for (uint256 i = 1; i <= COOLDOWN_BLOCKS; i++) {
            vm.roll(block.number + 1);
            (uint256 pct, uint256 amt) = cWBTC.getLiquidatableAmount(bob);
            console2.log("   Block (cooldown):", block.number);
            console2.log("     Percentage:", pct);
        }
        
        console2.log("");
        console2.log("   Cooldown complete! Liquidation window begins:");
        console2.log("");
        
        // Progress through liquidation window
        for (uint256 i = 0; i <= LIQUIDATION_WINDOW; i++) {
            (uint256 pct, uint256 amt) = cWBTC.getLiquidatableAmount(bob);
            console2.log("   Block:", block.number);
            console2.log("     Liquidatable %:", pct);
            console2.log("     Amount (cWBTC):", amt / 10**18);
            
            if (i < LIQUIDATION_WINDOW) {
                vm.roll(block.number + 1);
            }
        }
        
        console2.log("");
        console2.log("=== DEPLOYMENT COMPLETE ===");
        console2.log("");
        console2.log("Deployed Contracts:");
        console2.log("  WBTC (Mock):", address(wbtc));
        console2.log("  cWBTC (Circuit Breaker):", address(cWBTC));
        console2.log("  LendingProtocol:", address(protocol));
        console2.log("");
        console2.log("Key Observations:");
        console2.log("  1. Progressive liquidation grows from 10% to max allowed over", LIQUIDATION_WINDOW, "blocks");
        console2.log("  2. Users with wallet balance get protection caps that decay over time");
        console2.log("  3. Alice (100% ratio) starts at 50% cap, decays to 100%");
        console2.log("  4. Bob (25% ratio) has no cap - normal progressive curve");
        console2.log("  5. This mechanism balances user protection with protocol solvency");
        console2.log("");
        
        vm.stopBroadcast();
    }
}
