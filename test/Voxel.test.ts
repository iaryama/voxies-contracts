import { ethers } from "hardhat";
import { expect } from "chai";
import { Voxel, Voxel__factory } from "../typechain";
import { Signer } from "ethers";

describe("Voxel token tests", () => {
    let voxel: Voxel, voxelFactory: Voxel__factory;
    let adminSigner: Signer, aliceSigner: Signer, bobSigner: Signer;
    let admin: string, alice: string, bob: string;
    before(async () => {
        voxelFactory = await ethers.getContractFactory("Voxel");
    });
    beforeEach(async () => {
        voxel = await voxelFactory.deploy();
        [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();
        admin = await adminSigner.getAddress();
        alice = await aliceSigner.getAddress();
        bob = await bobSigner.getAddress();
    });
    it("sets correct token name", async () => {
        expect(await voxel.name()).eq("Voxel Token");
    });
    it("sets correct token symbol", async () => {
        expect(await voxel.symbol()).eq("VXL");
    });
    it("mints on deployment", async () => {
        expect(await voxel.balanceOf(admin)).eq(ethers.utils.parseEther("1000000"));
    });
    it("transfers to other address", async () => {
        await expect(voxel.transfer(alice, 1000)).to.emit(voxel, "Transfer").withArgs(admin, alice, 1000);
    });
    it("doesn't allow to transfer if insufficient balance", async () => {
        await expect(voxel.connect(aliceSigner).transfer(bob, 1000)).to.be.reverted;
    });
    it("doesn't allow transferring to 0 address", async () => {
        await expect(voxel.transfer(ethers.constants.AddressZero, 1000)).to.be.reverted;
    });
    it("sets correct allowance", async () => {
        await voxel.approve(alice, 1000);
        expect(await voxel.allowance(admin, alice)).eq(1000);
    });
    it("allows to transferFrom", async () => {
        await voxel.approve(alice, 1000);
        await voxel.connect(aliceSigner).transferFrom(admin, bob, 1000);
        expect(await voxel.balanceOf(bob)).eq(1000);
    });
    it("doesn't allow to transferFrom if insufficient allowance", async () => {
        await voxel.approve(alice, 1000);
        await expect(voxel.connect(aliceSigner).transferFrom(admin, bob, 1001)).to.be.reverted;
    });
});
