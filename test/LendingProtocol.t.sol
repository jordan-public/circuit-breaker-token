// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CircuitBreakerToken.sol";
import "../src/LendingProtocol.sol";

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

contract LendingProtocolTest is Test {
    CircuitBreakerToken cWBTC;  // Example: wrapping WETH
    MockERC20 underlying;
    LendingProtocol protocol;
    address user = address(0x1);
    address liquidator = address(0x2);

    function setUp() public {
        // Deploy protocol first (with temporary token address)
        protocol = new LendingProtocol(address(0x1));
        
        // Deploy underlying token and circuit breaker token
        underlying = new MockERC20("Wrapped Bitcoin", "WBTC");
        cWBTC = new CircuitBreakerToken(
            "Circuit Breaker WBTC",
            "cWBTC",
            address(underlying),
            10,  // 10 block cooldown
            5,   // 5 block window
            address(protocol)
        );

        // Mint underlying to user and have them deposit
        underlying.mint(user, 1000 ether);
        vm.startPrank(user);
        underlying.approve(address(cWBTC), 1000 ether);
        cWBTC.deposit(1000 ether);
        vm.stopPrank();
        
        // Set collateral amount for user (representing their position in the protocol)
        // In a real protocol, this would be tracked when they deposit
        protocol.setCollateral(user, 1000 ether);
        
        // User approves liquidators to manage their tokens
        vm.startPrank(user);
        cWBTC.approve(liquidator, type(uint256).max);
        cWBTC.approve(address(0x3), type(uint256).max); // liquidator2
        vm.stopPrank();
        
        // Advance a block so approvals aren't in the same block as liquidations
        vm.roll(block.number + 1);
    }

    function testHealthyPositionCannotBeLiquidated() public {
        // User has healthy position (health factor = 150%)
        protocol.setHealthFactor(user, 1.5e18);

        // Cannot initiate liquidation directly on token
        vm.expectRevert("Position not liquidatable");
        cWBTC.initiateLiquidation(user);
    }

    function testUnhealthyPositionCanBeLiquidated() public {
        // User's position becomes unhealthy (health factor = 80%)
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation directly on token (protocol's canLiquidate will be called)
        vm.prank(liquidator);
        cWBTC.initiateLiquidation(user);

        // Cannot liquidate immediately (in cooldown)
        vm.prank(liquidator);
        vm.expectRevert("CircuitBreaker: liquidation in cooldown");
        cWBTC.transferFrom(user, liquidator, 200 ether);

        // Advance past cooldown to start of window (10 blocks)
        vm.roll(block.number + 10);
        
        // At block 0 of window, only 10% can be liquidated (100 ether)
        (uint256 pct, uint256 amt) = cWBTC.getLiquidatableAmount(user);
        assertEq(pct, 10);
        assertEq(amt, 100 ether);
        
        // Trying to liquidate 200 ether should fail
        vm.prank(liquidator);
        vm.expectRevert("CircuitBreaker: exceeds liquidatable amount");
        cWBTC.transferFrom(user, liquidator, 200 ether);
        
        // Liquidate the allowed 100 ether
        vm.prank(liquidator);
        cWBTC.transferFrom(user, liquidator, 100 ether);

        assertEq(cWBTC.balanceOf(liquidator), 100 ether);
    }

    function testLiquidationWindowExpiry() public {
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation
        vm.prank(liquidator);
        cWBTC.initiateLiquidation(user);

        // Advance past cooldown + window (10 + 5 + 1 = 16 blocks)
        vm.roll(block.number + 16);

        // Window expired
        vm.prank(liquidator);
        vm.expectRevert("CircuitBreaker: liquidation window expired");
        cWBTC.transferFrom(user, liquidator, 200 ether);

        // Must re-initiate
        vm.prank(liquidator);
        cWBTC.initiateLiquidation(user);

        // Advance to valid window
        vm.roll(block.number + 11);

        // Now succeeds
        vm.prank(liquidator);
        cWBTC.transferFrom(user, liquidator, 200 ether);

        assertEq(cWBTC.balanceOf(liquidator), 200 ether);
    }

    function testPositionBecomesHealthyDuringCooldown() public {
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation
        vm.prank(liquidator);
        cWBTC.initiateLiquidation(user);

        // User adds more collateral, position becomes healthy again
        protocol.setHealthFactor(user, 1.5e18);

        // Advance past cooldown
        vm.roll(block.number + 11);

        // Liquidation still proceeds (cooldown was already initiated)
        // In a real protocol, you might want to cancel this
        vm.prank(liquidator);
        cWBTC.transferFrom(user, liquidator, 200 ether);

        assertEq(cWBTC.balanceOf(liquidator), 200 ether);
    }

    function testMultipleLiquidators() public {
        address liquidator2 = address(0x3);
        
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.5e18);

        // First liquidator initiates
        vm.prank(liquidator);
        cWBTC.initiateLiquidation(user);

        // Second liquidator cannot re-initiate
        vm.prank(liquidator2);
        vm.expectRevert("Liquidation already initiated");
        cWBTC.initiateLiquidation(user);

        // Advance past cooldown
        vm.roll(block.number + 11);

        // Any liquidator can execute (first come, first served)
        vm.prank(liquidator2);
        cWBTC.transferFrom(user, liquidator2, 200 ether);

        assertEq(cWBTC.balanceOf(liquidator2), 200 ether);
        assertEq(cWBTC.balanceOf(liquidator), 0);
    }

    function testUserDepositsWorkDuringCooldown() public {
        // User's position becomes unhealthy
        protocol.setHealthFactor(user, 0.8e18);

        // Initiate liquidation directly on token
        vm.prank(liquidator);
        cWBTC.initiateLiquidation(user);

        // User can still make deposits in a different transaction
        vm.roll(block.number + 1);
        
        address receiver = address(0x4);
        vm.startPrank(user);
        cWBTC.approve(receiver, 100 ether);
        vm.stopPrank();

        // Same block deposit should work
        vm.prank(receiver);
        cWBTC.transferFrom(user, receiver, 50 ether);

        assertEq(cWBTC.balanceOf(receiver), 50 ether);
    }
}
