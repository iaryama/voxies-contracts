// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/EIP712Base.sol";

interface INFTEngine {
    function creatorOfNft(uint256 creator) external view returns (address);
}

// NFTSale SMART CONTRACT
contract NFTSale is OwnableUpgradeable, IERC721Receiver, ReentrancyGuard, EIP712Base {
    using Address for address;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    IERC20 public immutable voxel;

    address public immutable nftAddress;
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
        bool isCancelled;
    }

    struct Sale {
        uint256 nftId;
        uint256 price;
        address owner;
        bool isActive;
        bool isCancelled;
    }

    struct Offer {
        address buyer;
        uint256 price;
        uint256 listingId;
    }

    Counters.Counter public _listingIds;

    // nftId => Sale mapping
    mapping(uint256 => Sale) public _nftSales;
    // user address => admin? mapping
    mapping(address => bool) private _admins;

    event ContractStatusSet(address indexed _admin, bool indexed _isActive);
    event AdminAccessSet(address indexed _admin, bool indexed _enabled);
    event SaleAdded(uint256 indexed _nftId, uint256 indexed _price, address indexed _owner, uint256 _timestamp);
    event SaleCancelled(
        uint256 indexed _nftId,
        uint256 _price,
        address indexed _owner,
        address _cancelledBy,
        uint256 _timestamp
    );
    event Sold(
        uint256 indexed _nftId,
        address indexed _seller,
        address indexed _buyer,
        uint256 _price,
        uint256 _timestamp
    );

    constructor(address _nftAddress, IERC20 _voxel) {
        require(_nftAddress.isContract(), "_nftAddress must be a contract");
        __Ownable_init();
        _initializeEIP712("NFTSale", "1");
        nftAddress = _nftAddress;
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
     * Sell NFT Transfer Logic
     *
     * @param nftId - nftId of the NFT
     * @param price - price to sell NFT for
     * @param artist - artist or original owner of NFT
     * @param nftOwner - Owner of nft on the blockchain contract
     */
    function _sellNFT(
        uint256 nftId,
        uint256 price,
        address artist,
        address nftOwner
    ) private nonReentrant {
        require(!_nftSales[nftId].isActive, "NFT Sale is active");
        Sale memory sale = Sale(nftId, price, artist, true, false);
        _nftSales[nftId] = sale;
        IERC721(nftAddress).safeTransferFrom(nftOwner, address(this), nftId);
        emit SaleAdded(nftId, price, artist, block.timestamp);
    }

    /**
     * Put up NFT for Sale
     *
     * @param nftId - nftId of the NFT
     * @param price - price to sell NFT for
     * @param artist - artist or original owner of NFT
     */
    function sellNFT(
        uint256 nftId,
        uint256 price,
        address artist
    ) external onlyAdmin {
        address nftOwner = IERC721(nftAddress).ownerOf(nftId);
        require(
            IERC721(nftAddress).getApproved(nftId) == address(this) ||
                IERC721(nftAddress).isApprovedForAll(nftOwner, address(this)),
            "Grant NFT approval to Sale Contract"
        );
        _sellNFT(nftId, price, artist, nftOwner);
    }

    /**
     * Put up My NFT for Sale
     *
     * @param nftId - nftId of the NFT
     * @param price - price to sell NFT for
     */
    function sellMyNFT(uint256 nftId, uint256 price) external {
        address nftOwner = IERC721(nftAddress).ownerOf(nftId);
        require(nftOwner == _msgSender(), "Seller Not Owner of NFTs");
        _sellNFT(nftId, price, (_msgSender()), nftOwner);
    }

    /**
     * Put up Multiple NFTs for Sale
     *
     * @param nftIds - nftIds of the NFTs
     * @param prices - prices to sell NFTs for
     * @param artist - artist or original owner of NFT
     */
    function sellNFTBatch(
        uint256[] calldata nftIds,
        uint256[] calldata prices,
        address artist
    ) external onlyAdmin {
        require(nftIds.length == prices.length, "nftIds and prices length mismatch");
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            address nftOwner = IERC721(nftAddress).ownerOf(nftId);
            require(
                IERC721(nftAddress).getApproved(nftId) == address(this) ||
                    IERC721(nftAddress).isApprovedForAll(nftOwner, address(this)),
                "Grant NFT approval to Sale Contract"
            );
        }
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            uint256 price = prices[i];
            address nftOwner = IERC721(nftAddress).ownerOf(nftId);
            _sellNFT(nftId, price, artist, nftOwner);
        }
    }

    /**
     * Put up Multiple NFTs of mine for Sale
     *
     * @param nftIds - nftIds of the NFTs
     * @param prices - prices to sell NFTs for
     */
    function sellMyNFTBatch(uint256[] calldata nftIds, uint256[] calldata prices) external {
        require(nftIds.length == prices.length, "nftIds and prices length mismatch");
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            require(IERC721(nftAddress).ownerOf(nftId) == _msgSender(), "Seller Not Owner of NFTs");
        }
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            uint256 price = prices[i];
            address nftOwner = IERC721(nftAddress).ownerOf(nftId);
            _sellNFT(nftId, price, (_msgSender()), nftOwner);
        }
    }

    /**
     * Get NFT Sale
     *
     * @param nftId - id of the NFT
     */
    function getSale(uint256 nftId) external view returns (address, uint256) {
        require(_nftSales[nftId].isActive, "NFT is not up for sale");
        return (_nftSales[nftId].owner, _nftSales[nftId].price);
    }

    /**
     * Cancel NFT Sale
     *
     * @param nftId - id of the NFT
     */
    function cancelSale(uint256 nftId) external onlyAdmin nonReentrant {
        require(_nftSales[nftId].isActive, "NFT is not up for sale");
        _nftSales[nftId].isActive = false;
        _nftSales[nftId].isCancelled = true;
        IERC721(nftAddress).safeTransferFrom(address(this), _nftSales[nftId].owner, nftId);
        emit SaleCancelled(nftId, _nftSales[nftId].price, _nftSales[nftId].owner, _msgSender(), block.timestamp);
    }

    /**
     * Purchase NFT Internal
     *
     * @param nftId - nftId of the NFT
     */
    function _purchaseNFT(uint256 nftId) private {
        require(_nftSales[nftId].isActive, "NFT is not for sale");
        address seller = _nftSales[nftId].owner;
        address buyer = (_msgSender());
        uint256 price = _nftSales[nftId].price;

        _nftSales[nftId].owner = buyer;
        _nftSales[nftId].isActive = false;

        //transfer price of nft to seller
        voxel.safeTransfer(seller, price);

        IERC721(nftAddress).safeTransferFrom(address(this), buyer, nftId);

        emit Sold(nftId, seller, buyer, price, block.timestamp);
    }

    /**
     * Purchase NFT
     *
     * @param nftId - nftId of the NFT
     */
    function purchaseNFT(uint256 nftId, uint256 _amount) external nonReentrant {
        require(isActive, "Contract Status in not Active");
        require(_amount == _nftSales[nftId].price, "value not equal to price of nft");

        voxel.safeTransferFrom(_msgSender(), address(this), _amount);
        _purchaseNFT(nftId);
    }

    /**
     * Batch Purchase NFT
     *
     * @param nftIds - nftIds of the NFT
     */
    function purchaseNFTBatch(uint256[] calldata nftIds, uint256 _amount) external nonReentrant {
        require(isActive, "Contract Status in not Active");
        uint256 totalPrice;
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            require(_nftSales[nftId].isActive, "One or more nfts requested in the batch purchase is not active");
            totalPrice = totalPrice + _nftSales[nftId].price;
        }
        require(_amount == totalPrice, "value not equal to price of nfts");
        voxel.safeTransferFrom(_msgSender(), address(this), _amount);

        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            _purchaseNFT(nftId);
        }
    }

    function hashMetaTransaction(Offer memory offer) internal pure returns (bytes32) {
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
        return signer == ecrecover(toTypedMessageHash(hashMetaTransaction(offer)), sigV, sigR, sigS);
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

    // @TODO Batch Purchase

    /**
     * Release NFT
     *
     * @param nftId - id of the NFT
     * @param buyer - buyer of the NFT
     */
    function releaseNFT(uint256 nftId, address buyer) external onlyAdmin nonReentrant {
        require(_nftSales[nftId].isActive, "NFT is not for sale");
        address seller = _nftSales[nftId].owner;

        _nftSales[nftId].owner = buyer;
        _nftSales[nftId].isActive = false;

        IERC721(nftAddress).safeTransferFrom(address(this), buyer, nftId);

        emit Sold(nftId, seller, buyer, 0, block.timestamp);
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
}
