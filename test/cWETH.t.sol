// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/cWETH.sol";

contract MockLiquidationTarget {
    mapping(address => bool) public liquidatable;
    
    function setLiquidatable(address user, bool status) external {
        liquidatable[user] = status;
    }
    
    function canLiquidate(address user) external view returns (bool) {
        return liquidatable[user];
    }
}

contract cWETHTest is Test {
    cWETH token;
    MockLiquidationTarget liquidationTarget;
    address user = address(0x1);
    address aave = address(0x2);

    function setUp() public {
        liquidationTarget = new MockLiquidationTarget();
        token = new cWETH(10, 5, address(liquidationTarget)); // 10 block cooldown, 5 block window

        vm.prank(user);
        token.mint(user, 1000 ether);
    }

    function testUserDeposit() public {
        vm.prank(user);
        token.approve(aave, 100 ether);

        vm.prank(aave);
        token.transferFrom(user, aave, 50 ether);

        assertEq(token.balanceOf(aave), 50 ether);
    }

    function testLiquidationBlockedThenAllowed() public {
        vm.prank(user);
        token.approve(aave, 1000 ether);

        // Simulate time passing (user's position becomes unhealthy)
        vm.roll(block.number + 1);

        // Cannot initiate liquidation if position is not liquidatable
        vm.prank(aave);
        vm.expectRevert("Position not liquidatable");
        token.initiateLiquidation(user);

        // Mark user as liquidatable
        liquidationTarget.setLiquidatable(user, true);

        // Without initiation, liquidation fails
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: must initiate liquidation first");
        token.transferFrom(user, aave, 200 ether);

        // Initiate liquidation (can be called by anyone, e.g., AAVE)
        vm.prank(aave);
        token.initiateLiquidation(user);

        // Immediately after initiation, still in cooldown
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: liquidation in cooldown");
        token.transferFrom(user, aave, 200 ether);

        // Advance fewer than 10 blocks (still in cooldown)
        vm.roll(block.number + 5);

        // Still blocked
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: liquidation in cooldown");
        token.transferFrom(user, aave, 200 ether);

        // Pass cooldown (at block 1 + 1 + 5 + 5 = 12, cooldown ends at block 2 + 10 = 12)
        vm.roll(block.number + 5);

        // Liquidation now succeeds (within window)
        vm.prank(aave);
        token.transferFrom(user, aave, 200 ether);

        assertEq(token.balanceOf(aave), 200 ether);
    }

    function testLiquidationWindowExpires() public {
        vm.prank(user);
        token.approve(aave, 1000 ether);

        vm.roll(block.number + 1);

        // Mark user as liquidatable
        liquidationTarget.setLiquidatable(user, true);

        // Initiate liquidation
        vm.prank(aave);
        token.initiateLiquidation(user);

        // Advance past cooldown + window (10 + 5 + 1 = 16 blocks)
        vm.roll(block.number + 16);

        // Window expired - liquidation fails
        vm.prank(aave);
        vm.expectRevert("CircuitBreaker: liquidation window expired");
        token.transferFrom(user, aave, 200 ether);

        // Must re-initiate
        vm.prank(aave);
        token.initiateLiquidation(user);

        // Advance to valid window
        vm.roll(block.number + 10);

        // Now succeeds
        vm.prank(aave);
        token.transferFrom(user, aave, 200 ether);

        assertEq(token.balanceOf(aave), 200 ether);
    }

    function testCannotInitiateLiquidationForHealthyPosition() public {
        vm.prank(user);
        token.approve(aave, 1000 ether);

        // Position is healthy (not liquidatable)
        vm.prank(aave);
        vm.expectRevert("Position not liquidatable");
        token.initiateLiquidation(user);

        // Verify no state was changed
        assertEq(token.liquidationBlockedUntil(user), 0);
        assertEq(token.liquidationWindowEnd(user), 0);
    }
}