// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { AccessProtected } from "./utils/AccessProtected.sol";

contract PolygonVoxel is AccessProtected, ERC20Burnable {
    event Bridge(address indexed user, uint256 amount);

    constructor() ERC20("Voxel Token", "VXL") {}

    function mint(address _to, uint256 _amount) external onlyAdmin {
        _mint(_to, _amount);
    }

    /**
     * Bridge
     * Only admin
     * @dev listen for `Bridge` event and `mint` on other side
     */
    function bridge(uint256 _amount) external onlyAdmin {
        burn(_amount);
        emit Bridge(_msgSender(), _amount);
    }
}
