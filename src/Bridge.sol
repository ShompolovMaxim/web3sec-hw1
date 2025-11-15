// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BridgeToken.sol";

contract Bridge is Ownable {
    BridgeToken public token;
    uint256 public immutable chainId;

    mapping(uint256 => bool) public processedNonces;

    event Deposit(
        address indexed from,
        uint256 indexed toChainId,
        address indexed to,
        uint256 amount,
        uint256 nonce
    );

    event Minted(address indexed to, uint256 amount, uint256 nonce);

    constructor(address tokenAddress, uint256 _chainId, address owner) Ownable(owner) {
        token = BridgeToken(tokenAddress);
        chainId = _chainId;
    }

    function deposit(uint256 toChainId, address to, uint256 amount, uint256 nonce) external {
        require(!processedNonces[nonce], "Nonce already used");
        processedNonces[nonce] = true;

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        token.burn(address(this), amount);

        emit Deposit(msg.sender, toChainId, to, amount, nonce);
    }

    function receiveFromOtherChain(
        address to,
        uint256 amount,
        uint256 nonce
    ) external onlyOwner {
        require(!processedNonces[nonce], "Nonce already processed");
        processedNonces[nonce] = true;

        token.mint(to, amount);
        emit Minted(to, amount, nonce);
    }
}
