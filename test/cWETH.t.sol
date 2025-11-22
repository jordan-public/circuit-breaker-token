// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/cWETH.sol";

contract cWETHTest is Test {
    cWETH token;
    address user = address(0x1);
    address aave = address(0x2);

    function setUp() public {
        token = new cWETH(10);

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

        // First attempt sets the cooldown but doesn't transfer
        vm.prank(aave);
        bool success = token.transferFrom(user, aave, 200 ether);
        assertTrue(success, "First transferFrom should return true");
        assertEq(token.balanceOf(aave), 0, "No tokens should be transferred on first attempt");

        // Advance fewer than 10 blocks
        vm.roll(block.number + 5);

        // Still blocked
        vm.prank(aave);
        vm.expectRevert();
        token.transferFrom(user, aave, 200 ether);

        // Pass cooldown
        vm.roll(block.number + 10);

        // Liquidation now succeeds
        vm.prank(aave);
        token.transferFrom(user, aave, 200 ether);

        assertEq(token.balanceOf(aave), 200 ether);
    }
}