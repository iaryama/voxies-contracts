import { ethers } from "hardhat";
import { expect } from "chai";
import { Signer } from "ethers";
import {Voxel, Voxel__factory, VoxiesNFTEngine, VoxiesNFTEngine__factory,NftAuction, NftAuction__factory } from "../typechain";

describe("Nft Auction Test", async () => {
    let owner: Signer,
        accounts1: Signer,
        accounts2: Signer,
        accounts3: Signer,
        accounts4: Signer,
        accounts5: Signer,
        voxelEngine: VoxiesNFTEngine__factory,
        vox: VoxiesNFTEngine,
        nftAuction: NftAuction__factory,
        auction: NftAuction,
        voxel: Voxel, voxelFactory: Voxel__factory;

    before(async () => {        
        voxelFactory = await ethers.getContractFactory("Voxel");
        voxel = await voxelFactory.deploy();
        voxelEngine = await ethers.getContractFactory("VoxiesNFTEngine");
        vox = await voxelEngine.deploy("VoxelNFT", "VOX");
        nftAuction = await ethers.getContractFactory("NftAuction");
        auction = await nftAuction.deploy(voxel.address,vox.address);
        [owner, accounts1, accounts2, accounts3, accounts4, accounts5] = await ethers.getSigners();
        var transferResult = await voxel.connect(owner).approve(await owner.getAddress(), 10000);
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(await owner.getAddress(), await accounts2.getAddress(), 10000); 

        var transferResult = await voxel.connect(owner).approve(await owner.getAddress(), 10000);
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(await owner.getAddress(), await accounts3.getAddress(), 10000); 

        var transferResult = await voxel.connect(owner).approve(await owner.getAddress(), 10000);
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(await owner.getAddress(), await accounts4.getAddress(), 10000); 
    });
    it("should have correct name", async () => {
        const name = await vox.name();
        expect(name).to.be.equal("VoxelNFT");
    });
    it("should have correct symbol", async () => {
        expect(await vox.symbol()).eq("VOX");
    });
    
    describe("Functionality Tests", async () => {
        before(async () => {      
            const nftOwner = await accounts1.getAddress();  
            const hash = "some-hash";            
            const hash1 = "some-hashh";
            await vox.issueToken(nftOwner, hash);
            await vox.issueToken(nftOwner, hash1);
        });
        
        it("Owner of Nft should start Dutch Auction", async () => {
            
            const nftId=1;
            const startBid=230;
            const endBid=100;
            const duration=6;
                        
            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction.connect(accounts1).dutchAuction(nftId,startBid,endBid,duration);
            await expect(auctionResult).to.emit(auction,"NewAuctionOpened");
        });
        it("Owner of Nft should start English Auction", async () => {
            const nftId=2;
            const startBid=230;
            const duration=11;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction.connect(accounts1).englishAuction(nftId,startBid,duration);
            await expect(auctionResult).to.emit(auction,"NewAuctionOpened");
            
        });
        it("User should be able to place bid in Dutch Auction", async () => {
            const nftId=1;
            const startBid=230;
            const newBid=300;

            var approvalResult = await voxel.connect(accounts2).approve(auction.address, newBid+startBid);
            await expect(approvalResult).to.emit(voxel, "Approval");
            // var approvallResult = await voxel.approve(auction.address, newBid);
            // await expect(approvallResult).to.emit(voxel, "Approval");

            var bidResult = await auction.connect(accounts2).buyNow(nftId,newBid);
            await expect(bidResult).to.emit(auction,"BidPlaced");
        });
        it("User should be able to place bid in English Auction", async () => {
            const nftId=2;
            const newBid=300;            
                       
            var approvallResult = await voxel.connect(accounts2).approve(auction.address, newBid);
            await expect(approvallResult).to.emit(voxel, "Approval");

            var bidResult = await auction.connect(accounts2).placeBid(nftId,newBid);
            await expect(bidResult).to.emit(auction,"BidPlaced");
        });
        it("Multiple User should be able to Place Bid in English Auction", async () => {
            const nftId=2;
            const newBid1=400;            
            const newBid2=500;
            const newBid3=600;            

            var approvallResult = await voxel.connect(accounts2).approve(auction.address, newBid1);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction.connect(accounts2).placeBid(nftId,newBid1);
            await expect(bidResult).to.emit(auction,"BidPlaced");    
            console.log("2"); 

            var approvallResult = await voxel.connect(accounts3).approve(auction.address, newBid2);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction.connect(accounts3).placeBid(nftId,newBid2);
            await expect(bidResult).to.emit(auction,"BidPlaced"); 
            console.log("3"); 

            var approvallResult = await voxel.connect(accounts4).approve(auction.address, newBid3);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction.connect(accounts4).placeBid(nftId,newBid3);
            await expect(bidResult).to.emit(auction,"BidPlaced");
            console.log("4"); 
        });
        it("User should be able to Claim Nft won in English Auction", async () => {
            const nftId=2;

            var nftResult = await auction.connect(accounts4).closeAuction(nftId);
            await expect(nftResult).to.emit(auction,"AuctionClosed");
        });
    });
});
