// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// NFTSale SMART CONTRACT
contract NFTSale is OwnableUpgradeable, IERC721Receiver {
    using Address for address;

    address public immutable nftAddress;
    bool public isActive;

    struct Sale {
        uint256 nftId;
        uint256 price;
        address payable owner;
        bool isActive;
        bool isCancelled;
    }

    // nftId => Sale mapping
    mapping(uint256 => Sale) public _nftSales;
    // user address => admin? mapping
    mapping(address => bool) private _admins;

    event ContractStatusSet(address _admin, bool _isActive);
    event AdminAccessSet(address _admin, bool _enabled);
    event SaleAdded(uint256 _nftId, uint256 _price, address _owner, uint256 _timestamp);
    event SaleCancelled(uint256 _nftId, uint256 _price, address _owner, address _cancelledBy, uint256 _timestamp);
    event Sold(uint256 _nftId, address _seller, address _buyer, uint256 _price, uint256 _timestamp);

    constructor(address _nftAddress) {
        require(_nftAddress.isContract(), "_nftAddress must be a contract");
        __Ownable_init();
        nftAddress = _nftAddress;
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
        address payable artist,
        address nftOwner
    ) private {
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
        address payable artist
    ) public onlyAdmin {
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
    function sellMyNFT(uint256 nftId, uint256 price) public {
        address nftOwner = IERC721(nftAddress).ownerOf(nftId);
        require(nftOwner == _msgSender(), "Seller Not Owner of NFTs");
        _sellNFT(nftId, price, payable(_msgSender()), nftOwner);
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
        address payable artist
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
            _sellNFT(nftId, price, payable(_msgSender()), nftOwner);
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
    function cancelSale(uint256 nftId) external onlyAdmin {
        require(_nftSales[nftId].isActive, "NFT is not up for sale");
        _nftSales[nftId].isActive = false;
        _nftSales[nftId].isCancelled = true;
        IERC721(nftAddress).safeTransferFrom(address(this), owner(), nftId);
        emit SaleCancelled(nftId, _nftSales[nftId].price, _nftSales[nftId].owner, _msgSender(), block.timestamp);
    }

    /**
     * Purchase NFT Internal
     *
     * @param nftId - nftId of the NFT
     */
    function _purchaseNFT(uint256 nftId) private {
        require(_nftSales[nftId].isActive, "NFT is not for sale");
        address payable seller = _nftSales[nftId].owner;
        address payable buyer = payable(_msgSender());
        uint256 price = _nftSales[nftId].price;

        _nftSales[nftId].owner = buyer;
        _nftSales[nftId].isActive = false;

        seller.transfer(price);
        IERC721(nftAddress).safeTransferFrom(address(this), buyer, nftId);

        emit Sold(nftId, seller, buyer, price, block.timestamp);
    }

    /**
     * Purchase NFT
     *
     * @param nftId - nftId of the NFT
     */
    function purchaseNFT(uint256 nftId) external payable {
        require(isActive, "Contract Status in not Active");
        require(msg.value >= _nftSales[nftId].price, "value less than price of nft");
        _purchaseNFT(nftId);
    }

    /**
     * Batch Purchase NFT
     *
     * @param nftIds - nftIds of the NFT
     */
    function purchaseNFTBatch(uint256[] calldata nftIds) external payable {
        require(isActive, "Contract Status in not Active");
        uint256 totalPrice;
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            require(_nftSales[nftId].isActive, "One or more nfts requested in the batch purchase is not active");
            totalPrice = totalPrice + _nftSales[nftId].price;
        }
        require(msg.value >= totalPrice, "value less than total price of nfts");
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            _purchaseNFT(nftId);
        }
    }

    // @TODO Batch Purchase

    /**
     * Release NFT
     *
     * @param nftId - id of the NFT
     * @param buyer - buyer of the NFT
     */
    function releaseNFT(uint256 nftId, address payable buyer) external onlyAdmin {
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
