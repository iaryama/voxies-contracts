// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/EIP712Base.sol";
import "./utils/BaseRelayRecipient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTSale is Ownable, IERC721Receiver, ReentrancyGuard, EIP712Base, BaseRelayRecipient {
    using Address for address;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    IERC20 public immutable voxel;
    bool public isActive;

    bytes32 private constant OFFER_TYPEHASH = keccak256(bytes("Offer(address buyer,uint256 price,uint256 listingId)"));

    struct Listing {
        uint256 listingId;
        uint256 nftCount;
        address[] nftAddresses;
        uint256[] tokenIDs;
        uint256 price;
        address owner;
        bool isActive;
        bool isSold;
    }

    struct Offer {
        address buyer;
        uint256 price;
        uint256 listingId;
    }

    Counters.Counter public _listingIds;

    mapping(address => mapping(uint256 => uint256)) private _nftToListingId; // NFT contract Address -> TokenID -> ListingId
    mapping(address => bool) public allowedNFTAddresses;

    // user address => admin? mapping
    mapping(address => bool) private _admins;
    mapping(uint256 => Listing) public listings;

    event ContractStatusSet(address indexed _admin, bool indexed _isActive);
    event AdminAccessSet(address indexed _admin, bool indexed _enabled);
    event ListingAdded(uint256 indexed _listingId, uint256 indexed _price, address indexed _owner, uint256 _timestamp);
    event ListingCancelled(uint256 indexed _listingId, address indexed _owner, uint256 _timestamp);
    event Sold(
        uint256 indexed _listingId,
        address indexed _seller,
        address indexed _buyer,
        uint256 _price,
        uint256 _timestamp
    );

    constructor(IERC20 _voxel) {
        _initializeEIP712("NFTSale", "1");
        voxel = _voxel;
    }

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
     * Enable/Disable Contract
     *
     * @param _isActive - Enable/Disable Contract
     */
    function setContractStatus(bool _isActive) external onlyAdmin {
        isActive = _isActive;
        emit ContractStatusSet(_msgSender(), _isActive);
    }

    /**
     * Sell NFT Bundle
     *
     * @param _nftAddresses - Addresses of the NFTs to be bundled
     * @param _nftIds - Token IDs of the NFTs to be bundled
     * @param price - price to sell NFT for
     */
    function sellNFTBundle(
        address[] calldata _nftAddresses,
        uint256[] calldata _nftIds,
        uint256 price
    ) external nonReentrant {
        require(isActive, "Contract Status in not Active");
        require(_nftAddresses.length == _nftIds.length, "call data not of same length");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(allowedNFTAddresses[_nftAddresses[i]], "NFT contract address is not allowed");
            require(
                _nftToListingId[_nftAddresses[i]][_nftIds[i]] == 0,
                "A listed Bundle exists with one of the given NFT"
            );
            address nftOwner = IERC721(_nftAddresses[i]).ownerOf(_nftIds[i]);
            require(_msgSender() == nftOwner, "Not owner of one or more NFTs");
        }
        _listingIds.increment();
        uint256 listingId = _listingIds.current();

        for (uint256 i = 0; i < _nftIds.length; i++) {
            _nftToListingId[_nftAddresses[i]][_nftIds[i]] = listingId;
            IERC721(_nftAddresses[i]).transferFrom(_msgSender(), address(this), _nftIds[i]);
        }
        Listing memory listing = Listing(
            listingId,
            _nftAddresses.length,
            _nftAddresses,
            _nftIds,
            price,
            _msgSender(),
            true,
            false
        );
        listings[listingId] = listing;
        emit ListingAdded(listingId, price, _msgSender(), block.timestamp);
    }

    /**
     * Get NFT Sale Listing
     *
     * @param _listingId - id of the NFT Bundle
     */
    function getListing(uint256 _listingId) external view returns (address[] memory, uint256[] memory) {
        return (listings[_listingId].nftAddresses, listings[_listingId].tokenIDs);
    }

    /**
     * Cancel NFT Sale
     *
     * @param _listingId - id of the NFT Bundle
     */
    function cancelListingBundle(uint256 _listingId) external nonReentrant {
        require(isActive, "Contract Status in not Active");
        require(listings[_listingId].isActive, "Listing is already inactive");
        require(listings[_listingId].owner == _msgSender(), "You are not the owner of this listing");
        listings[_listingId].isActive = false;
        uint256[] memory _nftIds = listings[_listingId].tokenIDs;
        address[] memory _nftAddresses = listings[_listingId].nftAddresses;
        for (uint256 i = 0; i < _nftIds.length; i++) {
            _nftToListingId[_nftAddresses[i]][_nftIds[i]] = 0;
            IERC721(_nftAddresses[i]).transferFrom(address(this), listings[_listingId].owner, _nftIds[i]);
        }
        emit ListingCancelled(_listingId, _msgSender(), block.timestamp);
    }

    /**
     * Purchase NFT Internal
     *
     * @param _listingId - id of the NFT Bundle
     */
    function purchaseNFT(uint256 _listingId, uint256 _amount) external nonReentrant {
        require(isActive, "Sale Contract Status in not Active");
        require(_amount == listings[_listingId].price, "value not equal to price of nft");
        require(!listings[_listingId].isSold, "Listing is already sold");
        require(listings[_listingId].isActive, "Listing is inactive");
        address seller = listings[_listingId].owner;
        address buyer = (_msgSender());
        uint256 price = listings[_listingId].price;
        listings[_listingId].isSold = true;
        listings[_listingId].isActive = false;
        uint256[] memory _nftIds = listings[_listingId].tokenIDs;
        address[] memory _nftAddresses = listings[_listingId].nftAddresses;

        // Transfer the Voxel Tokens
        voxel.safeTransferFrom(buyer, seller, price);

        // Transfer the NFTs to the buyer
        for (uint256 i = 0; i < _nftIds.length; i++) {
            _nftToListingId[_nftAddresses[i]][_nftIds[i]] = 0;
            IERC721(_nftAddresses[i]).transferFrom(address(this), buyer, _nftIds[i]);
        }
        emit Sold(_listingId, seller, buyer, price, block.timestamp);
    }

    function hashOffer(Offer memory offer) internal pure returns (bytes32) {
        return keccak256(abi.encode(OFFER_TYPEHASH, offer.buyer, offer.price, offer.listingId));
    }

    function verify(
        address signer,
        Offer memory offer,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
        return signer == ecrecover(toTypedMessageHash(hashOffer(offer)), sigV, sigR, sigS);
    }

    function acceptOffer(
        address offerSender,
        uint256 amount,
        uint256 listingId,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) external {
        Offer memory offer = Offer({ buyer: offerSender, price: amount, listingId: listingId });
        require(verify(offerSender, offer, sigR, sigS, sigV), "Signer and signature do not match");
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * Throws if called by any account other than the Admin.
     */
    modifier onlyAdmin() {
        require(_admins[_msgSender()] || _msgSender() == owner(), "Caller does not have Admin Access");
        _;
    }

    function setTrustedForwarder(address _trustedForwarder) external onlyAdmin {
        trustedForwarder = _trustedForwarder;
    }

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address) {
        return BaseRelayRecipient._msgSender();
    }
}
