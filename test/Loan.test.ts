import { ethers, network } from "hardhat";
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
        vox: VoxiesNFTEngine,
        nftAddresses: string[];

    beforeEach(async () => {
        voxelEngine = (await ethers.getContractFactory("VoxiesNFTEngine")) as VoxiesNFTEngine__factory;
        vox = await voxelEngine.deploy("VoxelNFT", "VOX");
        voxelFactory = (await ethers.getContractFactory("Voxel")) as Voxel__factory;
        voxel = await voxelFactory.deploy();
        loanFactory = (await ethers.getContractFactory("Loan")) as Loan__factory;
        loan = await loanFactory.deploy([], voxel.address);
        [owner, accounts1, accounts2, accounts3, accounts4, accounts5] = await ethers.getSigners();
        vox.addToWhitelist(loan.address);
    });
    describe("Access Tests", async () => {
        it("owner should be able to add allowed NFT", async () => {
            expect(loan.allowNFTContract(voxel.address, true));
        });
        it("only owner should be able to add allowed NFT", async () => {
            expect(loan.connect(accounts1).allowNFTContract(voxel.address, true)).to.be.revertedWith(
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
            expect(loan.allowNFTContract(vox.address, true));
            const hash = "some-hash";
            nftIds = [];
            nftAddresses = [];
            const hashes = [];
            const iterations = 10;
            for (var i = 1; i <= iterations; i++) {
                const hash = `ipfs-hash-user1-${i}`;
                hashes.push(hash);
                const nftId = await vox.callStatic.issueToken(nftOwner, hash);
                await vox.issueToken(nftOwner, hash);
                await vox.connect(accounts1).approve(loan.address, nftId);
                nftIds.push(nftId);
                nftAddresses.push(vox.address);
            }
        });
        it("only nft owner can create loanable bundle", async () => {
            expect(
                loan.connect(accounts2).createLoanableItem(nftAddresses, nftIds, 1000, 30, 604800)
            ).to.be.revertedWith("Sender is not the owner of given NFT");
        });
        it("should not be able to create loan with timePeriod less than minimum Loan Period", async () => {
            expect(
                loan.connect(accounts1).createLoanableItem(nftAddresses, nftIds, 1000, 30, 100)
            ).to.be.revertedWith("Incorrect loan time period specified");
        });
        it("should not be able to create loan with timePeriod greater than maximum Loan Period", async () => {
            expect(
                loan.connect(accounts1).createLoanableItem(nftAddresses, nftIds, 1000, 30, 605800)
            ).to.be.revertedWith("Incorrect loan time period specified");
        });
        it("loaner Should be able to list loan item", async () => {
            const ownerAddress = await accounts1.getAddress();
            const loanId = await loan
                .connect(accounts1)
                .callStatic.createLoanableItem(nftAddresses, nftIds, 1000, 30, 604800);
            expect(loan.connect(accounts1).createLoanableItem(nftAddresses, nftIds, 1000, 30, 604800))
                .to.emit(loan, "LoanableItemCreated")
                .withArgs(ownerAddress, nftAddresses, nftIds, loanId);
        });
        describe("Loaning, Rewarding Listed Loan Items", async () => {
            let nftIds2: BigNumber[],
                loanId: BigNumber,
                ownerAddress: string,
                account2Address: string,
                account1Address: string,
                account3Address: string;
            const createLoanableItemParams = async (
                account: Signer,
                _nftIds: BigNumber[],
                upfrontFee: BigNumber,
                percentageRewards: BigNumber,
                timePeriod: BigNumber
            ) => {
                // nftAddresses = [];
                // for (var i = 0; i < nftIds2.length; i++) {
                //     nftAddresses.push(vox.address);
                // }
                const _loanId = await loan
                    .connect(account)
                    .callStatic.createLoanableItem(
                        nftAddresses,
                        _nftIds,
                        upfrontFee,
                        percentageRewards,
                        timePeriod
                    );
                expect(
                    loan
                        .connect(account)
                        .createLoanableItem(nftAddresses, _nftIds, upfrontFee, percentageRewards, timePeriod)
                )
                    .to.emit(loan, "LoanableItemCreated")
                    .withArgs(await account.getAddress(), nftAddresses, _nftIds, _loanId);
                return _loanId;
            };
            beforeEach(async () => {
                const iterations = 10;
                ownerAddress = await owner.getAddress();
                account1Address = await accounts1.getAddress();
                account2Address = await accounts2.getAddress();
                account3Address = await accounts3.getAddress();
                nftIds2 = [];
                for (var i = 1; i <= iterations; i++) {
                    const hash = `ipfs-hash-user1-${i + 20}`;
                    const nftId = await vox.callStatic.issueToken(account3Address, hash);
                    await vox.issueToken(account3Address, hash);
                    await vox.connect(accounts3).approve(loan.address, nftId);
                    nftIds2.push(nftId);
                }
                loanId = await loan
                    .connect(accounts1)
                    .callStatic.createLoanableItem(nftAddresses, nftIds, 1000, 30, 604800);
                await expect(
                    loan.connect(accounts1).createLoanableItem(nftAddresses, nftIds, 1000, 30, 604800)
                )
                    .to.emit(loan, "LoanableItemCreated")
                    .withArgs(account1Address, nftAddresses, nftIds, loanId);
            });
            it("check if deployer has access", async () => {
                var ret = await loan.hasAccessToNFT(vox.address, nftIds[0], await owner.getAddress());
                expect(ret).to.equal(false);
            });
            it("check if account1 has access", async () => {
                var ret = await loan
                    .connect(accounts1)
                    .hasAccessToNFT(vox.address, nftIds[0], await accounts1.getAddress());
                expect(ret).to.equal(true);
            });
            it("revert on nft use for second loan bundle", async () => {
                expect(
                    loan.connect(accounts1).createLoanableItem(nftAddresses, nftIds, 1000, 30, 604800)
                ).to.be.revertedWith("Loan Bundle exits with the given NFT");
            });
            it("nfts should be locked/non transferable after listing loan item", async () => {
                for (var i = 0; i < nftIds.length; i++) {
                    expect(
                        vox
                            .connect(accounts1)
                            .transferFrom(account1Address, account2Address, nftIds[i].toBigInt())
                    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
                }
            });
            it("loan contract should be the owner of locked nfts", async () => {
                for (var i = 0; i < nftIds.length; i++) {
                    expect(await vox.ownerOf(nftIds[i].toBigInt())).to.be.equal(loan.address);
                }
            });
            it("listed loanable item should not be active", async () => {
                const loanItem = await loan.loanItems(loanId);
                expect(loanItem.isActive).to.be.equal(false);
            });
            it("loanee should be able to loan item", async () => {
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(loanId)).to.emit(loan, "LoanIssued");
                const loanItem = await loan.loanItems(loanId);
                expect(loanItem.loanee).to.be.equal(account2Address);
            });
            it("should not allow to issue an active loan", async () => {
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(loanId)).to.emit(loan, "LoanIssued");
                const loanItem = await loan.loanItems(loanId);
                expect(loanItem.loanee).to.be.equal(account2Address);
                expect(loan.connect(accounts3).loanItem(loanId)).to.be.revertedWith(
                    "Loan Item is already loaned"
                );
            });
            it("check if loanee has access", async () => {
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(loanId)).to.emit(loan, "LoanIssued");
                const loanItem = await loan.loanItems(loanId);
                expect(loanItem.loanee).to.be.equal(account2Address);
                expect(loan.connect(accounts3).loanItem(loanId)).to.be.revertedWith(
                    "Loan Item is already loaned"
                );
                var ret = await loan
                    .connect(accounts1)
                    .hasAccessToNFT(vox.address, nftIds[0], await accounts2.getAddress());
                expect(ret).to.equal(true);
                var ret = await loan
                    .connect(accounts1)
                    .hasAccessToNFT(vox.address, nftIds[0], await accounts1.getAddress());
                expect(ret).to.equal(false);
            });
            it("only owner should be able to add rewards on NFTs", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(10));
                }
                await expect(
                    loan.connect(accounts1).addRewardsForNFT(nftAddresses, nftIds, amounts)
                ).to.be.revertedWith("Caller does not have Admin Access");
            });
            it("owner should be able to add rewards on NFTs", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(10));
                }
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 1000);
                await expect(loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds, amounts))
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds, amounts);
                expect((await voxel.balanceOf(loan.address)).toNumber()).to.be.equal(100);
            });
            it("rewards should be directly sent to owner for an inactive loan.", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(10));
                }
                // await voxel.connect(owner).transfer(account2Address, 1000);
                // await voxel.connect(accounts2).approve(loan.address, 1000);
                // expect(loan.connect(accounts2).loanItem(loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 1000);
                await expect(loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds, amounts))
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds, amounts);
                expect((await voxel.balanceOf(account1Address)).toNumber()).to.be.equal(100);
            });
            it("Add rewards for nfts part of multiple loan bundles", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(10));
                }
                const _loanId = await createLoanableItemParams(
                    accounts3,
                    nftIds2,
                    BigNumber.from(50),
                    BigNumber.from(13),
                    BigNumber.from(5800)
                );
                await voxel.connect(owner).transfer(account2Address, 10000);
                await voxel.connect(accounts2).approve(loan.address, 10000);
                await expect(loan.connect(accounts2).loanItem(loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 10000);
                expect(loan.connect(accounts2).loanItem(_loanId)).to.emit(loan, "LoanIssued");
                await expect(
                    loan
                        .connect(owner)
                        .addRewardsForNFT(
                            nftAddresses.concat(nftAddresses),
                            nftIds.concat(nftIds2),
                            amounts.concat(amounts)
                        )
                )
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds, amounts);
                const _loan2Rewards = await (await loan.loanItems(_loanId)).totalRewards;
                const _loan1Rewards = await (await loan.loanItems(loanId)).totalRewards;
                expect(_loan2Rewards.toNumber()).to.equal(100);
                expect(_loan1Rewards.toNumber()).to.equal(100);
            });
            it("loaner can claim rewards", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(1));
                }
                const _loanId = await createLoanableItemParams(
                    accounts3,
                    nftIds2,
                    BigNumber.from(50),
                    BigNumber.from(13),
                    BigNumber.from(5800)
                );
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                expect(loan.connect(accounts2).loanItem(_loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 1000);
                await expect(loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds2, amounts))
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds2, amounts);
                await expect(loan.connect(accounts3).claimRewards(_loanId)).to.emit(loan, "RewardsClaimed");
                const totalRewards = await (await loan.loanItems(_loanId)).totalRewards;
                expect(totalRewards.toNumber()).to.be.equal(10);
                expect((await voxel.balanceOf(account3Address)).toNumber()).to.be.equal(51);
                expect((await voxel.balanceOf(account2Address)).toNumber()).to.be.equal(950);
            });
            it("loanee can claim rewards", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(1));
                }
                const _loanId = await createLoanableItemParams(
                    accounts3,
                    nftIds2,
                    BigNumber.from(50),
                    BigNumber.from(13),
                    BigNumber.from(5800)
                );
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(_loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 1000);
                await expect(loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds2, amounts))
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds2, amounts);
                await expect(loan.connect(accounts2).claimRewards(_loanId)).to.emit(loan, "RewardsClaimed");
                const totalRewards = await (await loan.loanItems(_loanId)).totalRewards;
                expect(totalRewards.toNumber()).to.be.equal(10);
                expect((await voxel.balanceOf(account3Address)).toNumber()).to.be.equal(50);
                expect((await voxel.balanceOf(account2Address)).toNumber()).to.be.equal(959);
            });
            it("loaner cannot claim NFTs over active loan period", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(1));
                }
                const _loanId = await createLoanableItemParams(
                    accounts3,
                    nftIds2,
                    BigNumber.from(50),
                    BigNumber.from(13),
                    BigNumber.from(5800)
                );
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(_loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 1000);
                await expect(loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds2, amounts))
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds2, amounts);
                await expect(loan.connect(accounts2).claimRewards(_loanId)).to.emit(loan, "RewardsClaimed");
                const totalRewards = await (await loan.loanItems(_loanId)).totalRewards;
                expect(totalRewards.toNumber()).to.be.equal(10);
                expect((await voxel.balanceOf(account3Address)).toNumber()).to.be.equal(50);
                expect((await voxel.balanceOf(account2Address)).toNumber()).to.be.equal(959);
                // await network.provider.send("evm_increaseTime", [5800]);
                // await network.provider.send("evm_mine");
                expect(loan.connect(accounts3).claimNFTs(_loanId)).to.be.revertedWith(
                    "Loan period is still active"
                );
            });
            it("loaner can claim NFTs after active loan period", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(1));
                }
                const _loanId = await createLoanableItemParams(
                    accounts3,
                    nftIds2,
                    BigNumber.from(50),
                    BigNumber.from(13),
                    BigNumber.from(5800)
                );
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(_loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 1000);
                await expect(loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds2, amounts))
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds2, amounts);
                // expect(loan.connect(accounts2).claimRewards(_loanId)).to.emit(loan, "RewardsClaimed");
                await network.provider.send("evm_increaseTime", [5800]);
                await network.provider.send("evm_mine");
                await loan.connect(accounts3).claimNFTs(_loanId);
                for (i = 0; i < nftIds2.length; i++) {
                    expect((await vox.ownerOf(nftIds2[i])).toString()).to.be.equal(
                        account3Address.toString()
                    );
                }
                const totalRewards = await (await loan.loanItems(_loanId)).totalRewards;
                expect(totalRewards.toNumber()).to.be.equal(10);
                expect((await voxel.balanceOf(account3Address)).toNumber()).to.be.equal(50);
                expect((await voxel.balanceOf(account2Address)).toNumber()).to.be.equal(950);
            });
            it("loaner cannot loan deleted loan", async () => {
                const iterations = 10;
                let amounts = [];
                for (var i = 1; i <= iterations; i++) {
                    amounts.push(BigNumber.from(1));
                }
                const _loanId = await createLoanableItemParams(
                    accounts3,
                    nftIds2,
                    BigNumber.from(50),
                    BigNumber.from(13),
                    BigNumber.from(5800)
                );
                await voxel.connect(owner).transfer(account2Address, 1000);
                await voxel.connect(accounts2).approve(loan.address, 1000);
                await expect(loan.connect(accounts2).loanItem(_loanId)).to.emit(loan, "LoanIssued");
                await voxel.connect(owner).approve(loan.address, 1000);
                await expect(loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds2, amounts))
                    .to.emit(loan, "RewardsAdded")
                    .withArgs(nftAddresses, nftIds2, amounts);
                // expect(loan.connect(accounts2).claimRewards(_loanId)).to.emit(loan, "RewardsClaimed");
                await network.provider.send("evm_increaseTime", [5800]);
                await network.provider.send("evm_mine");
                await loan.connect(accounts3).claimNFTs(_loanId);
                for (i = 0; i < nftIds2.length; i++) {
                    expect((await vox.ownerOf(nftIds2[i])).toString()).to.be.equal(
                        account3Address.toString()
                    );
                }
                const totalRewards = await (await loan.loanItems(_loanId)).totalRewards;
                expect(totalRewards.toNumber()).to.be.equal(10);
                expect((await voxel.balanceOf(account3Address)).toNumber()).to.be.equal(50);
                expect((await voxel.balanceOf(account2Address)).toNumber()).to.be.equal(950);
                expect(loan.connect(accounts2).loanItem(_loanId)).to.be.revertedWith(
                    "Loan Item is already loaned"
                );
                expect(
                    loan.connect(owner).addRewardsForNFT(nftAddresses, nftIds2, amounts)
                ).to.be.revertedWith("Loanable Item Not Found");
            });
        });
    });
});
