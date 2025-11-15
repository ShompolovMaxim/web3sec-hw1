// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BridgeToken.sol";
import "../src/Bridge.sol";

contract BridgeTest is Test {
    BridgeToken public tokenA;
    BridgeToken public tokenB;
    Bridge public bridgeA;
    Bridge public bridgeB;
    address public user;

    event Deposit(address indexed from, uint256 indexed toChainId, address indexed to, uint256 amount, uint256 nonce);
    event Minted(address indexed to, uint256 amount, uint256 nonce);

    function setUp() public {
        user = vm.addr(1);

        tokenA = new BridgeToken("TokenA", "TKA", address(this));
        tokenB = new BridgeToken("TokenB", "TKB", address(this));

        bridgeA = new Bridge(address(tokenA), 1, address(this));
        bridgeB = new Bridge(address(tokenB), 2, address(this));

        tokenA.grantRole(tokenA.MINTER_ROLE(), address(bridgeA));
        tokenA.grantRole(tokenA.BURNER_ROLE(), address(bridgeA));
        tokenB.grantRole(tokenB.MINTER_ROLE(), address(bridgeB));
        tokenB.grantRole(tokenB.BURNER_ROLE(), address(bridgeB));

        vm.prank(address(bridgeA));
        tokenA.mint(user, 1000);
    }  

    function testDeposit() public {
        vm.startPrank(user);
        tokenA.approve(address(bridgeA), 500);

        vm.expectEmit(true, true, true, true, address(bridgeA));
        emit Deposit(user, 2, user, 500, 1);

        bridgeA.deposit(2, user, 500, 1);

        assertEq(tokenA.balanceOf(user), 500);
        assertEq(tokenA.balanceOf(address(bridgeA)), 0);
        vm.stopPrank();
    }

    function testReceiveFromOtherChain() public {
        uint256 initial = tokenB.balanceOf(user);

        vm.expectEmit(true, true, true, true, address(bridgeB));
        emit Minted(user, 300, 7);

        bridgeB.receiveFromOtherChain(user, 300, 7);

        assertEq(tokenB.balanceOf(user), initial + 300);
    }

    function testCrossChainPipeline() public {
        uint256 transferAmount = 150;
        uint256 initialTotalOnA = tokenA.totalSupply();
        uint256 initialTotalOnB = tokenB.totalSupply();

        vm.prank(user);
        tokenA.approve(address(bridgeA), transferAmount);
        vm.expectEmit(true, true, true, true, address(bridgeA));
        emit Deposit(user, 2, user, transferAmount, 30);
        vm.prank(user);
        bridgeA.deposit(2, user, transferAmount, 30);

        vm.expectEmit(true, true, true, true, address(bridgeB));
        emit Minted(user, transferAmount, 30);
        bridgeB.receiveFromOtherChain(user, transferAmount, 30);

        assertEq(tokenA.balanceOf(user), 1000 - transferAmount);
        assertEq(tokenA.balanceOf(address(bridgeA)), 0);
        assertEq(tokenB.balanceOf(user), transferAmount);
        assertEq(tokenB.balanceOf(address(bridgeB)), 0);

        assertEq(tokenA.totalSupply(), initialTotalOnA - transferAmount);
        assertEq(tokenB.totalSupply(), initialTotalOnB + transferAmount);
    }

    function testNonceRestrictions() public {
        vm.prank(user);
        tokenA.approve(address(bridgeA), 500);
        vm.prank(user);
        bridgeA.deposit(2, user, 500, 1);

        vm.prank(user);
        tokenA.approve(address(bridgeA), 100);
        vm.prank(user);
        vm.expectRevert("Nonce already used");
        bridgeA.deposit(2, user, 100, 1);

        vm.expectRevert("Nonce already processed");
        bridgeA.receiveFromOtherChain(user, 100, 1);
    }

    function test2Nonces() public {
        vm.prank(user);
        tokenA.approve(address(bridgeA), 1000);
        
        vm.prank(user);
        bridgeA.deposit(2, user, 100, 1);
        
        vm.prank(user);
        bridgeA.deposit(2, user, 200, 2);
        

        assertEq(tokenA.balanceOf(user), 700);
        assertEq(tokenA.totalSupply(), 700);
    }

    function testAccess() public {
        vm.prank(user);
        vm.expectRevert();
        bridgeA.receiveFromOtherChain(user, 300, 2);

        vm.expectRevert();
        tokenA.mint(user, 1000);

        vm.expectRevert();
        tokenA.burn(user, 1000);
    }
}
