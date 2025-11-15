// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BridgeToken.sol";

contract CheckBalanceScript is Script {
    function run() external view {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address account = vm.envAddress("ACCOUNT");

        BridgeToken token = BridgeToken(tokenAddress);

        console.log("Token:", tokenAddress);
        console.log("Account:", account);
        console.log("Account balance:", token.balanceOf(account));
    }
}
