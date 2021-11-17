import { ethers } from "hardhat";
import { Signer, BigNumber } from "ethers";
import {
    Voxel,
    Voxel__factory,
    NFT,
    NFT__factory,
    Loan,
    Loan__factory,
    VoxiesNFTEngine__factory,
    VoxiesNFTEngine,
} from "../typechain";
import { expect } from "chai";

describe("Loaning Tests", async () => {
    let owner: Signer,
        accounts1: Signer,
        accounts2: Signer,
        accounts3: Signer,
        accounts4: Signer,
        accounts5: Signer,
        voxelFactory: Voxel__factory,
        voxel: Voxel,
        loanFactory: Loan__factory,
        loan: Loan,
        voxelEngine: VoxiesNFTEngine__factory,
        vox: VoxiesNFTEngine;

    beforeEach(async () => {
        voxelEngine = (await ethers.getContractFactory("VoxiesNFTEngine")) as VoxiesNFTEngine__factory;
        vox = await voxelEngine.deploy("VoxelNFT", "VOX");
        voxelFactory = (await ethers.getContractFactory("Voxel")) as Voxel__factory;
        voxel = await voxelFactory.deploy();
        loanFactory = (await ethers.getContractFactory("Loan")) as Loan__factory;
        loan = await loanFactory.deploy([], voxel.address);
        [owner, accounts1, accounts2, accounts3, accounts4, accounts5] = await ethers.getSigners();
        await expect(vox.addToWhitelist(loan.address));
    });
    describe("Access Tests", async () => {
        it("owner should be able to add allowed NFT", async () => {
            await expect(loan.updateAllowedNFT(voxel.address, true));
        });
        it("only owner should be able to add allowed NFT", async () => {
            await expect(loan.connect(accounts1).updateAllowedNFT(voxel.address, true)).to.be.revertedWith(
                "Caller does not have Admin Access"
            );
        });
    });

    // ERC721: owner query for nonexistent token
    //ERC721: transfer caller is not owner nor approved
    //Contract Address is not whitelisted'

    describe("Functionality Tests", async () => {
        let nftIds: BigNumber[];
        beforeEach(async () => {
            const nftOwner = await accounts1.getAddress();
            await expect(loan.updateAllowedNFT(vox.address, true));
            const hash = "some-hash";
            nftIds = [];
            const hashes = [];
            const iterations = 10;
            for (var i = 1; i <= iterations; i++) {
                const hash = `ipfs-hash-user1-${i}`;
                hashes.push(hash);
                const nftId = await vox.callStatic.issueToken(nftOwner, hash);
                await vox.issueToken(nftOwner, hash);
                await vox.connect(accounts1).approve(loan.address, nftId);
                nftIds.push(nftId);
            }
        });
        it("only nft owner can create loanable bundle", async () => {
            await expect(
                loan.connect(accounts2).createLoanableItem(vox.address, nftIds, 1000, 30, 604800)
            ).to.be.revertedWith("Sender is not the owner of given NFT");
        });
        it("loaner Should be able to list loan item", async () => {
            const ownerAddress = await accounts1.getAddress();
            const loanId = await loan
                .connect(accounts1)
                .callStatic.createLoanableItem(vox.address, nftIds, 1000, 30, 604800);
            await expect(loan.connect(accounts1).createLoanableItem(vox.address, nftIds, 1000, 30, 604800))
                .to.emit(loan, "LoanableItemCreated")
                .withArgs(ownerAddress, nftIds, loanId);
            console.log(loanId);
        });
        it("revert on nft use for second loan bundle", async () => {
            await expect(
                loan.connect(accounts1).createLoanableItem(vox.address, nftIds, 1000, 30, 604800)
            ).to.emit(loan, "LoanableItemCreated");
            await expect(
                loan.connect(accounts1).createLoanableItem(vox.address, nftIds, 1000, 30, 604800)
            ).to.be.revertedWith("Loan Bundle exits with the given NFT");
        });
        it("nfts should be locked after listing loan item", async () => {
            const ownerAddress = await accounts1.getAddress();
            const bobAddress = await accounts2.getAddress();
            await expect(
                loan.connect(accounts1).createLoanableItem(vox.address, nftIds, 1000, 30, 604800)
            ).to.emit(loan, "LoanableItemCreated");
            console.log(nftIds[0].toBigInt());
            for (var i = 0; i < nftIds.length; i++) {
                await expect(
                    vox.connect(accounts1).transferFrom(ownerAddress, bobAddress, nftIds[i].toBigInt())
                ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
            }
        });
        it("loan contract should be the owner of locked nfts", async () => {
            await expect(
                loan.connect(accounts1).createLoanableItem(vox.address, nftIds, 1000, 30, 604800)
            ).to.emit(loan, "LoanableItemCreated");
            for (var i = 0; i < nftIds.length; i++) {
                await expect(await vox.ownerOf(nftIds[i].toBigInt())).to.be.equal(loan.address);
            }
        });
        it("loanee should be able to loan item", async () => {
            const loanId = await loan
                .connect(accounts1)
                .callStatic.createLoanableItem(vox.address, nftIds, 1000, 30, 604800);
            await expect(
                loan.connect(accounts1).createLoanableItem(vox.address, nftIds, 1000, 30, 604800)
            ).to.emit(loan, "LoanableItemCreated");
            await expect(await loan.connect(accounts2).issueLoan(loanId)).to.be.revertedWith(
                "ERC20: transfer amount exceeds allowance"
            );
        });
    });
    // it("should have correct token address", async () => {
    //     const tokenAddress = await loan.token;
    //     expect(tokenAddress).to.be.equal(voxel.address);
    // });
    // it("should have correct symbol", async () => {
    //     expect(await vox.symbol()).eq("VOX");
    // });
});
