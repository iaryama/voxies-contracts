import { ethers } from "hardhat";

async function deploy() {
    const Voxel = await ethers.getContractFactory("Voxel");
    const voxel = await Voxel.deploy();
    await voxel.deployed();
    const VoxelDistribution = await ethers.getContractFactory("VoxelDistribution");
    const voxelDistribution = await VoxelDistribution.deploy(voxel.address);
    await voxelDistribution.deployed();
    console.log({
        voxel: voxel.address,
        voxelDistribution: voxelDistribution.address,
    });
}

deploy();
