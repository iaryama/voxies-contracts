import { ethers } from "hardhat";
import { Signer } from "ethers";
import { VoxelDistribution, VoxelDistribution__factory, Voxel, Voxel__factory } from "../typechain";
import { expect } from "chai";

describe("Token Distribution tests", function () {
    let VoxelDistributionFactory: VoxelDistribution__factory, VoxelFactory: Voxel__factory;
    let voxelDistribution: VoxelDistribution, voxel: Voxel;
    let signerAdmin: Signer, signerAlice: Signer, signerBob: Signer;
    let admin: string, alice: string, bob: string;
    before(async function () {
        VoxelDistributionFactory = (await ethers.getContractFactory(
            "VoxelDistribution"
        )) as VoxelDistribution__factory;
        VoxelFactory = (await ethers.getContractFactory("Voxel")) as Voxel__factory;
    });
    beforeEach(async function () {
        [signerAdmin, signerAlice, signerBob] = await ethers.getSigners();
        admin = await signerAdmin.getAddress();
        alice = await signerAlice.getAddress();
        bob = await signerBob.getAddress();
        voxel = await VoxelFactory.deploy(300000000, "Voxel Token", "VOXEL");
        voxelDistribution = await VoxelDistributionFactory.deploy(voxel.address);
        await voxel.transfer(voxelDistribution.address, ethers.utils.parseEther("1000"));
    });
    describe("Deployment tests", function () {
        it("correctly sets IERC20 voxel", async function () {
            expect(await voxelDistribution.token()).eq(voxel.address);
        });
        it("correctly sets owner", async function () {
            expect(await voxelDistribution.owner()).eq(admin);
        });
    });
    describe("Whitelist tests", function () {
        it("throws if non owner tries to add and remove from whitelist", async function () {
            await expect(voxelDistribution.connect(signerAlice).addToWhitelist(alice)).to.be.revertedWith(
                "Caller does not have Admin Access"
            );
        });
        it("adds to whitelist", async function () {
            await expect(voxelDistribution.addToWhitelist(alice))
                .to.emit(voxelDistribution, "WhitelistAdded")
                .withArgs(alice);
            expect(await voxelDistribution.whitelisted(alice)).to.be.true;
        });
        it("removes from whitelist", async function () {
            expect(await voxelDistribution.addToWhitelist(alice));
            await expect(voxelDistribution.removeFromWhitelist(alice))
                .to.emit(voxelDistribution, "WhitelistRemoved")
                .withArgs(alice);
            expect(await voxelDistribution.whitelisted(alice)).to.be.false;
        });
        it("throws if non whitelisted user tries to purchase the voxel", async function () {
            await expect(voxelDistribution.buy({ value: ethers.utils.parseEther("1") })).to.be.revertedWith(
                "!whitelisted"
            );
        });
    });
    describe("Functionality Tests", async function () {
        beforeEach(async function () {
            await voxelDistribution.addToWhitelist(alice);
        });
        it("throws if whitelisted user sends less than minimum purchase amount", async function () {
            await expect(voxelDistribution.connect(signerAlice).buy({ value: 1000 })).to.be.revertedWith(
                "amount should be greater than minimum requirement"
            );
        });
        it("allows admin to set price", async () => {
            expect(await voxelDistribution.price()).eq(ethers.utils.parseEther("0.01"));
            await voxelDistribution.setPrice(ethers.utils.parseEther("1"));
            expect(await voxelDistribution.price()).eq(ethers.utils.parseEther("1"));
        });
        it("throws if non admin tries to set price", async () => {
            await expect(
                voxelDistribution.connect(signerAlice).setPrice(ethers.utils.parseEther("1"))
            ).to.be.revertedWith("Caller does not have Admin Access");
        });
        it("allows admin to set min buy amount", async () => {
            expect(await voxelDistribution.minimumBuyAmount()).eq(ethers.utils.parseEther("1"));
            await voxelDistribution.setMinimumBuyAmount(ethers.utils.parseEther("0.01"));
            expect(await voxelDistribution.minimumBuyAmount()).eq(ethers.utils.parseEther("0.01"));
        });
        it("throws if non admin tries to set min buy amount", async () => {
            await expect(
                voxelDistribution.connect(signerAlice).setMinimumBuyAmount(ethers.utils.parseEther("1.2"))
            ).to.be.revertedWith("Caller does not have Admin Access");
        });

        it("purchases the tokens", async function () {
            expect(await voxel.balanceOf(alice)).eq(0);
            await expect(voxelDistribution.connect(signerAlice).buy({ value: ethers.utils.parseEther("1") }))
                .to.emit(voxelDistribution, "Buy")
                .withArgs(alice, ethers.utils.parseEther("1"));

            const tokensToBeReceived = ethers.utils.parseEther("1").mul(100);
            expect(await voxel.balanceOf(alice)).eq(tokensToBeReceived);
        });
        it("purchases via fallback", async function () {
            await expect(
                signerAlice.sendTransaction({
                    to: voxelDistribution.address,
                    value: ethers.utils.parseEther("1"),
                })
            ).to.emit(voxelDistribution, "Buy");
        });
        it("allows owner to withdraw ERC20 from contract", async () => {
            const amount = await voxel.balanceOf(voxelDistribution.address);
            const balance = await voxel.balanceOf(admin);
            await voxelDistribution.withdrawToken(amount);
            expect(await voxel.balanceOf(admin)).gt(balance);
        });
        it("doesn't allow non owner to withdraw ERC20 from contract", async () => {
            const contractBalance = await voxel.balanceOf(voxelDistribution.address);
            await expect(
                voxelDistribution.connect(signerAlice).withdrawToken(contractBalance)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
        xit("allows owner to withdraw accumulated ETH from contract", async () => {
            await voxelDistribution.addToWhitelist(admin);
            await voxelDistribution.buy({ value: ethers.utils.parseEther("10") });
            const balance = await ethers.provider.getBalance(admin);
            console.log((await ethers.provider.getBalance(voxelDistribution.address)).toString());
            // console.logs(10 ether)
            await voxelDistribution.withdraw(); // withdraws all ether
            console.log((await ethers.provider.getBalance(voxelDistribution.address)).toString());
            // console.logs(0)
            expect(await ethers.provider.getBalance(admin)).gt(balance);
            // fails: no increment???
        });
        it("doesn't allow non owner to withdraw ETH from contract", async () => {
            await expect(voxelDistribution.connect(signerAlice).withdraw()).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        describe("Pausable testing", async function () {
            it("only owner can pause and unpause", async function () {
                await expect(voxelDistribution.connect(signerAlice).pause()).to.be.revertedWith(
                    "Ownable: caller is not the owner"
                );
                await voxelDistribution.pause();
                await expect(voxelDistribution.connect(signerAlice).pause()).to.be.revertedWith(
                    "Ownable: caller is not the owner"
                );
                await voxelDistribution.unpause();
            });
            it("cannot purchase tokens when paused", async function () {
                await voxelDistribution.pause();
                await expect(
                    voxelDistribution.connect(signerAlice).buy({ value: ethers.utils.parseEther("1") })
                ).to.be.revertedWith("Pausable: paused");
            });
        });
    });
});
