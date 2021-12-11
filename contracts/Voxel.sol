// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Voxel is Ownable, ERC20 {
    constructor(
        uint256 _initialSupply,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        _mint(_msgSender(), _initialSupply * (1e18));
    }
}
