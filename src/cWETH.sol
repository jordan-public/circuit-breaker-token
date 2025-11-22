// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/cWETH.sol";
import "../src/LiquidationHelper.sol";

contract cWETHTest is Test {
    cWETH token;
    LiquidationHelper helper;
    address user = address(0x1);
    address aave = address(0x2);

    function setUp() public {
        helper = new LiquidationHelper();
        token = new cWETH(address(helper), 10);

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

        // First attempt fails
        vm.prank(aave);
        vm.expectRevert();
        token.transferFrom(user, aave, 200 ether);

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