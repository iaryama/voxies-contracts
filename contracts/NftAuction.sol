//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

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

contract NftAuction is IERC721Receiver, ReentrancyGuard {
    struct Auction {
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
    }

    enum AuctionType {
        dutchAuction,
        englishAuction
    }
    AuctionType choice;
    //AuctionType orderType;

    mapping(uint256 => Auction) public auctions;

    IERC20 public immutable voxel;
    IVoxelNFT public immutable nft_;
    using SafeERC20 for IERC20;
    uint256 public balances;

    event NewAuctionOpened(
        AuctionType indexed orderType,
        uint256 indexed nftId,
        uint256 startingBid,
        uint256 closingTime,
        address indexed originalOwner
    );

    event EnglishAuctionClosed(uint256 indexed nftId, uint256 highestBid, address indexed highestBidder);

    event BidPlacedInEnglishAuction(uint256 indexed nftId, uint256 indexed bidPrice, address indexed bidder);

    event BoughtNFTInDutchAuction(uint256 indexed nftId, uint256 indexed bidPrice, address indexed buyer);

    event AuctionCancelled(uint256 indexed nftId, address indexed cancelledBy);

    constructor(IERC20 _voxel, IVoxelNFT _nft) {
        nft_ = _nft;
        voxel = _voxel;
    }

    function getCurrentPrice(uint256 _nftId, AuctionType orderType) public view returns (uint256) {
        AuctionType choicee = AuctionType.englishAuction;

        if (choicee == orderType) {
            return auctions[_nftId].highestBid;
        } else {
            uint256 _startPrice = auctions[_nftId].startBid;
            uint256 _endPrice = auctions[_nftId].endBid;
            uint256 _startingTime = auctions[_nftId].startingTime;
            uint256 tickPerBlock = (_startPrice - _endPrice) / (auctions[_nftId].closingTime - _startingTime);
            return _startPrice - ((block.timestamp - _startingTime) * tickPerBlock);
        }
    }

    function startDutchAuction(
        uint256 _nftId,
        uint256 _startPrice,
        uint256 _endBid,
        uint256 _duration
    ) external {
        require(_startPrice > _endBid, "End price should be lower than start price");
        choice = AuctionType.dutchAuction;
        openAuction(choice, _nftId, _startPrice, _endBid, _duration);
    }

    function startEnglishAuction(
        uint256 _nftId,
        uint256 _startPrice,
        uint256 _duration
    ) external {
        choice = AuctionType.englishAuction;
        openAuction(choice, _nftId, _startPrice, 0, _duration);
    }

    function openAuction(
        AuctionType _orderType,
        uint256 _nftId,
        uint256 _initialBid,
        uint256 _endBid,
        uint256 _duration
    ) private nonReentrant {
        require(auctions[_nftId].isActive == false, "Ongoing auction detected");
        require(_duration > 0 && _initialBid > 0, "Invalid input");
        require(nft_.ownerOf(_nftId) == msg.sender, "Not NFT owner");
        auctions[_nftId].orderType = _orderType;
        auctions[_nftId].startBid = _initialBid;
        auctions[_nftId].endBid = _endBid;
        auctions[_nftId].startingTime = block.timestamp;
        auctions[_nftId].closingTime = block.timestamp + _duration;
        auctions[_nftId].highestBid = _initialBid;
        auctions[_nftId].highestBidder = msg.sender;
        auctions[_nftId].originalOwner = msg.sender;
        auctions[_nftId].isActive = true;
        nft_.safeTransferFrom(msg.sender, address(this), _nftId);
        emit NewAuctionOpened(
            _orderType,
            _nftId,
            auctions[_nftId].startBid,
            auctions[_nftId].closingTime,
            auctions[_nftId].originalOwner
        );
    }

    function placeBidInEnglishAuction(
        uint256 _nftId,
        uint256 _amount,
        AuctionType orderType
    ) external nonReentrant {
        choice = AuctionType.englishAuction;
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime > block.timestamp, "Auction is closed");
        require(_amount > auctions[_nftId].highestBid, "Bid is too low");
        require(orderType == choice, "only for English Auction");
        if (auctions[_nftId].closingTime - block.timestamp <= 600) {
            auctions[_nftId].closingTime += 60;
        }

        voxel.safeTransferFrom(msg.sender, address(this), _amount);
        //transferring bid amount to previous highest bidder
        if (auctions[_nftId].originalOwner != auctions[_nftId].highestBidder) {
            voxel.safeTransfer(auctions[_nftId].highestBidder, auctions[_nftId].highestBid);
        }
        auctions[_nftId].highestBid = _amount;
        auctions[_nftId].highestBidder = msg.sender;
        emit BidPlacedInEnglishAuction(_nftId, auctions[_nftId].highestBid, auctions[_nftId].highestBidder);
    }

    function buyNftFromDutchAuction(
        uint256 _nftId,
        uint256 _amount,
        AuctionType orderType
    ) external nonReentrant {
        choice = AuctionType.dutchAuction;
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime > block.timestamp, "Auction is closed");
        require(orderType == choice, "only for Dutch Auction");
        require(auctions[_nftId].isSold == false, "Already sold");
        uint256 currentPrice = getCurrentPrice(_nftId, choice);
        require(_amount >= currentPrice, "price error");
        address seller = auctions[_nftId].originalOwner;

        auctions[_nftId].highestBid = _amount;
        auctions[_nftId].highestBidder = msg.sender;
        auctions[_nftId].isSold = true;

        // transferring price to seller of nft
        voxel.safeTransferFrom(msg.sender, seller, currentPrice);
        //voxel.safeTransferFrom(msg.sender, address(this), _amount);

        //transferring nft to highest bidder
        nft_.safeTransferFrom(address(this), msg.sender, _nftId);

        emit BoughtNFTInDutchAuction(_nftId, auctions[_nftId].highestBid, auctions[_nftId].highestBidder);
    }

    function claimNftFromEnglishAuction(uint256 _nftId) external nonReentrant {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime <= block.timestamp, "Auction is not closed");
        require(auctions[_nftId].highestBidder == msg.sender, "You are not ower of this NFT");

        address seller = auctions[_nftId].originalOwner;

        //sending price to seller of nft
        voxel.safeTransfer(seller, auctions[_nftId].highestBid);

        //transferring nft to highest bidder
        nft_.safeTransferFrom(address(this), auctions[_nftId].highestBidder, _nftId);
        auctions[_nftId].isActive = false;

        emit EnglishAuctionClosed(_nftId, auctions[_nftId].highestBid, auctions[_nftId].highestBidder);
    }

    function cancelAuction(uint256 _nftId) external nonReentrant {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime > block.timestamp, "Auction is closed, Go to Claim Nft");
        require(auctions[_nftId].startBid == auctions[_nftId].highestBid, "Bids were placed in the Auction");
        require(auctions[_nftId].originalOwner == msg.sender, "You are not the creator of Auction");
        auctions[_nftId].isActive = false;
        delete auctions[_nftId];

        emit AuctionCancelled(_nftId, msg.sender);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
