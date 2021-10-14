import { ethers, waffle, web3 } from "hardhat";
import "@nomiclabs/hardhat-web3";
import { expect, use } from "chai";
import { Signer } from "ethers";
import { VoxiesNFTEngine, VoxiesNFTEngine__factory, NFTSale, NFTSale__factory } from "../typechain";

use(waffle.solidity);

describe("NFTSale Test", async () => {
    let owner: Signer,
        accounts1: Signer,
        accounts2: Signer,
        accounts3: Signer,
        voxelEngine: VoxiesNFTEngine__factory,
        vox: VoxiesNFTEngine,
        nftsale: NFTSale__factory,
        nft: NFTSale;

    beforeEach(async () => {
        voxelEngine = await ethers.getContractFactory("VoxiesNFTEngine");
        vox = await voxelEngine.deploy("VoxelNFT", "VOX");
        [owner, accounts1, accounts2, accounts3] = await ethers.getSigners();
        nftsale = await ethers.getContractFactory("NFTSale");
        nft = await nftsale.deploy(vox.address);
    });
    it("should have correct NFT address", async () => {
        const nftAddress = await nft.nftAddress();
        expect(nftAddress).to.be.equal(vox.address);
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
            const data_01 = "some-data";
            const hash_02 = "some-hash-02";
            const data_02 = "some-data-02";
            const hash_03 = "some-hash-03";
            const data_03 = "some-data-03";
            const result_01 = await vox.issueToken(recepient, hash_01, JSON.stringify(data_01));
            const result_02 = await vox.issueToken(recepient, hash_02, JSON.stringify(data_02));
            const result_03 = await vox.issueToken(recepient, hash_03, JSON.stringify(data_03));
            await expect(result_01).to.emit(vox, "Transfer");
            await expect(result_02).to.emit(vox, "Transfer");
            await expect(result_03).to.emit(vox, "Transfer");
            const nftOwner_01 = await vox.ownerOf(1);
            const nftOwner_02 = await vox.ownerOf(2);
            const nftOwner_03 = await vox.ownerOf(3);
            expect(nftOwner_01).to.be.equal(recepient);
            expect(nftOwner_02).to.be.equal(recepient);
            expect(nftOwner_03).to.be.equal(recepient);
        });
        it("non-admin should not be able to start sale", async () => {
            const nftId = 1;
            const price = 1000000000000000000n;
            await expect(
                nft.connect(accounts1).sellNFT(nftId, price, await accounts3.getAddress())
            ).to.be.revertedWith("Caller does not have Admin Access");
        });
        it("owner should not be able to start sale without granting approval", async () => {
            const nftId = 1;
            const price = 1000000000000000000n;
            await expect(nft.sellNFT(nftId, price, await accounts3.getAddress())).to.be.revertedWith(
                "Grant NFT approval to Sale Contract"
            );
        });
        it("owner should be able to start sale", async () => {
            const nftId = 1;
            const price = 1000000000000000000n;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const nftOwner = await vox.ownerOf(1);
            expect(nftOwner).to.be.equal(nft.address);
        });
        it("should be able to get sale using NFT ID", async () => {
            const nftId = 1;
            const price = 1000000000000000000n;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const nftOwner = await vox.ownerOf(1);
            expect(nftOwner).to.be.equal(nft.address);
            const sale = await nft.getSale(nftId);
            expect(sale[0]).to.be.equal(await accounts3.getAddress());
            expect(sale[1]).to.be.equal(1000000000000000000n);
        });
        it("should not be able to purchase if contract is inactive", async () => {
            const nftId = 1;
            const price = 1000000000000000000n;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const nftOwner = await vox.ownerOf(1);
            expect(nftOwner).to.be.equal(nft.address);
            const buyer = await accounts2.getAddress();
            const sale = await nft.connect(buyer).getSale(nftId);
            const pricee = sale[1];
            await expect(
                nft.connect(accounts2).purchaseNFT(nftId, { value: pricee.toString() })
            ).to.be.revertedWith("Contract Status in not Active");
        });
        it("should be able to purchase", async () => {
            await nft.setContractStatus(true);
            const nftId = 1;
            const price = 1000000000000000000n;
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, await accounts3.getAddress());
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const nftOwner = await vox.ownerOf(1);
            expect(nftOwner).to.be.equal(nft.address);
            const buyer = await accounts2.getAddress();
            const sale = await nft.connect(accounts2).getSale(nftId);
            const pricee = sale[1];
            var purchaseResult = await nft
                .connect(accounts2)
                .purchaseNFT(nftId, { value: pricee.toString() });
            const newNftOwner = await vox.ownerOf(nftId);
            await expect(purchaseResult).to.emit(nft, "Sold");
            expect(newNftOwner).to.be.equal(buyer);
        });
        it("owner be able to release", async () => {
            const nftId = 2;
            const price = 1000000000000000000n;
            await vox.approve(nft.address, nftId);
            await nft.sellNFT(nftId, price, await accounts3.getAddress());

            const buyer = await accounts2.getAddress();

            var purchaseResult = await nft.releaseNFT(nftId, buyer);

            await expect(purchaseResult).to.emit(nft, "Sold");

            const nftOwner = await vox.ownerOf(nftId);
            expect(nftOwner).to.be.equal(buyer);
        });
        it("owner should be able to cancel sale", async () => {
            const nftId = 3;
            const price = 1000000000000000000n;
            const nftOwner = await accounts3.getAddress();
            var approvalResult = await vox.approve(nft.address, nftId);
            await expect(approvalResult).to.emit(vox, "Approval");
            var saleResult = await nft.sellNFT(nftId, price, nftOwner);
            await expect(saleResult).to.emit(nft, "SaleAdded");
            const newNftOwner = await vox.ownerOf(nftId);
            expect(newNftOwner).to.be.equal(nft.address);
            var cancelledResult = await nft.cancelSale(nftId);
            await expect(cancelledResult).to.emit(nft, "SaleCancelled");
            const originalNftOwner = await vox.ownerOf(nftId);
            expect(originalNftOwner).to.be.equal(await owner.getAddress());
        });
    });
});
