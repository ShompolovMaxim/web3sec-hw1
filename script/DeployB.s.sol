// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BridgeToken.sol";
import "../src/Bridge.sol";

contract DeployBScript is Script {
    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        uint256 chainId = block.chainid;
        
        console.log("Deploying on chain:", chainId);
        console.log("Deployer:", deployer);

        BridgeToken tokenB = new BridgeToken("TokenB", "TKB", deployer);
        Bridge bridgeB = new Bridge(address(tokenB), chainId, deployer);

        tokenB.grantRole(tokenB.MINTER_ROLE(), address(bridgeB));
        tokenB.grantRole(tokenB.BURNER_ROLE(), address(bridgeB));
        tokenB.grantRole(tokenB.MINTER_ROLE(), deployer);

        console.log("TokenB:", address(tokenB));
        console.log("BridgeB:", address(bridgeB));

        vm.stopBroadcast();
    }
}

