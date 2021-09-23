// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { Whitelist } from "./utils/Whitelist.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// @todo: owners cut?
// @todo: multiple rounds?
// @todo: soft cap? hard cap?

contract VoxelDistribution is Whitelist, Pausable {
    uint256 public minimumBuyAmount = 1 ether;
    uint256 public price = 1e16; // 1 matic = 100 tokens
    IERC20 public token;

    event Buy(address indexed investor, uint256 amount);

    constructor(IERC20 _token) {
        require(address(_token) != address(0), "ZERO_ADDRESS");
        token = _token;
    }

    /**
     * @notice buy the token
     */
    function buy() public payable onlyWhitelist whenNotPaused {
        require(msg.value >= minimumBuyAmount, "amount should be greater than minimum requirement");
        uint256 tokensToSend = (msg.value * 1e18) / price;
        token.transfer(msg.sender, tokensToSend);
        emit Buy(msg.sender, msg.value);
    }

    /// @notice fallback for buy()
    receive() external payable {
        buy();
    }

    /**
     * @notice Set price
     * Only admin
     */
    function setMinimumBuyAmount(uint256 _minAmount) external onlyAdmin {
        minimumBuyAmount = _minAmount;
    }

    /**
     * @notice Set min buy amount
     * Only admin
     */
    function setPrice(uint256 _price) external onlyAdmin {
        price = _price;
    }

    /**
     * @notice withdraw accumulated funds in this contract
     * Can only be called by the current owner.
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @notice get balance of funds in this contract
     */
    function getBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    //
    //  PAUSABLE IMPLEMENTATION
    //
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
