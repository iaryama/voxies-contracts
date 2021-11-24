//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/AccessProtected.sol";
import "./utils/BaseRelayRecipient.sol";

interface IVoxelNFT {
    function issueToken(
        uint256,
        string memory,
        string memory
    ) external returns (uint256);

    function ownerOf(uint256) external view returns (address);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

contract NftAuction is IERC721Receiver, ReentrancyGuard, AccessProtected, BaseRelayRecipient {
    using Address for address;
    using Counters for Counters.Counter;

    struct Auction {
        uint256 auctionID;
        AuctionType orderType;
        uint256 highestBid;
        uint256 startBid;
        uint256 endBid;
        uint256 startingTime;
        uint256 closingTime;
        address highestBidder;
        address originalOwner;
        bool isActive;
        bool isSold;
        uint256 nftCount;
        address[] nftAddresses;
        uint256[] tokenIDs; // Corresponding tokenIDs to above NFT addresses.
    }

    mapping(address => mapping(uint256 => uint256)) private _nftToAuctionId; // NFT contract Address -> TokenID -> AuctionID
    mapping(address => bool) public allowedNFTAddresses; // Whitelisted NFT contract addresses

    Counters.Counter public _auctionIds;

    enum AuctionType {
        dutchAuction,
        englishAuction
    }
    AuctionType choice;
    //AuctionType orderType;

    mapping(uint256 => Auction) public auctions;

    IERC20 public immutable voxel;
    using SafeERC20 for IERC20;
    uint256 public balances;

    event NewAuctionOpened(
        AuctionType indexed orderType,
        address[] indexed nftAddresses,
        uint256[] indexed nftIds,
        uint256 startingBid,
        uint256 closingTime,
        address originalOwner
    );

    event EnglishAuctionClosed(uint256 indexed nftId, uint256 highestBid, address indexed highestBidder);

    event BidPlacedInEnglishAuction(uint256 indexed nftId, uint256 indexed bidPrice, address indexed bidder);

    event BoughtNFTInDutchAuction(uint256 indexed nftId, uint256 indexed bidPrice, address indexed buyer);

    event AuctionCancelled(uint256 indexed nftId, address indexed cancelledBy);

    constructor(IERC20 _voxel) {
        voxel = _voxel;
    }

    function getCurrentPrice(uint256 _auctionId, AuctionType orderType) public view returns (uint256) {
        AuctionType choicee = AuctionType.englishAuction;

        if (choicee == orderType) {
            return auctions[_auctionId].highestBid;
        } else {
            uint256 _startPrice = auctions[_auctionId].startBid;
            uint256 _endPrice = auctions[_auctionId].endBid;
            uint256 _startingTime = auctions[_auctionId].startingTime;
            uint256 tickPerBlock = (_startPrice - _endPrice) / (auctions[_auctionId].closingTime - _startingTime);
            return _startPrice - ((block.timestamp - _startingTime) * tickPerBlock);
        }
    }

    function startDutchAuction(
        address[] calldata _nftAddresses,
        uint256[] calldata _nftIds,
        uint256 _startPrice,
        uint256 _endBid,
        uint256 _duration
    ) external {
        require(_startPrice > _endBid, "End price should be lower than start price");
        choice = AuctionType.dutchAuction;
        openAuction(choice, _nftAddresses, _nftIds, _startPrice, _endBid, _duration);
    }

    function startEnglishAuction(
        address[] calldata _nftAddresses,
        uint256[] calldata _nftIds,
        uint256 _startPrice,
        uint256 _duration
    ) external {
        choice = AuctionType.englishAuction;
        openAuction(choice, _nftAddresses, _nftIds, _startPrice, 0, _duration);
    }

    function openAuction(
        AuctionType _orderType,
        address[] calldata _nftAddresses,
        uint256[] calldata _nftIds,
        uint256 _initialBid,
        uint256 _endBid,
        uint256 _duration
    ) private nonReentrant returns (uint256) {
        require(_nftAddresses.length == _nftIds.length, "call data not of same length");
        require(_nftIds.length > 0, "Atleast one NFT should be specified");
        require(_duration > 0 && _initialBid > 0, "Invalid input");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(allowedNFTAddresses[_nftAddresses[i]], "NFT contract address is not allowed");
            require(
                _nftToAuctionId[_nftAddresses[i]][_nftIds[i]] == 0,
                "An auction Bundle exists with one of the given NFT"
            );
            address nftOwner = IERC721(_nftAddresses[i]).ownerOf(_nftIds[i]);
            require(_msgSender() == nftOwner, "Not owner of one or more NFTs");
        }

        _auctionIds.increment();
        uint256 newAuctionId = _auctionIds.current();
        auctions[newAuctionId].auctionID = newAuctionId;
        auctions[newAuctionId].orderType = _orderType;
        auctions[newAuctionId].startBid = _initialBid;
        auctions[newAuctionId].endBid = _endBid;
        auctions[newAuctionId].startingTime = block.timestamp;
        auctions[newAuctionId].closingTime = block.timestamp + _duration;
        auctions[newAuctionId].highestBid = _initialBid;
        auctions[newAuctionId].highestBidder = _msgSender();
        auctions[newAuctionId].originalOwner = _msgSender();
        auctions[newAuctionId].isActive = true;
        auctions[newAuctionId].nftCount = _nftIds.length;
        auctions[newAuctionId].nftAddresses = _nftAddresses;
        auctions[newAuctionId].tokenIDs = _nftIds;

        for (uint256 i = 0; i < _nftIds.length; i++) {
            _nftToAuctionId[_nftAddresses[i]][_nftIds[i]] = newAuctionId;
            IERC721(_nftAddresses[i]).safeTransferFrom(_msgSender(), address(this), _nftIds[i]);
        }

        emit NewAuctionOpened(
            _orderType,
            _nftAddresses,
            _nftIds,
            auctions[newAuctionId].startBid,
            auctions[newAuctionId].closingTime,
            auctions[newAuctionId].originalOwner
        );
        return newAuctionId;
    }

