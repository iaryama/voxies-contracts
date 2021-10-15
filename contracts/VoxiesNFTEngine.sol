// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract VoxiesNFTEngine is ERC721URIStorage, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;
    mapping(address => bool) private _admins;

    event AdminAccessSet(address _admin, bool _enabled);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    /**
     * Set Admin Access
     *
     * @param admin - Address of Minter
     * @param enabled - Enable/Disable Admin Access
     */
    function setAdmin(address admin, bool enabled) external onlyOwner {
        _admins[admin] = enabled;
        emit AdminAccessSet(admin, enabled);
    }

    /**
     * Check Admin Access
     *
     * @param admin - Address of Admin
     * @return whether minter has access
     */
    function isAdmin(address admin) public view returns (bool) {
        return _admins[admin];
    }

    /**
     * Mint + Issue NFT
     *
     * @param recipient - NFT will be issued to recipient
     * @param hash - Artwork Metadata IPFS hash
     * @param data - Artwork Metadata URI/Data
     */
    function issueToken(
        address recipient,
        string memory hash,
        string memory data
    ) public onlyAdmin returns (uint256) {
        require(hashes[hash] != 1, "NFT for hash already minted");
        hashes[hash] = 1;
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, data);
        return newTokenId;
    }

    /**
     * Batch Mint
     *
     * @param recipient - NFT will be issued to recipient
     * @param _hashes - array of Artwork Metadata IPFS hash
     * @param _URIs - array of Artwork Metadata URI/Data
     */
    function issueBatch(
        address recipient,
        string[] memory _hashes,
        string[] memory _URIs
    ) public onlyAdmin returns (uint256[] memory) {
        require(_hashes.length == _URIs.length, "Hashes & URIs length mismatch");
        uint256[] memory tokenIds = new uint256[](_hashes.length);
        for (uint256 i = 0; i < _hashes.length; i++) {
            string memory hash = _hashes[i];
            string memory data = _URIs[i];
            uint256 tokenId = issueToken(recipient, hash, data);
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
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

    /**
     * Throws if called by any account other than the Admin.
     */
    modifier onlyAdmin() {
        require(_admins[msg.sender] || msg.sender == owner(), "Caller does not have Admin Access");
        _;
    }
}
