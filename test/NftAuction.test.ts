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
            const hash2 = "some-hasshh";
            const hash3 = "some-haashh";
            await vox.issueToken(nftOwner, hash);
            await vox.issueToken(nftOwner, hash1);
            await vox.issueToken(nftOwner, hash2);
            await vox.issueToken(nftOwner, hash3);
        });
        
        it("Owner of Nft should start Dutch Auction", async () => {
            
            const nftId=1;
            const startBid=230;
            const endBid=100;
            const duration=100;
                        
            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction.connect(accounts1).startDutchAuction(nftId,startBid,endBid,duration);
            await expect(auctionResult).to.emit(auction,"NewAuctionOpened");
        });
        it("Non-owner of Nft should not be able to start Dutch Auction", async () => {
            
            const nftId=2;
            const startBid=230;
            const endBid=100;
            const duration=6;
                        
            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            await expect(auction.connect(accounts2).startDutchAuction(nftId,startBid,endBid,duration)).to.be.revertedWith('Not NFT owner');
        });
        it("Owner of Nft should start English Auction", async () => {
            const nftId=3;
            const startBid=230;
            const duration=1800;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction.connect(accounts1).startEnglishAuction(nftId,startBid,duration);
            await expect(auctionResult).to.emit(auction,"NewAuctionOpened");
            
        });
        it("Non-owner of Nft should not be able to start English Auction", async () => {
            const nftId=2;
            const startBid=230;
            const duration=11;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            await expect(auction.connect(accounts2).startEnglishAuction(nftId,startBid,duration)).to.be.revertedWith('Not NFT owner');
            
        });
        it("User should be able to place bid in Dutch Auction", async () => {
            const nftId=1;
            const startBid=230;
            const newBid=300;

            var approvalResult = await voxel.connect(accounts2).approve(auction.address, newBid+startBid);
            await expect(approvalResult).to.emit(voxel, "Approval");

            var bidResult = await auction.connect(accounts2).buyNow(nftId,newBid);
            await expect(bidResult).to.emit(auction,"BidPlaced");
        });
        it("User should not be able to place bid in Inactive Dutch Auction", async () => {
            const nftId=4;
            const startBid=230;
            const newBid=300;

            var approvalResult = await voxel.connect(accounts2).approve(auction.address, newBid+startBid);
            await expect(approvalResult).to.emit(voxel, "Approval");

            await expect(auction.connect(accounts2).buyNow(nftId,newBid)).to.be.revertedWith('Not active auction');
        });
        it("User should not be able to buy sold NFT in Dutch Auction", async () => {
            const nftId=1;
            const startBid=230;
            const newBid=300;

            var approvalResult = await voxel.connect(accounts3).approve(auction.address, newBid+startBid);
            await expect(approvalResult).to.emit(voxel, "Approval");
            console.log("132")

            await expect(auction.connect(accounts3).buyNow(nftId,newBid)).to.be.revertedWith('Already sold');
        });
        it("User should not be able to place bid in closed Dutch Auction", async () => {
            const nftId=1;
            const startBid=230;
            const newBid=300;

            await ethers.provider.send("evm_increaseTime", [100]);
            var approvalResult = await voxel.connect(accounts2).approve(auction.address, newBid+startBid);
            await expect(approvalResult).to.emit(voxel, "Approval");

            await expect(auction.connect(accounts2).buyNow(nftId,newBid)).to.be.revertedWith('Auction is closed');
        });
        it("User should be able to place bid in English Auction", async () => {
            const nftId=3;
            const newBid=300;            
                       
            var approvallResult = await voxel.connect(accounts2).approve(auction.address, newBid);
            await expect(approvallResult).to.emit(voxel, "Approval");

            var bidResult = await auction.connect(accounts2).placeBid(nftId,newBid);
            await expect(bidResult).to.emit(auction,"BidPlaced");
        });
        it("User should not be able to place bid in Inactive English Auction", async () => {
            const nftId=4;
            const newBid=300;            
                       
            var approvallResult = await voxel.connect(accounts2).approve(auction.address, newBid);
            await expect(approvallResult).to.emit(voxel, "Approval");

            await expect(auction.connect(accounts2).placeBid(nftId,newBid)).to.be.revertedWith('Not active auction');
        });
        it("Multiple User should be able to Place Bid in English Auction", async () => {
            const nftId=3;
            const newBid1=400;            
            const newBid2=500;
            const newBid3=600;            

            var approvallResult = await voxel.connect(accounts2).approve(auction.address, newBid1);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction.connect(accounts2).placeBid(nftId,newBid1);
            await expect(bidResult).to.emit(auction,"BidPlaced");  

            var approvallResult = await voxel.connect(accounts3).approve(auction.address, newBid2);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction.connect(accounts3).placeBid(nftId,newBid2);
            await expect(bidResult).to.emit(auction,"BidPlaced"); 

            var approvallResult = await voxel.connect(accounts4).approve(auction.address, newBid3);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction.connect(accounts4).placeBid(nftId,newBid3);
            await expect(bidResult).to.emit(auction,"BidPlaced");
        });
        it("User should be able to Claim Nft won in English Auction", async () => {
            const nftId=3;
            await ethers.provider.send("evm_increaseTime", [1800]);
            var nftResult = await auction.connect(accounts4).closeAuction(nftId);
            await expect(nftResult).to.emit(auction,"AuctionClosed");
        });
        it("User should not be able to place bid in closed English Auction", async () => {
            const nftId=4;
            const startBid=230;
            const duration=100;
            const newBid=300;            

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction.connect(accounts1).startEnglishAuction(nftId,startBid,duration);
            await expect(auctionResult).to.emit(auction,"NewAuctionOpened");

            await ethers.provider.send("evm_increaseTime", [1800]);
                       
            var approvallResult = await voxel.connect(accounts2).approve(auction.address, newBid);
            await expect(approvallResult).to.emit(voxel, "Approval");

            await expect(auction.connect(accounts2).placeBid(nftId,newBid)).to.be.revertedWith('Auction is closed');
        });
       
    });
});
