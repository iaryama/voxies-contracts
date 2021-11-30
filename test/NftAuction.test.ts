import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Signer } from "ethers";
import {
    Voxel,
    Voxel__factory,
    VoxiesNFTEngine,
    VoxiesNFTEngine__factory,
    NftAuction,
    NftAuction__factory,
} from "../typechain";

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
        voxel: Voxel,
        voxelFactory: Voxel__factory;

    before(async () => {
        voxelFactory = await ethers.getContractFactory("Voxel");
        voxel = await voxelFactory.deploy();
        voxelEngine = await ethers.getContractFactory("VoxiesNFTEngine");
        vox = await voxelEngine.deploy("VoxelNFT", "VOX");
        nftAuction = await ethers.getContractFactory("NftAuction");
        auction = await nftAuction.deploy(voxel.address);

        [owner, accounts1, accounts2, accounts3, accounts4, accounts5] = await ethers.getSigners();
        const amount = "100000";
        var transferResult = await voxel
            .connect(owner)
            .approve(await owner.getAddress(), ethers.utils.parseEther(amount));
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(
            await owner.getAddress(),
            await accounts2.getAddress(),
            ethers.utils.parseEther(amount)
        );

        var transferResult = await voxel
            .connect(owner)
            .approve(await owner.getAddress(), ethers.utils.parseEther(amount));
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(
            await owner.getAddress(),
            await accounts3.getAddress(),
            ethers.utils.parseEther(amount)
        );

        var transferResult = await voxel
            .connect(owner)
            .approve(await owner.getAddress(), ethers.utils.parseEther(amount));
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(
            await owner.getAddress(),
            await accounts4.getAddress(),
            ethers.utils.parseEther(amount)
        );
    });
    it("should have correct name", async () => {
        const name = await vox.name();
        expect(name).to.be.equal("VoxelNFT");
    });
    it("should have correct symbol", async () => {
        expect(await vox.symbol()).eq("VOX");
    });
    it("owner should be able to add addresses to contract whitelist", async () => {
        await expect(vox.addToWhitelist(vox.address));
        await expect(vox.addToWhitelist(auction.address));
    });
    describe("Functionality Tests", async () => {
        before(async () => {
            const nftOwner = await accounts1.getAddress();
            const hash = "some-hash";
            const hash1 = "some-hashh";
            const hash2 = "some-hasshh";
            const hash3 = "some-haashh";
            const hash4 = "some-hhashh";
            const hash5 = "somee-hhashh";
            const hash6 = "somme-hhashh";
            const hash7 = "sommee-hhashh";
            const hash8 = "soommee-hhashh";
            await vox.issueToken(nftOwner, hash);
            await vox.issueToken(nftOwner, hash1);
            await vox.issueToken(nftOwner, hash2);
            await vox.issueToken(nftOwner, hash3);
            await vox.issueToken(nftOwner, hash4);
            await vox.issueToken(nftOwner, hash5);
            await vox.issueToken(nftOwner, hash6);
            await vox.issueToken(nftOwner, hash7);
            await vox.issueToken(nftOwner, hash8);
        });

        it("Owner of Nft should start Dutch Auction", async () => {
            const nftId = 1;
            const startBid = "230";
            const endBid = "100";
            const duration = 100;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            await auction.connect(owner).setNFTContractStatus(vox.address, true);
            var auctionResult = await auction
                .connect(accounts1)
                .startDutchAuction(
                    [vox.address],
                    [nftId],
                    ethers.utils.parseEther(startBid),
                    ethers.utils.parseEther(endBid),
                    duration
                );
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");
        });
        it("Non-owner of Nft should not be able to start Dutch Auction", async () => {
            const nftId = 2;
            const startBid = "230";
            const endBid = "100";
            const duration = 6;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            await expect(
                auction
                    .connect(accounts2)
                    .startDutchAuction(
                        [vox.address],
                        [nftId],
                        ethers.utils.parseEther(startBid),
                        ethers.utils.parseEther(endBid),
                        duration
                    )
            ).to.be.revertedWith("Not owner of one or more NFTs");
        });
        it("Owner of Nft should start English Auction", async () => {
            const nftId = 3;
            const startBid = "230";
            const duration = "1800";

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            const auctionResult = await auction
                .connect(accounts1)
                .startEnglishAuction([vox.address], [nftId], ethers.utils.parseEther(startBid), duration);
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");
        });
        it("Non-owner of Nft should not be able to start English Auction", async () => {
            const nftId = 2;
            const startBid = "230";
            const duration = 11;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            await expect(
                auction
                    .connect(accounts2)
                    .startEnglishAuction([vox.address], [nftId], ethers.utils.parseEther(startBid), duration)
            ).to.be.revertedWith("Not owner of one or more NFTs");
        });
        it("User should be able to place bid in Dutch Auction", async () => {
            const auctionId = 1;
            const startBid = "230";
            const newBid = "230";

            var approvalResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvalResult).to.emit(voxel, "Approval");

            var bidResult = await auction
                .connect(accounts2)
                .buyNftFromDutchAuction(auctionId, ethers.utils.parseEther(newBid), 0);
            await expect(bidResult).to.emit(auction, "BoughtNFTInDutchAuction");
        });
        it("User should not be able to place bid in Inactive Dutch Auction", async () => {
            const auctionId = 4;
            const startBid = "230";
            const newBid = "300";

            var approvalResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvalResult).to.emit(voxel, "Approval");

            await expect(
                auction
                    .connect(accounts2)
                    .buyNftFromDutchAuction(auctionId, ethers.utils.parseEther(newBid), 0)
            ).to.be.revertedWith("Not active auction");
        });
        it("User should not be able to buy sold NFT in Dutch Auction", async () => {
            const auctionId = 1;
            const startBid = "230";
            const newBid = "310";

            var approvalResult = await voxel
                .connect(accounts3)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvalResult).to.emit(voxel, "Approval");

            await expect(
                auction
                    .connect(accounts3)
                    .buyNftFromDutchAuction(auctionId, ethers.utils.parseEther(newBid), 0)
            ).to.be.revertedWith("Already sold");
        });
        it("User should not be able to place bid in closed Dutch Auction", async () => {
            const nftId = 1;
            const startBid = "230";
            const newBid = "300";

            await ethers.provider.send("evm_increaseTime", [100]);
            var approvalResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvalResult).to.emit(voxel, "Approval");

            await expect(
                auction.connect(accounts2).buyNftFromDutchAuction(nftId, ethers.utils.parseEther(newBid), 0)
            ).to.be.revertedWith("Auction is closed");
        });
        it("User should be able to place bid in English Auction", async () => {
            const auctionId = 2;
            const newBid = "300";

            var approvallResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvallResult).to.emit(voxel, "Approval");

            var bidResult = await auction
                .connect(accounts2)
                .placeBidInEnglishAuction(auctionId, ethers.utils.parseEther(newBid), 1);
            await expect(bidResult).to.emit(auction, "BidPlacedInEnglishAuction");
        });
        it("User should not be able to place bid in Inactive English Auction", async () => {
            const auctionId = 3;
            const newBid = "300";

            var approvallResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvallResult).to.emit(voxel, "Approval");

            await expect(
                auction
                    .connect(accounts2)
                    .placeBidInEnglishAuction(auctionId, ethers.utils.parseEther(newBid), 1)
            ).to.be.revertedWith("Not active auction");
        });
        it("Multiple User should be able to Place Bid in English Auction", async () => {
            const auctionId = 2;
            const newBid1 = "400";
            const newBid2 = "500";
            const newBid3 = "600";

            var approvallResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid1));
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction
                .connect(accounts2)
                .placeBidInEnglishAuction(auctionId, ethers.utils.parseEther(newBid1), 1);
            await expect(bidResult).to.emit(auction, "BidPlacedInEnglishAuction");

            var approvallResult = await voxel
                .connect(accounts3)
                .approve(auction.address, ethers.utils.parseEther(newBid2));
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction
                .connect(accounts3)
                .placeBidInEnglishAuction(auctionId, ethers.utils.parseEther(newBid2), 1);
            await expect(bidResult).to.emit(auction, "BidPlacedInEnglishAuction");

            var approvallResult = await voxel
                .connect(accounts4)
                .approve(auction.address, ethers.utils.parseEther(newBid3));
            await expect(approvallResult).to.emit(voxel, "Approval");
            var bidResult = await auction
                .connect(accounts4)
                .placeBidInEnglishAuction(auctionId, ethers.utils.parseEther(newBid3), 1);
            await expect(bidResult).to.emit(auction, "BidPlacedInEnglishAuction");
        });
        it("User should be able to Claim Nft won in English Auction", async () => {
            const auctionId = 2;
            await ethers.provider.send("evm_increaseTime", [1800]);
            var nftResult = await auction.connect(accounts4).claimNftFromEnglishAuction(auctionId);
            await expect(nftResult).to.emit(auction, "EnglishAuctionClosed");
        });
        it("User should not be able to place bid in closed English Auction", async () => {
            const nftId = 4;
            const startBid = "230";
            const duration = 100;
            const newBid = "300";

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction
                .connect(accounts1)
                .startEnglishAuction([vox.address], [nftId], ethers.utils.parseEther(startBid), duration);
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");

            await ethers.provider.send("evm_increaseTime", [1800]);

            var approvallResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvallResult).to.emit(voxel, "Approval");

            await expect(
                auction.connect(accounts2).placeBidInEnglishAuction(3, ethers.utils.parseEther(newBid), 1)
            ).to.be.revertedWith("Auction is closed");
        });
        it("Owner of Nft can cancel Dutch Auction", async () => {
            const nftId = 5;
            const startBid = "230";
            const endBid = "100";
            const duration = 100;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction
                .connect(accounts1)
                .startDutchAuction(
                    [vox.address],
                    [nftId],
                    ethers.utils.parseEther(startBid),
                    endBid,
                    duration
                );
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");

            var cancelResult = await auction.connect(accounts1).cancelAuction(4);
            await expect(cancelResult).to.emit(auction, "AuctionCancelled");
        });
        it("Non-Owner of Nft cannot cancel Dutch Auction", async () => {
            const nftId = 6;
            const startBid = "230";
            const endBid = "100";
            const duration = 100;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction
                .connect(accounts1)
                .startDutchAuction(
                    [vox.address],
                    [nftId],
                    ethers.utils.parseEther(startBid),
                    endBid,
                    duration
                );
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");

            await expect(auction.connect(accounts2).cancelAuction(5)).to.be.revertedWith(
                "You are not the creator of Auction"
            );
        });
        it("Owner of Nft cannot cancel if bid is placed in Dutch Auction", async () => {
            const nftId = 6;
            const startBid = "230";
            const newBid = "300";

            var approvalResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvalResult).to.emit(voxel, "Approval");

            var bidResult = await auction
                .connect(accounts2)
                .buyNftFromDutchAuction(5, ethers.utils.parseEther(newBid), 0);
            await expect(bidResult).to.emit(auction, "BoughtNFTInDutchAuction");

            await expect(auction.connect(accounts1).cancelAuction(5)).to.be.revertedWith(
                "Bids were placed in the Auction"
            );
        });

        it("Owner of Nft can cancel English Auction", async () => {
            const nftId = 7;
            const startBid = "230";
            const duration = 1800;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction
                .connect(accounts1)
                .startEnglishAuction([vox.address], [nftId], ethers.utils.parseEther(startBid), duration);
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");

            var cancelResult = await auction.connect(accounts1).cancelAuction(6);
            await expect(cancelResult).to.emit(auction, "AuctionCancelled");
        });
        it("Non-Owner of Nft cannot cancel English Auction", async () => {
            const nftId = 8;
            const startBid = "230";
            const duration = 1800;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction
                .connect(accounts1)
                .startEnglishAuction([vox.address], [nftId], ethers.utils.parseEther(startBid), duration);
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");

            await expect(auction.connect(accounts2).cancelAuction(7)).to.be.revertedWith(
                "You are not the creator of Auction"
            );
        });
        it("Owner of Nft cannot cancel if bid placed in English Auction", async () => {
            const nftId = 8;
            const newBid = "300";

            var approvallResult = await voxel
                .connect(accounts2)
                .approve(auction.address, ethers.utils.parseEther(newBid));
            await expect(approvallResult).to.emit(voxel, "Approval");

            var bidResult = await auction
                .connect(accounts2)
                .placeBidInEnglishAuction(7, ethers.utils.parseEther(newBid), 1);
            await expect(bidResult).to.emit(auction, "BidPlacedInEnglishAuction");

            await expect(auction.connect(accounts1).cancelAuction(7)).to.be.revertedWith(
                "Bids were placed in the Auction"
            );
        });
        it("start Dutch Auction", async () => {
            const nftId = 9;
            const startBid = "2330";
            const endBid = "500";
            const duration = 14440;

            var approvalResult = await vox.connect(accounts1).approve(auction.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var auctionResult = await auction
                .connect(accounts1)
                .startDutchAuction(
                    [vox.address],
                    [nftId],
                    ethers.utils.parseEther(startBid),
                    ethers.utils.parseEther(endBid),
                    duration
                );
            await expect(auctionResult).to.emit(auction, "NewAuctionOpened");

            console.log("0 hours", (await auction.getCurrentPrice(8, 0)).toString());
            await network.provider.send("evm_increaseTime", [3601]);
            await network.provider.send("evm_mine");
            console.log("1 hours", (await auction.getCurrentPrice(8, 0)).toString());
            await network.provider.send("evm_increaseTime", [3601]);
            await network.provider.send("evm_mine");
            console.log("2 hours", (await auction.getCurrentPrice(8, 0)).toString());
            await network.provider.send("evm_increaseTime", [3601]);
            await network.provider.send("evm_mine");
            console.log("3 hours", (await auction.getCurrentPrice(8, 0)).toString());
            await network.provider.send("evm_increaseTime", [3601]);
            await network.provider.send("evm_mine");
            console.log("4 hours", (await auction.getCurrentPrice(8, 0)).toString());
        });
    });
});
