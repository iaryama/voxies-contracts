// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Voxel is Ownable, ERC20("Voxel Token", "VXL") {
    constructor() {
        _mint(_msgSender(), 1000000 ether); // 1 mil
    }
}
