// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessProtected } from "./utils/AccessProtected.sol";

contract Voxel is AccessProtected, ERC20("Voxel Token", "VXL") {
    function mint(address _to, uint256 _amount) external onlyAdmin {
        _mint(_to, _amount);
    }
}
