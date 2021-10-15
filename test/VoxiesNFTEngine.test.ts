import { ethers } from "hardhat";
import { expect } from "chai";
import { Signer } from "ethers";
import { VoxiesNFTEngine, VoxiesNFTEngine__factory } from "../typechain";

describe("VoxiesNFTEngine Test", async () => {
    let owner: Signer,
        accounts1: Signer,
        accounts2: Signer,
        accounts3: Signer,
        accounts4: Signer,
        accounts5: Signer,
        voxelEngine: VoxiesNFTEngine__factory,
        vox: VoxiesNFTEngine;

    beforeEach(async () => {
        voxelEngine = await ethers.getContractFactory("VoxiesNFTEngine");
        vox = await voxelEngine.deploy("VoxelNFT", "VOX");
        [owner, accounts1, accounts2, accounts3, accounts4, accounts5] = await ethers.getSigners();
    });
    it("should have correct name", async () => {
        const name = await vox.name();
        expect(name).to.be.equal("VoxelNFT");
    });
    it("should have correct symbol", async () => {
        expect(await vox.symbol()).eq("VOX");
    });
    describe("Access Tests", async () => {
        it("owner should be able to mint", async () => {
            const recepient = await accounts1.getAddress();
            const hash = "some-hash";
            const data = "some-uri";
            await expect(vox.issueToken(recepient, hash, data)).to.emit(vox, "Transfer");
            const nftOwner = await vox.ownerOf(1);
            expect(nftOwner).to.equal(recepient);
        });
        it("non-owner should not be able to mint", async () => {
            const recepient = await accounts1.getAddress();
            const hash = "some-hash";
            const data = "some-uri";
            await expect(vox.connect(accounts1).issueToken(recepient, hash, data)).to.be.revertedWith(
                "Caller does not have Admin Access"
            );
        });
        it("owner should be able to set admin", async () => {
            await expect(vox.setAdmin(await accounts1.getAddress(), true)).to.emit(vox, "AdminAccessSet");
            expect(await vox.isAdmin(await accounts1.getAddress())).to.be.equal(true);
        });
        it("non-owner should not be able to set admin", async () => {
            await expect(
                vox.connect(accounts1).setAdmin(await accounts1.getAddress(), true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
        it("owner should be able to revoke admin", async () => {
            await expect(await vox.setAdmin(await accounts1.getAddress(), false)).to.emit(
                vox,
                "AdminAccessSet"
            );
            expect(await vox.isAdmin(await accounts1.getAddress())).to.be.equal(false);
        });
    });
    describe("Functionality Tests", async () => {
        it("should not be able to mint NFT with same hash", async () => {
            const recepient = await accounts1.getAddress();
            const hash = "some-hash";
            const data = "some-uri";
            await expect(vox.connect(accounts1).issueToken(recepient, hash, data)).to.be.revertedWith(
                "Caller does not have Admin Access"
            );
        });
        it("nft-owner should be able to transfer NFT", async () => {
            const nftOwner = await accounts1.getAddress();
            const recepient = await accounts2.getAddress();
            const hash = "some-hash";
            const data = "some-uri";
            const nftId = await vox.callStatic.issueToken(nftOwner, hash, data);
            await vox.issueToken(nftOwner, hash, data);
            await expect(vox.connect(accounts1).transferFrom(nftOwner, recepient, nftId)).to.emit(
                vox,
                "Transfer"
            );
            const newOwner = await vox.ownerOf(nftId);
            expect(newOwner).to.be.equal(recepient);
        });
        it("non-nft-owner should not be able to transfer NFT", async () => {
            const user = await accounts3.getAddress();
            const recepient = await accounts5.getAddress();
            const nftId = 1;
            await expect(vox.connect(accounts3).transferFrom(user, recepient, nftId)).to.be.revertedWith(
                "ERC721: operator query for nonexistent token"
            );
        });
        it("nft-owner should be able to approve other addresses", async () => {
            const nftOwner = await accounts2.getAddress();
            const user = await accounts3.getAddress();
            const hash = "some-hash";
            const data = "some-uri";
            const nftId = 1;
            await vox.issueToken(nftOwner, hash, data);
            await expect(vox.connect(accounts2).approve(user, nftId)).to.emit(vox, "Approval");
            const approved = await vox.getApproved(nftId);
            expect(approved).to.be.equal(user);
        });
        it("approved should be able to transfer and burn NFT", async () => {
            const nftOwner = await accounts2.getAddress();
            const approved = await accounts3.getAddress();
            const recepient = await accounts3.getAddress();
            const hash = "some-hash";
            const data = "some-uri";
            const hashh = "some-hashh";
            const dataa = "some-urii";
            const nftId = await vox.callStatic.issueToken(nftOwner, hash, data);
            await vox.issueToken(nftOwner, hash, data);
            await vox.issueToken(approved, hashh, dataa);
            await vox.connect(accounts2).setApprovalForAll(approved, true);
            await expect(vox.connect(accounts3).transferFrom(nftOwner, recepient, nftId)).to.emit(
                vox,
                "Transfer"
            );
            const newOwner = await vox.ownerOf(nftId);
            expect(newOwner).to.be.equal(recepient);
            console.log(
                "Tokens held By User Before Burn ",
                (await vox.getHolderTokenIds(await accounts3.getAddress())).toString()
            );
            await vox.connect(accounts3).burn(nftId);
            console.log(
                "Tokens held By User After Burn ",
                (await vox.getHolderTokenIds(await accounts3.getAddress())).toString()
            );
        });
    });
});
