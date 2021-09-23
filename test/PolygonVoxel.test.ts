import { ethers } from "hardhat";
import { expect } from "chai";
import { PolygonVoxel, PolygonVoxel__factory } from "../typechain";
import { Signer } from "ethers";

describe("PolygonVoxel token tests", () => {
    let voxel: PolygonVoxel, voxelFactory: PolygonVoxel__factory;
    let adminSigner: Signer, aliceSigner: Signer, bobSigner: Signer;
    let admin: string, alice: string, bob: string;
    before(async () => {
        voxelFactory = await ethers.getContractFactory("PolygonVoxel");
    });
    beforeEach(async () => {
        const childChainManagerProxy = ethers.constants.AddressZero;
        voxel = await voxelFactory.deploy(childChainManagerProxy);
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
    it("sets correct allowance", async () => {
        await voxel.approve(alice, 1000);
        expect(await voxel.allowance(admin, alice)).eq(1000);
    });
});
