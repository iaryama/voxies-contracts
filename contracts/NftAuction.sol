//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IVoxelNFT {
    function issueToken(uint256, string memory, string memory) external returns(
        uint256
    );
    function ownerOf(uint256) external view returns (address);
    function transfer(uint256, address) external;
}
contract NftAuction {
    struct Auction {
        uint256 highestBid;
        uint256 closingTime;
        address highestBidder;
        address originalOwner;
        bool isActive;
    }

    mapping(uint256 => Auction) public auctions;

    IVoxelNFT private sNft_;

    uint256 public balances;

    event NewAuctionOpened( uint256 nftId, uint256 startingBid, uint256 closingTime, address originalOwner);

    event AuctionClosed( uint256 nftId, uint256 highestBid, address highestBidder);

    event BidPlaced(uint256 nftId, uint256 bidPrice, address bidder);
    constructor(IVoxelNFT _sNft)  {
        sNft_ = _sNft;
    }

    
    function openAuction(uint256 _nftId, uint256 _initialBid,uint256 _duration) external {
        require(auctions[_nftId].isActive == false, "Ongoing auction detected");
        require(_duration > 0 && _initialBid > 0, "Invalid input");
        require(sNft_.ownerOf(_nftId) == msg.sender, "Not NFT owner");

        sNft_.transfer(_nftId, address(this));

        auctions[_nftId].highestBid = _initialBid;
        auctions[_nftId].closingTime = block.timestamp + _duration;
        auctions[_nftId].highestBidder = msg.sender;
        auctions[_nftId].originalOwner = msg.sender;
        auctions[_nftId].isActive = true;

        emit NewAuctionOpened( _nftId, auctions[_nftId].highestBid, auctions[_nftId].closingTime, auctions[_nftId].highestBidder);
    }

    function placeBid(uint256 _nftId) external payable {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime > block.timestamp,"Auction is closed");
        require(msg.value > auctions[_nftId].highestBid, "Bid is too low");

        if (auctions[_nftId].originalOwner != auctions[_nftId].highestBidder) {
            // Transfer Matic to Previous Highest Bidder
            
        }

        auctions[_nftId].highestBid = msg.value;
        auctions[_nftId].highestBidder = msg.sender;

        emit BidPlaced(_nftId,auctions[_nftId].highestBid,auctions[_nftId].highestBidder);
    }

    function closeAuction(uint256 _nftId) external {
        require(auctions[_nftId].isActive == true, "Not active auction");
        require(auctions[_nftId].closingTime <= block.timestamp,"Auction is not closed");

        
        if (auctions[_nftId].originalOwner != auctions[_nftId].highestBidder) {
            // Transfer Matic to NFT Owner
        }

        // Transfer NFT to Highest Bidder
        sNft_.transfer(_nftId, auctions[_nftId].highestBidder);
        auctions[_nftId].isActive = false;

        emit AuctionClosed(_nftId,auctions[_nftId].highestBid,auctions[_nftId].highestBidder);
    }
}