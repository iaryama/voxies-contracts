// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721 {
    uint256 count;

    constructor(uint256 _amount) ERC721("Non fungible token", "NFT") {
        for (uint256 i = 0; i < _amount; i++) {
            count++;
            _mint(msg.sender, count);
        }
    }
}
