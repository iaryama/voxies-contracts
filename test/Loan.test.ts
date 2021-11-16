import { ethers } from "hardhat";
import { Signer } from "ethers";
import { Voxel, Voxel__factory, NFT, NFT__factory, Loan, Loan__factory } from "../typechain";
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
        loan: Loan;

    beforeEach(async () => {
        voxelFactory = (await ethers.getContractFactory("Voxel")) as Voxel__factory;
        voxel = await voxelFactory.deploy();
        loanFactory = (await ethers.getContractFactory("Loan")) as Loan__factory;
        loan = await loanFactory.deploy([""], voxel.address);
        console.log(loan.address);
        console.log(voxel.address);
        [owner, accounts1, accounts2, accounts3, accounts4, accounts5] = await ethers.getSigners();
    });
    it("should have correct token address", async () => {
        const tokenAddress = await loan.token;
        expect(tokenAddress).to.be.equal(voxel.address);
    });
    // it("should have correct symbol", async () => {
    //     expect(await vox.symbol()).eq("VOX");
    // });
});
