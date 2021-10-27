//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

contract NftAuction is IERC721Receiver {
    struct Auction {
        uint8 orderType;
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

    mapping(uint256 => Auction) public auctions;

    IERC20 public immutable voxel;
    IVoxelNFT public immutable nft_;
    using SafeERC20 for IERC20;
    uint256 public balances;

    event NewAuctionOpened(
        uint8 orderType,
        uint256 nftId,
        uint256 startingBid,
        uint256 closingTime,
        address originalOwner
    );

    event AuctionClosed(uint256 nftId, uint256 highestBid, address highestBidder);

    event BidPlaced(uint256 nftId, uint256 bidPrice, address bidder);

    constructor(IERC20 _voxel, IVoxelNFT _nft) {
        nft_ = _nft;
        voxel = _voxel;
    }

    function getCurrentPrice(uint256 _nftId) public view returns (uint256) {
        if (auctions[_nftId].orderType == 2) {
            uint256 lastBidPrice = auctions[_nftId].highestBid;
            return lastBidPrice == 0 ? auctions[_nftId].highestBid : lastBidPrice;
        } else {
            uint256 _startPrice = auctions[_nftId].startBid;
            uint256 _endPrice = auctions[_nftId].endBid;
            uint256 _startBlock = auctions[_nftId].startingTime;
            uint256 tickPerBlock = (_startPrice - _endPrice) / (auctions[_nftId].closingTime - _startBlock);
            return _startPrice - ((block.timestamp - _startBlock) * tickPerBlock);
        }
    }

    function startDutchAuction(
        uint256 _nftId,
        uint256 _startPrice,
        uint256 _endBid,
        uint256 _duration
    ) public {
        require(_startPrice > _endBid, "End price should be lower than start price");
        openAuction(1, _nftId, _startPrice, _endBid, _duration);
    }

    function startEnglishAuction(
        uint256 _nftId,
        uint256 _startPrice,
        uint256 _duration
    ) public {
        openAuction(2, _nftId, _startPrice, 0, _duration);
    }

    function openAuction(
        uint8 _orderType,
        uint256 _nftId,
        uint256 _initialBid,
        uint256 _endBid,
        uint256 _duration
    ) internal {
        require(auctions[_nftId].isActive == false, "Ongoing auction detected");
        require(_duration > 0 && _initialBid > 0, "Invalid input");
        require(nft_.ownerOf(_nftId) == msg.sender, "Not NFT owner");
        nft_.safeTransferFrom(msg.sender, address(this), _nftId);
        auctions[_nftId].orderType = _orderType;
        auctions[_nftId].startBid = _initialBid;
        auctions[_nftId].endBid = _endBid;
        auctions[_nftId].startingTime = block.timestamp;
        auctions[_nftId].closingTime = block.timestamp + _duration;
        auctions[_nftId].highestBid = _initialBid;
        auctions[_nftId].highestBidder = msg.sender;
        auctions[_nftId].originalOwner = msg.sender;
        auctions[_nftId].isActive = true;
        emit NewAuctionOpened(
            _orderType,
            _nftId,
            auctions[_nftId].startBid,
            auctions[_nftId].closingTime,
            auctions[_nftId].originalOwner
        );
    }

    function placeBid(uint256 _nftId, uint256 _amount) external {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime > block.timestamp, "Auction is closed");
        require(_amount > auctions[_nftId].highestBid, "Bid is too low");
        require(auctions[_nftId].orderType == 2, "only for English Auction");
        if (auctions[_nftId].closingTime - block.timestamp <= 600) {
            auctions[_nftId].closingTime += 60;
        }

        voxel.safeTransferFrom(msg.sender, address(this), _amount);

        if (auctions[_nftId].originalOwner != auctions[_nftId].highestBidder) {
            voxel.safeTransfer(auctions[_nftId].highestBidder, auctions[_nftId].highestBid);
        }

        auctions[_nftId].highestBid = _amount;
        auctions[_nftId].highestBidder = msg.sender;

        emit BidPlaced(_nftId, auctions[_nftId].highestBid, auctions[_nftId].highestBidder);
    }

    function buyNow(uint256 _nftId, uint256 _amount) external {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime > block.timestamp, "Auction is closed");
        require(_amount > auctions[_nftId].highestBid, "Bid is too low");
        require(auctions[_nftId].orderType == 1, "only for Dutch Auction");
        require(auctions[_nftId].isSold == false, "Already sold");

        uint256 currentPrice = getCurrentPrice(_nftId);

        voxel.safeTransferFrom(msg.sender, address(this), _amount);
        require(_amount >= currentPrice, "price error");
        auctions[_nftId].isSold = true;

        if (_amount > currentPrice) {
            uint256 extra_amount = _amount - currentPrice;
            voxel.safeTransfer(msg.sender, extra_amount);
        }

        nft_.safeTransferFrom(address(this), msg.sender, _nftId);

        emit BidPlaced(_nftId, auctions[_nftId].highestBid, auctions[_nftId].highestBidder);
    }

    function closeAuction(uint256 _nftId) external {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime <= block.timestamp, "Auction is not closed");

        if (auctions[_nftId].originalOwner != auctions[_nftId].highestBidder) {
            voxel.safeTransfer(auctions[_nftId].highestBidder, auctions[_nftId].highestBid);
        }

        nft_.safeTransferFrom(address(this), auctions[_nftId].highestBidder, _nftId);
        auctions[_nftId].isActive = false;

        emit AuctionClosed(_nftId, auctions[_nftId].highestBid, auctions[_nftId].highestBidder);
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
