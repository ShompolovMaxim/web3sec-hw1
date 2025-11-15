// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BridgeToken.sol";

contract MintTokensScript is Script {
    function run() external {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address recipient = vm.envAddress("RECIPIENT");
        uint256 amount = vm.envUint("AMOUNT");

        vm.startBroadcast();

        BridgeToken token = BridgeToken(tokenAddress);
        
        console.log("Token:", tokenAddress);
        console.log("Recipient:", recipient);
        console.log("Amount:", amount);

        token.mint(recipient, amount);

        console.log("Recipient balance:", token.balanceOf(recipient));

        vm.stopBroadcast();
    }
}
