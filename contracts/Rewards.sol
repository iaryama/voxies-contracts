// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

contract Rewards is Ownable {
    event RewardedERC20(address indexed token, address[] indexed winners, uint256[] amounts);
    event RewardedNFT(address indexed nft, address[] indexed winners, uint256[] amounts);
    event DepositedERC20(address indexed depositor, address indexed token, uint256 amount);
    event DepositedNFT(address indexed depositor, address indexed nft, uint256[] tokenIds);
    event WithdrawnERC20(address indexed token, address indexed caller, uint256 amount);
    event WithdrawnNFT(address indexed nft, address indexed caller, uint256[] tokenIds);

    function depositERC20(address _token, uint256 _amount) external onlyOwner {
        require(_amount > 0, "amount == 0");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        emit DepositedERC20(msg.sender, _token, _amount);
    }

    function depositNFTs(address _nft, uint256[] memory _tokenIds) external onlyOwner {
        uint256 len = _tokenIds.length;
        require(len > 0, "tokenIds length == 0");

        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = _tokenIds[i];
            IERC721(_nft).transferFrom(msg.sender, address(this), tokenId);
        }

        emit DepositedNFT(msg.sender, _nft, _tokenIds);
    }

    function rewardinERC20(
        address _token,
        address[] memory _winners,
        uint256[] memory _amounts
    ) external onlyOwner {
        require(_winners.length == _amounts.length, "winners.length != _amounts.length");
        uint256 len = _winners.length;
        for (uint256 i = 0; i < len; i++) {
            address winner = _winners[i];
            uint256 amount = _amounts[i];
            IERC20(_token).transfer(winner, amount);
        }
        emit RewardedERC20(address(_token), _winners, _amounts);
    }

    function rewardinNFTs(
        address _token,
        address[] memory _winners,
        uint256[] memory _tokenIds
    ) external onlyOwner {
        require(_winners.length == _tokenIds.length, "winners.length != _tokenIds.length");
        uint256 len = _winners.length;
        for (uint256 i = 0; i < len; i++) {
            address winner = _winners[i];
            uint256 tokenId = _tokenIds[i];
            IERC721(_token).transferFrom(address(this), winner, tokenId);
        }
        emit RewardedNFT(address(_token), _winners, _tokenIds);
    }

    function getERC20Balance(address _token) public view onlyOwner returns (uint256) {
        return IERC20(_token).balanceOf((address(this)));
    }

    function getNFTBalance(address _token) public view onlyOwner returns (uint256) {
        return IERC721(_token).balanceOf((address(this)));
    }

    function withdrawERC20(address _token) external onlyOwner {
        uint256 balance = getERC20Balance(_token);
        IERC20(_token).transfer(owner(), balance);
    }

    function withdrawNFTs(address _token, uint256[] memory _tokenIds) external onlyOwner {
        uint256 len = _tokenIds.length;
        require(len > 0, "tokenIds length == 0");
        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = _tokenIds[i];
            IERC721(_token).transferFrom(address(this), owner(), tokenId);
        }
    }
}