    function placeBidInEnglishAuction(
        uint256 _auctionId,
        uint256 _amount,
        AuctionType orderType
    ) external nonReentrant {
        choice = AuctionType.englishAuction;
        require(auctions[_auctionId].isActive == true, "Not active auction");
        require(auctions[_auctionId].closingTime > block.timestamp, "Auction is closed");
        require(_amount > auctions[_auctionId].highestBid, "Bid is too low");
        require(orderType == choice, "only for English Auction");
        if (auctions[_auctionId].closingTime - block.timestamp <= 600) {
            auctions[_auctionId].closingTime += 60;
        }

        voxel.safeTransferFrom(_msgSender(), address(this), _amount);
        //transferring bid amount to previous highest bidder
        if (auctions[_auctionId].originalOwner != auctions[_auctionId].highestBidder) {
            voxel.safeTransfer(auctions[_auctionId].highestBidder, auctions[_auctionId].highestBid);
        }
        auctions[_auctionId].highestBid = _amount;
        auctions[_auctionId].highestBidder = _msgSender();
        emit BidPlacedInEnglishAuction(_auctionId, auctions[_auctionId].highestBid, auctions[_auctionId].highestBidder);
    }

    function buyNftFromDutchAuction(
        uint256 _auctionId,
        uint256 _amount,
        AuctionType orderType
    ) external nonReentrant {
        choice = AuctionType.dutchAuction;
        require(auctions[_auctionId].isActive == true, "Not active auction");
        require(auctions[_auctionId].closingTime > block.timestamp, "Auction is closed");
        require(orderType == choice, "only for Dutch Auction");
        require(auctions[_auctionId].isSold == false, "Already sold");
        uint256 currentPrice = getCurrentPrice(_auctionId, choice);
        require(_amount >= currentPrice, "price error");
        address seller = auctions[_auctionId].originalOwner;

        auctions[_auctionId].highestBid = _amount;
        auctions[_auctionId].highestBidder = _msgSender();
        auctions[_auctionId].isSold = true;

        // transferring price to seller of nft
        voxel.safeTransferFrom(_msgSender(), seller, currentPrice);
        //voxel.safeTransferFrom(_msgSender(), address(this), _amount);

        //transferring nft to highest bidder
        uint256[] memory _nftIds = auctions[_auctionId].tokenIDs;
        address[] memory _nftAddresses = auctions[_auctionId].nftAddresses;
        for (uint256 i = 0; i < _nftIds.length; i++) {
            IERC721(_nftAddresses[i]).safeTransferFrom(address(this), _msgSender(), _nftIds[i]);
        }

        emit BoughtNFTInDutchAuction(_auctionId, auctions[_auctionId].highestBid, auctions[_auctionId].highestBidder);
    }

    function claimNftFromEnglishAuction(uint256 _auctionId) external nonReentrant {
        require(auctions[_auctionId].isActive == true, "Not active auction");
        require(auctions[_auctionId].closingTime <= block.timestamp, "Auction is not closed");
        require(auctions[_auctionId].highestBidder == _msgSender(), "You are not ower of this NFT");

        address seller = auctions[_auctionId].originalOwner;

        //sending price to seller of nft
        voxel.safeTransfer(seller, auctions[_auctionId].highestBid);

        //transferring nft to highest bidder
        uint256[] memory _nftIds = auctions[_auctionId].tokenIDs;
        address[] memory _nftAddresses = auctions[_auctionId].nftAddresses;
        for (uint256 i = 0; i < _nftIds.length; i++) {
            IERC721(_nftAddresses[i]).safeTransferFrom(address(this), auctions[_auctionId].highestBidder, _nftIds[i]);
        }

        auctions[_auctionId].isActive = false;
        emit EnglishAuctionClosed(_auctionId, auctions[_auctionId].highestBid, auctions[_auctionId].highestBidder);
    }

    function cancelAuction(uint256 _auctionId) external nonReentrant {
        require(auctions[_auctionId].isActive == true, "Not active auction");
        require(auctions[_auctionId].closingTime > block.timestamp, "Auction is closed, Go to Claim Nft");
        require(auctions[_auctionId].startBid == auctions[_auctionId].highestBid, "Bids were placed in the Auction");
        require(auctions[_auctionId].originalOwner == _msgSender(), "You are not the creator of Auction");
        auctions[_auctionId].isActive = false;
        delete auctions[_auctionId];

        emit AuctionCancelled(_auctionId, _msgSender());
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setTrustedForwarder(address _trustedForwarder) external onlyAdmin {
        trustedForwarder = _trustedForwarder;
    }

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address) {
        return BaseRelayRecipient._msgSender();
    }
}
