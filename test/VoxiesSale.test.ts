import { ethers, waffle } from "hardhat";
import { expect, use } from "chai";
import { Signer } from "ethers";
import { Voxel,Voxel__factory,VoxiesNFTEngine, VoxiesNFTEngine__factory, NFTSale, NFTSale__factory } from "../typechain";

use(waffle.solidity);

describe("NFTSale Test", async () => {
    let owner: Signer,
        accounts1: Signer,
        accounts2: Signer,
        accounts3: Signer,
        voxelEngine: VoxiesNFTEngine__factory,
        vox: VoxiesNFTEngine,
        nftsale: NFTSale__factory,
        nft: NFTSale,
        voxel: Voxel,
        voxelFactory: Voxel__factory;
    beforeEach(async () => {
        voxelFactory = await ethers.getContractFactory("Voxel");
        voxel = await voxelFactory.deploy();
        voxelEngine = await ethers.getContractFactory("VoxiesNFTEngine");
        vox = await voxelEngine.deploy("VoxelNFT", "VOX");
        [owner, accounts1, accounts2, accounts3] = await ethers.getSigners();
        nftsale = await ethers.getContractFactory("NFTSale");
        nft = await nftsale.deploy(vox.address,voxel.address);

        var transferResult = await voxel.connect(owner).approve(await owner.getAddress(), 10000);
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(await owner.getAddress(), await accounts2.getAddress(), 10000);

        var transferResult = await voxel.connect(owner).approve(await owner.getAddress(), 10000);
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(await owner.getAddress(), await accounts3.getAddress(), 10000);

        var transferResult = await voxel.connect(owner).approve(await owner.getAddress(), 10000);
        await expect(transferResult).to.emit(voxel, "Approval");
        voxel.transferFrom(await owner.getAddress(), await accounts1.getAddress(), 10000);
    });
    it("should have correct NFT address", async () => {
        const nftAddress = await nft.nftAddress();
        expect(nftAddress).to.be.equal(vox.address);
    });
    it("owner should be able to add addresses to contract whitelist", async () => {
        await expect(vox.addToWhitelist(vox.address));
        await expect(vox.addToWhitelist(nft.address));
    });
    describe("Access Tests", async () => {
        it("owner should be able to set admin", async () => {
            await expect(nft.setAdmin(await accounts1.getAddress(), true)).to.emit(nft, "AdminAccessSet");
            expect(await nft.isAdmin(await accounts1.getAddress())).to.be.equal(true);
        });
        it("non-owner should not be able to set admin", async () => {
            await expect(
                nft.connect(accounts1).setAdmin(await accounts1.getAddress(), true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
        it("owner should be able to revoke admin", async () => {
            const result = await nft.setAdmin(await accounts1.getAddress(), false);
            await expect(result).to.emit(nft, "AdminAccessSet");
            expect(await nft.isAdmin(await accounts1.getAddress())).to.be.equal(false);
        });
    });
    describe("Functionality Tests", async () => {
        beforeEach(async () => {
            const recepient = await owner.getAddress();
            const hash_01 = "some-hash";
            const hash_02 = "some-hash-02";
            const hash_03 = "some-hash-03";
            const result_01 = await vox.issueToken(recepient, hash_01);
            const result_02 = await vox.issueToken(recepient, hash_02);
            const result_03 = await vox.issueToken(recepient, hash_03);
            await expect(result_01).to.emit(vox, "Transfer");
            await expect(result_02).to.emit(vox, "Transfer");
            await expect(result_03).to.emit(vox, "Transfer");
            const nftOwner_01 = await vox.ownerOf(1);
            const nftOwner_02 = await vox.ownerOf(2);
            const nftOwner_03 = await vox.ownerOf(3);
            expect(nftOwner_01).to.be.equal(recepient);
            expect(nftOwner_02).to.be.equal(recepient);
            expect(nftOwner_03).to.be.equal(recepient);
            await expect(vox.addToWhitelist(nft.address));
        });
        it("non-admin should not be able to start sale", async () => {
            const nftId = 1;
            const price = 1000;
            await expect(
                nft.connect(accounts1).sellNFT(nftId, price, await accounts3.getAddress())
            ).to.be.revertedWith("Caller does not have Admin Access");
        });
        it("owner should not be able to start sale without granting approval", async () => {
            const nftId = 1;
            const price = 1000;
            await expect(nft.sellNFT(nftId, price, await accounts3.getAddress())).to.be.revertedWith(
                "Grant NFT approval to Sale Contract"
            );
        });
        it("owner should be able to start sale", async () => {
            const nftId = 1;
            const price = 1000;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const nftOwner = await vox.ownerOf(1);
            await expect(nftOwner).to.be.equal(nft.address);
        });
        it("should be able to get sale using NFT ID", async () => {
            const nftId = 1;
            const price = 1000;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const nftOwner = await vox.ownerOf(1);
            await expect(nftOwner).to.be.equal(nft.address);
            const sale = await nft.getSale(nftId);
            await expect(sale[0]).to.be.equal(await accounts3.getAddress());
            await expect(sale[1]).to.be.equal(1000);
        });
        it("should not be able to purchase if contract is inactive", async () => {
            const nftId = 1;
            const price = 1000;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const nftOwner = await vox.ownerOf(1);
            await expect(nftOwner).to.be.equal(nft.address);
            const buyer = await accounts2.getAddress();
            const sale = await nft.connect(buyer).getSale(nftId);
            const pricee = sale[1];
            await expect(
                nft.connect(accounts2).purchaseNFT(nftId, pricee)
            ).to.be.revertedWith("Contract Status in not Active");
        });
        it("should be able to purchase", async () => {
            await nft.setContractStatus(true);
            const nftId = 1;
            const price = 1000;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");

            const nftOwner = await vox.ownerOf(1);
            expect(nftOwner).to.be.equal(nft.address);

            const buyer = await accounts2.getAddress();
            const sale = await nft.connect(accounts2).getSale(nftId);
            const pricee = sale[1];
            var approvallResult = await voxel.connect(accounts2).approve(nft.address, pricee);
            await expect(approvallResult).to.emit(voxel, "Approval");

            var purchaseResult = await nft.connect(accounts2).purchaseNFT(nftId, pricee);
            const newNftOwner = await vox.ownerOf(nftId);
            await expect(purchaseResult).to.emit(nft, "Sold");
            await expect(newNftOwner).to.be.equal(buyer);
        });
        it("owner be able to release", async () => {
            const nftId = 2;
            const price = 1000;
            await vox.approve(nft.address, nftId);
            await nft.sellNFT(nftId, price, await accounts3.getAddress());

            const buyer = await accounts2.getAddress();

            var purchaseResult = await nft.releaseNFT(nftId, buyer);

            await expect(purchaseResult).to.emit(nft, "Sold");

            const nftOwner = await vox.ownerOf(nftId);
            await expect(nftOwner).to.be.equal(buyer);
        });
        it("owner should be able to cancel sale", async () => {
            const nftId = 3;
            const price = 1000;
            const nftOwner = await accounts3.getAddress();
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            await expect(nft.sellNFT(nftId, price, await accounts3.getAddress())).to.emit(nft, "SaleAdded");
            const newNftOwner = await vox.ownerOf(nftId);
            await expect(newNftOwner).to.be.equal(nft.address);
            var cancelledResult = await nft.cancelSale(nftId);
            await expect(cancelledResult).to.emit(nft, "SaleCancelled");
            const originalNftOwner = await vox.ownerOf(nftId);
            await expect(originalNftOwner).to.be.equal(await accounts3.getAddress());
        });
        it("user should be able to sell NFT minted to him by Admin. Buyer should be able to buy from user", async () => {
            const hash_04 = "some-hash-044";
            const nftId = 4;
            const seller = await accounts2.getAddress();
            const buyer = await accounts3.getAddress();
            const price = 1000;
            await vox.issueToken(seller, hash_04);
            await nft.setContractStatus(true);
            var approvalResult = await vox.connect(accounts2).approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.connect(accounts2).sellMyNFT(nftId, price);
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const sale = await nft.connect(accounts2).getSale(nftId);
            const pricee = sale[1];
            var approvallResult = await voxel.connect(accounts3).approve(nft.address, pricee);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var purchaseResult = await nft
                .connect(accounts3)
                .purchaseNFT(nftId, pricee);
            const newNftOwner = await vox.ownerOf(nftId);
            await expect(purchaseResult).to.emit(nft, "Sold");
            await expect(newNftOwner).to.be.equal(buyer);
        });
        it("admin should be able to put a batch of NFTs for sale and buyer should be able to buy them", async () => {
            const nftIds = [];
            const hashes = [];
            const iterations = 8;
            const recepient = await owner.getAddress();
            const prices = [];
            for (var i = 1; i <= iterations; i++) {
                const hash = `ipfs-hash-user1-${i}`;
                hashes.push(hash);
                prices.push(1000);
                nftIds.push(i);
            }
            await vox.issueBatch(recepient, hashes);
            await nft.setContractStatus(true);
            var approvalResult = await vox.setApprovalForAll(nft.address, true);
            await expect(approvalResult).to.emit(vox, "ApprovalForAll");
            var saleResult = await nft.sellNFTBatch(nftIds, prices, recepient);
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const totalPrice = prices.reduce((a, b) => a + b);
            var approvallResult = await voxel.connect(accounts2).approve(nft.address, totalPrice);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var purchaseResult = await nft
                .connect(accounts2)
                .purchaseNFTBatch(nftIds, totalPrice);
            await expect(purchaseResult).to.emit(nft, "Sold");
            for (var i = 1; i <= iterations; i++) {
                await expect(nft.getSale(nftIds[i])).to.be.reverted;
            }
        });
        it("mint nfts to user and users should be able to put a batch of NFTs for sale and buyer should be able to buy them", async () => {
            const hashes = [];
            const iterations = 8;
            const ownerOfNFTs = await accounts2.getAddress();
            const prices = [];
            for (var i = 1; i <= iterations; i++) {
                const hash = `ipfs-hash-user2-${i}`;
                hashes.push(hash);
                prices.push(1000);
            }
            const nftIds = await vox.callStatic.issueBatch(ownerOfNFTs, hashes);
            await vox.issueBatch(ownerOfNFTs, hashes);
            await nft.setContractStatus(true);
            var approvalResult = await vox.connect(accounts2).setApprovalForAll(nft.address, true);
            await expect(approvalResult).to.emit(vox, "ApprovalForAll");
            var saleResult = await nft.connect(accounts2).sellMyNFTBatch(nftIds, prices);
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const totalPrice = prices.reduce((a, b) => a + b);
            var approvallResult = await voxel.connect(accounts3).approve(nft.address, totalPrice);
            await expect(approvallResult).to.emit(voxel, "Approval");
            var purchaseResult = await nft
                .connect(accounts3)
                .purchaseNFTBatch(nftIds, totalPrice);
            await expect(purchaseResult).to.emit(nft, "Sold");
            for (var i = 1; i <= iterations; i++) {
                await expect(nft.getSale(nftIds[i])).to.be.reverted;
            }
        });
    });
});
