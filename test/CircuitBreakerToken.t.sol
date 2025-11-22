// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CircuitBreakerToken.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockLiquidationTarget {
    mapping(address => bool) public liquidatable;
    mapping(address => uint256) public collateral;
    
    function setLiquidatable(address user, bool status) external {
        liquidatable[user] = status;
    }
    
    function setCollateral(address user, uint256 amount) external {
        collateral[user] = amount;
    }
    
    function canLiquidate(address user) external view returns (bool) {
        return liquidatable[user];
    }
    
    function getUserCollateral(address user) external view returns (uint256) {
        return collateral[user];
    }
}

contract CircuitBreakerTokenTest is Test {
    CircuitBreakerToken cWETH;  // Example: wrapping WETH
    MockERC20 underlying;
    MockLiquidationTarget liquidationTarget;
    address user = address(0x1);
    address aave = address(0x2);

    function setUp() public {
        underlying = new MockERC20("Wrapped Ether", "WETH");
        liquidationTarget = new MockLiquidationTarget();
        cWETH = new CircuitBreakerToken(
            "Circuit Breaker WETH",
            "cWETH",
            address(underlying),
            10,  // 10 block cooldown
            5,   // 5 block window
            address(liquidationTarget)
        );

        // Mint underlying tokens to user and have them deposit
        underlying.mint(user, 1000 ether);
        vm.startPrank(user);
        underlying.approve(address(cWETH), 1000 ether);
        cWETH.deposit(1000 ether);
        vm.stopPrank();
    }

    function testUserDeposit() public {
        // Regular user transfer (not a liquidation) should work
        // The position is healthy (not liquidatable)
        liquidationTarget.setLiquidatable(user, false);
        
        vm.roll(block.number + 1);  // Move to a new block first
        
        vm.startPrank(user);
        cWETH.approve(aave, 500 ether);
        vm.stopPrank();
        
        // Same block transfer should work because liquidationBlockedUntil == 0
        vm.prank(aave);
        cWETH.transferFrom(user, aave, 50 ether);
        
        assertEq(cWETH.balanceOf(user), 950 ether);
        assertEq(cWETH.balanceOf(aave), 50 ether);
    }

    function testLiquidationBlockedThenAllowed() public {
        // Make position liquidatable
        liquidationTarget.setLiquidatable(user, true);
        liquidationTarget.setCollateral(user, 1000 ether);
        
        vm.roll(block.number + 1);
        vm.prank(user);
        cWETH.approve(aave, 1000 ether);
        
        // Roll forward to avoid same-block approval bypass
        vm.roll(block.number + 1);
        
        // Initiate liquidation
        vm.prank(aave);
        cWETH.initiateLiquidation(user);

        // Immediately after initiation, still in cooldown
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: liquidation in cooldown");
        cWETH.transferFrom(user, aave, 200 ether);

        // Advance fewer than 10 blocks (still in cooldown)
        vm.roll(block.number + 5);

        // Still blocked
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: liquidation in cooldown");
        cWETH.transferFrom(user, aave, 200 ether);

        // Advance to reach cooldown (total 10 blocks)
        vm.roll(block.number + 5);

        // Now at start of window, only 10% can be liquidated (100 ether of 1000)
        (uint256 pct, uint256 maxAmount) = cWETH.getLiquidatableAmount(user);
        assertEq(pct, 10); // 10% at start of window
        assertEq(maxAmount, 100 ether);
        
        // Try to liquidate more than allowed - should fail
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: exceeds liquidatable amount");
        cWETH.transferFrom(user, aave, 200 ether);
        
        // Liquidate allowed amount
        vm.prank(aave);
        cWETH.transferFrom(user, aave, 100 ether);

        assertEq(cWETH.balanceOf(user), 900 ether);
        assertEq(cWETH.balanceOf(aave), 100 ether);
    }

    function testLiquidationWindowExpires() public {
        // Make position liquidatable
        liquidationTarget.setLiquidatable(user, true);
        liquidationTarget.setCollateral(user, 1000 ether);
        
        vm.roll(block.number + 1);
        vm.prank(user);
        cWETH.approve(aave, 1000 ether);
        
        vm.roll(block.number + 1);
        
        // Initiate liquidation
        vm.prank(aave);
        cWETH.initiateLiquidation(user);
        
        // Advance past both cooldown (10) and window (5) = 15 blocks total
        vm.roll(block.number + 16);
        
        // Liquidation window has expired
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: liquidation window expired");
        cWETH.transferFrom(user, aave, 200 ether);
        
        assertEq(cWETH.balanceOf(user), 1000 ether);
        assertEq(cWETH.balanceOf(aave), 0);
    }
    
    function testProgressiveLiquidation() public {
        // Make position liquidatable
        liquidationTarget.setLiquidatable(user, true);
        liquidationTarget.setCollateral(user, 1000 ether);
        
        vm.roll(block.number + 1);
        vm.prank(user);
        cWETH.approve(aave, 1000 ether);
        
        vm.roll(block.number + 1);
        
        // Initiate liquidation
        vm.prank(aave);
        cWETH.initiateLiquidation(user);
        
        // Advance to start of window (10 blocks)
        vm.roll(block.number + 10);
        
        // At block 0 of window: 10% liquidatable
        (uint256 pct1, uint256 amt1) = cWETH.getLiquidatableAmount(user);
        assertEq(pct1, 10);
        assertEq(amt1, 100 ether);
        
        // Advance halfway through window (2.5 blocks)
        vm.roll(block.number + 2);
        
        // At block 2 of 5: 10% + (90% * 2/5) = 10% + 36% = 46%
        (uint256 pct2, uint256 amt2) = cWETH.getLiquidatableAmount(user);
        assertEq(pct2, 46);
        assertEq(amt2, 460 ether);
        
        // Advance to end of window (5 blocks total)
        vm.roll(block.number + 3);
        
        // At block 5 of 5: 100% liquidatable
        (uint256 pct3, uint256 amt3) = cWETH.getLiquidatableAmount(user);
        assertEq(pct3, 100);
        assertEq(amt3, 1000 ether);
    }
    
    function testWalletBalanceReducesLiquidation() public {
        // User has significant wallet balance
        underlying.mint(user, 600 ether); // 60% of collateral
        
        liquidationTarget.setLiquidatable(user, true);
        liquidationTarget.setCollateral(user, 1000 ether);
        
        vm.roll(block.number + 1);
        vm.prank(user);
        cWETH.approve(aave, 1000 ether);
        
        vm.roll(block.number + 1);
        
        // Initiate liquidation
        vm.prank(aave);
        cWETH.initiateLiquidation(user);
        
        // Advance to start of window
        vm.roll(block.number + 10);
        
        // Wallet balance 600e, collateral 1000e -> ratio = 60%
        // Base percentage at start = 10%
        // Reduction = 60% * 10% / 300 = 2%
        // Final = 10% - 2% = 8%
        (uint256 pct, uint256 amt) = cWETH.getLiquidatableAmount(user);
        assertEq(pct, 8);
        assertEq(amt, 80 ether);
    }

    function testCannotInitiateLiquidationForHealthyPosition() public {
        vm.prank(user);
        cWETH.approve(aave, 1000 ether);

        // Position is healthy (not liquidatable)
        vm.prank(aave);
        vm.expectRevert("Position not liquidatable");
        cWETH.initiateLiquidation(user);

        // Verify no state was changed
        assertEq(cWETH.liquidationBlockedUntil(user), 0);
        assertEq(cWETH.liquidationWindowEnd(user), 0);
    }

    function testDepositAndWithdraw() public {
        address user2 = address(0x5);
        underlying.mint(user2, 500 ether);
        
        vm.startPrank(user2);
        underlying.approve(address(cWETH), 500 ether);
        cWETH.deposit(500 ether);
        vm.stopPrank();
        
        assertEq(cWETH.balanceOf(user2), 500 ether);
        assertEq(underlying.balanceOf(user2), 0);
        
        // Withdraw
        vm.prank(user2);
        cWETH.withdraw(500 ether);
        
        assertEq(cWETH.balanceOf(user2), 0);
        assertEq(underlying.balanceOf(user2), 500 ether);
    }
}