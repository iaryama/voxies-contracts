// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoxiesNFTEngine is ERC721URIStorage, Ownable {
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
     * Throws if called by any account other than the Admin.
     */
    modifier onlyAdmin() {
        require(_admins[msg.sender] || msg.sender == owner(), "Caller does not have Admin Access");
        _;
    }
}
