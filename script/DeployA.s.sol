// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BridgeToken.sol";
import "../src/Bridge.sol";

contract DeployAScript is Script {
    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        uint256 chainId = block.chainid;
        
        console.log("Deploying on chain:", chainId);
        console.log("Deployer:", deployer);

        BridgeToken tokenA = new BridgeToken("TokenA", "TKA", deployer);
        Bridge bridgeA = new Bridge(address(tokenA), chainId, deployer);

        tokenA.grantRole(tokenA.MINTER_ROLE(), address(bridgeA));
        tokenA.grantRole(tokenA.BURNER_ROLE(), address(bridgeA));
        tokenA.grantRole(tokenA.MINTER_ROLE(), deployer);

        console.log("TokenA:", address(tokenA));
        console.log("BridgeA:", address(bridgeA));

        vm.stopBroadcast();
    }
}

