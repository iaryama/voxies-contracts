// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract PolygonVoxel is Ownable, ERC20("Voxel Token", "VXL") {
    address private _childChainManagerProxy;

    constructor(address childChainManagerProxy_) {
        _childChainManagerProxy = childChainManagerProxy_;
    }

    function deposit(address _to, bytes calldata _data) external {
        require(_msgSender() == _childChainManagerProxy, "caller != childChainManagerProxy");
        uint256 amount = abi.decode(_data, (uint256));
        _mint(_to, amount);
    }

    function withdraw(uint256 _amount) external {
        _burn(_msgSender(), _amount);
    }

    function updateChildChainManagerProxy(address _newAddr) external onlyOwner {
        _childChainManagerProxy = _newAddr;
    }
}
