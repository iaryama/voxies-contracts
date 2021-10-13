import { ethers } from "hardhat";
import { Signer } from "ethers";
import { Voxel, Voxel__factory, Rewards, Rewards__factory, NFT, NFT__factory } from "../typechain";
import { expect } from "chai";

describe("Rewards test", () => {
    let bomb: Voxel, rewards: Rewards, nft: NFT;
    let BOMB: Voxel__factory, REWARDS: Rewards__factory, NFTFactory: NFT__factory;
    let adminSigner: Signer, aliceSigner: Signer, bobSigner: Signer;
    let admin: string, alice: string, bob: string;
    before(async () => {
        BOMB = (await ethers.getContractFactory("Voxel")) as Voxel__factory;
        REWARDS = (await ethers.getContractFactory("Rewards")) as Rewards__factory;
        NFTFactory = (await ethers.getContractFactory("NFT")) as NFT__factory;
        [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();
        admin = await adminSigner.getAddress();
        alice = await aliceSigner.getAddress();
        bob = await bobSigner.getAddress();
    });
    beforeEach(async () => {
        bomb = await BOMB.deploy();
        rewards = await REWARDS.deploy();
        nft = await NFTFactory.deploy(10);
    });
    describe("Deposit & Reward tests", async () => {
        beforeEach(async () => {
            await bomb.approve(rewards.address, 100);
            await nft.setApprovalForAll(rewards.address, true);
        });
        it("allows owner to deposit ERC20", async () => {
            await expect(rewards.depositERC20(bomb.address, 100))
                .to.emit(rewards, "DepositedERC20")
                .withArgs(admin, bomb.address, 100);
        });
        it("does not allow non owner to deposit ERC20", async () => {
            await expect(rewards.connect(aliceSigner).depositERC20(bomb.address, 100)).to.be.reverted;
        });
        it("allows owner to deposit NFTs", async () => {
            expect(await nft.balanceOf(admin)).eq(10);
            await rewards.depositNFTs(nft.address, [1, 2, 3]);
            expect(await nft.balanceOf(admin)).eq(7);
        });
        it("does not allow non owner to deposit NFTs", async () => {
            await expect(rewards.connect(aliceSigner).depositNFTs(nft.address, [1, 2, 3])).to.be.reverted;
        });
        it("rewards in ERC20", async () => {
            expect(await bomb.balanceOf(alice)).eq(0);
            expect(await bomb.balanceOf(bob)).eq(0);
            await rewards.depositERC20(bomb.address, 100);
            await rewards.rewardinERC20(bomb.address, [alice, bob], [50, 50]);
            expect(await bomb.balanceOf(alice)).eq(50);
            expect(await bomb.balanceOf(bob)).eq(50);
        });
        it("throws if not enough ERC20 in contract", async () => {
            await expect(rewards.rewardinERC20(bomb.address, [alice, bob], [50, 50])).to.be.reverted;
        });
        it("throws if non owner calls rewardinERC20", async () => {
            await rewards.depositERC20(bomb.address, 100);
            await expect(rewards.connect(aliceSigner).rewardinERC20(bomb.address, [alice, bob], [50, 50])).to
                .be.reverted;
        });
        it("throws if winners length != amounts length", async () => {
            await rewards.depositERC20(bomb.address, 100);
            await expect(rewards.rewardinERC20(bomb.address, [alice, bob], [100])).to.be.reverted;
        });
        it("rewards in NFTs", async () => {
            expect(await nft.balanceOf(alice)).eq(0);
            expect(await nft.balanceOf(bob)).eq(0);
            await rewards.depositNFTs(nft.address, [1, 2, 3, 4]);
            await rewards.rewardinNFTs(nft.address, [alice, bob], [1, 2]);
            expect(await nft.balanceOf(alice)).eq(1);
            expect(await nft.balanceOf(bob)).eq(1);
        });
        it("throws if not enough NFT in contract", async () => {
            await expect(rewards.rewardinNFTs(nft.address, [alice, bob], [1, 2])).to.be.reverted;
        });
        it("throws if non owner calls rewardinNFTs", async () => {
            await rewards.depositNFTs(nft.address, [1, 2]);
            await expect(rewards.connect(aliceSigner).rewardinNFTs(bomb.address, [alice, bob], [1, 2])).to.be
                .reverted;
        });
        it("throws if winners length != tokenIds length", async () => {
            await rewards.depositNFTs(nft.address, [1, 2]);
            await expect(rewards.rewardinERC20(bomb.address, [alice, bob], [2])).to.be.reverted;
        });
    });
});
