// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BridgeToken.sol";
import "../src/Bridge.sol";

contract TestDepositScript is Script {
    function run() external {
        address user = msg.sender;
        
        address bridge = vm.envAddress("BRIDGE_ADDRESS");
        address token = vm.envAddress("TOKEN_ADDRESS");
        uint256 targetChainId = vm.envUint("TARGET_CHAIN_ID");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 nonce = vm.envUint("NONCE");
        address toAddress = vm.envAddress("TO_ADDRESS");

        vm.startBroadcast();

        BridgeToken tokenContract = BridgeToken(token);
        Bridge bridgeContract = Bridge(bridge);

        console.log("User:", user);
        console.log("Bridge:", bridge);
        console.log("Token:", token);
        console.log("Amount:", amount);
        console.log("Nonce:", nonce);
        console.log("Target Chain ID:", targetChainId);
        console.log("Current Chain ID:", block.chainid);

        uint256 balanceBefore = tokenContract.balanceOf(user);
        uint256 supplyBefore = tokenContract.totalSupply();

        console.log("User balance before:", balanceBefore);
        console.log("Total supply before:", supplyBefore);

        tokenContract.approve(bridge, amount);

        bridgeContract.deposit(targetChainId, toAddress, amount, nonce);

        uint256 balanceAfter = tokenContract.balanceOf(user);
        uint256 supplyAfter = tokenContract.totalSupply();

        console.log("User balance after:", balanceAfter);
        console.log("Total supply after:", supplyAfter);
        console.log("Deposit event emitted with nonce:", nonce);
        console.log("Relay will mint on chain", targetChainId);

        vm.stopBroadcast();
    }
}
