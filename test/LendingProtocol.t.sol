// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/cWETH.sol";
import "../src/LendingProtocol.sol";

contract LendingProtocolTest is Test {
    cWETH token;
    LendingProtocol protocol;
    address user = address(0x1);
    address liquidator = address(0x2);

    function setUp() public {
        // Deploy protocol first (with temporary token address)
        protocol = new LendingProtocol(address(0x1));
        
        // Deploy cWETH with the protocol as the liquidation target
        token = new cWETH(10, 5, address(protocol));
        
        // Note: We can't update the protocol's token reference, so we work with this setup
        // In a real deployment, you'd deploy protocol last or use an initializer pattern

        // Mint tokens to user
        token.mint(user, 1000 ether);
        
        // User approves liquidators to manage their tokens
        vm.startPrank(user);
        token.approve(liquidator, type(uint256).max);
        token.approve(address(0x3), type(uint256).max); // liquidator2
        vm.stopPrank();
        
        // Advance a block so approvals aren't in the same block as liquidations
        vm.roll(block.number + 1);
    }

    function testHealthyPositionCannotBeLiquidated() public {
        // User has healthy position (health factor = 150%)
        protocol.setHealthFactor(user, 1.5e18);

        // Cannot initiate liquidation directly on token
        vm.expectRevert("Position not liquidatable");
        token.initiateLiquidation(user);
    }

    function testUnhealthyPositionCanBeLiquidated() public {
        // User's position becomes unhealthy (health factor = 80%)
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation directly on token (protocol's canLiquidate will be called)
        vm.prank(liquidator);
        token.initiateLiquidation(user);

        // Cannot liquidate immediately (in cooldown)
        vm.prank(liquidator);
        vm.expectRevert("CircuitBreaker: liquidation in cooldown");
        token.transferFrom(user, liquidator, 200 ether);

        // Advance past cooldown
        vm.roll(block.number + 11);

        // Now liquidation succeeds
        vm.prank(liquidator);
        token.transferFrom(user, liquidator, 200 ether);

        assertEq(token.balanceOf(liquidator), 200 ether);
        assertEq(token.balanceOf(user), 800 ether);
    }

    function testLiquidationWindowExpiry() public {
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation
        vm.prank(liquidator);
        token.initiateLiquidation(user);

        // Advance past cooldown + window (10 + 5 + 1 = 16 blocks)
        vm.roll(block.number + 16);

        // Window expired
        vm.prank(liquidator);
        vm.expectRevert("CircuitBreaker: liquidation window expired");
        token.transferFrom(user, liquidator, 200 ether);

        // Must re-initiate
        vm.prank(liquidator);
        token.initiateLiquidation(user);

        // Advance to valid window
        vm.roll(block.number + 11);

        // Now succeeds
        vm.prank(liquidator);
        token.transferFrom(user, liquidator, 200 ether);

        assertEq(token.balanceOf(liquidator), 200 ether);
    }

    function testPositionBecomesHealthyDuringCooldown() public {
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation
        vm.prank(liquidator);
        token.initiateLiquidation(user);

        // User adds more collateral, position becomes healthy again
        protocol.setHealthFactor(user, 1.5e18);

        // Advance past cooldown
        vm.roll(block.number + 11);

        // Liquidation still proceeds (cooldown was already initiated)
        // In a real protocol, you might want to cancel this
        vm.prank(liquidator);
        token.transferFrom(user, liquidator, 200 ether);

        assertEq(token.balanceOf(liquidator), 200 ether);
    }

    function testMultipleLiquidators() public {
        address liquidator2 = address(0x3);
        
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.5e18);

        // First liquidator initiates
        vm.prank(liquidator);
        token.initiateLiquidation(user);

        // Second liquidator cannot re-initiate
        vm.prank(liquidator2);
        vm.expectRevert("Liquidation already initiated");
        token.initiateLiquidation(user);

        // Advance past cooldown
        vm.roll(block.number + 11);

        // Any liquidator can execute (first come, first served)
        vm.prank(liquidator2);
        token.transferFrom(user, liquidator2, 200 ether);

        assertEq(token.balanceOf(liquidator2), 200 ether);
        assertEq(token.balanceOf(liquidator), 0);
    }

    function testUserDepositsWorkDuringCooldown() public {
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation directly on token
        vm.prank(liquidator);
        token.initiateLiquidation(user);

        // User can still make deposits in a different transaction
        vm.roll(block.number + 1);
        
        address receiver = address(0x4);
        vm.startPrank(user);
        token.approve(receiver, 100 ether);
        vm.stopPrank();

        // Same block deposit should work
        vm.prank(receiver);
        token.transferFrom(user, receiver, 50 ether);

        assertEq(token.balanceOf(receiver), 50 ether);
    }
}
