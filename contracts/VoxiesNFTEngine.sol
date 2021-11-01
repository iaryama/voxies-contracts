// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./utils/AccessProtected.sol";

contract VoxiesNFTEngine is ERC721URIStorage, ERC721Enumerable, AccessProtected {
    using Counters for Counters.Counter;
    using Address for address;
    Counters.Counter public _tokenIds;
    mapping(string => bool) public hashes;
    mapping(address => bool) public whitelistedAddresses;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    /**
     * Mint + Issue NFT
     *
     * @param recipient - NFT will be issued to recipient
     * @param hash - Artwork Metadata IPFS hash
     */
    function issueToken(address recipient, string memory hash) public onlyAdmin returns (uint256) {
        require(hashes[hash] == false, "NFT for hash already minted");
        hashes[hash] = true;
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, hash);
        return newTokenId;
    }

    /**
     * Batch Mint
     *
     * @param recipient - NFT will be issued to recipient
     * @param _hashes - array of Artwork Metadata IPFS hash
     */
    function issueBatch(address recipient, string[] memory _hashes) public onlyAdmin returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](_hashes.length);
        for (uint256 i = 0; i < _hashes.length; i++) {
            uint256 tokenId = issueToken(recipient, _hashes[i]);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }

    /**
     * Get Holder Token IDs
     *
     * @param holder - Holder of the Tokens
     */
    function getHolderTokenIds(address holder) public view returns (uint256[] memory) {
        uint256 count = balanceOf(holder);
        uint256[] memory result = new uint256[](count);
        uint256 index;
        for (index = 0; index < count; index++) {
            result[index] = tokenOfOwnerByIndex(holder, index);
        }
        return result;
    }

    /**
     * Burn NFT
     *
     * @param tokenId - NFT Id to Burn
     */
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * Add contract addresses to the whitelist
     */

    function addToWhitelist(address _contractAddress) external onlyAdmin {
        require(_contractAddress.isContract(), "Provided Address is not a contract");
        whitelistedAddresses[_contractAddress] = true;
    }

    /**
     * Remove a contract addresses from the whitelist
     */

    function removeFromWhitelist(address _contractAddress) external onlyAdmin {
        require(_contractAddress.isContract(), "Provided Address is not a contract");
        whitelistedAddresses[_contractAddress] = false;
    }

    /**
     * Get the whitelisted status of a contract
     */

    function getWhitelistStatus(address _contractAddress) external view onlyAdmin returns (bool) {
        require(_contractAddress.isContract(), "Provided Address is not a contract");
        return whitelistedAddresses[_contractAddress];
    }

    /**
     * Override transfer functionality
     */

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721) {
        if (to.isContract()) {
            require(whitelistedAddresses[to], "Contract Address is not whitelisted");
        }
        super._transfer(from, to, tokenId);
    }

    /**
     * returns the message sender
     */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}
