import { ethers } from "hardhat";
import dotenv from "dotenv";
dotenv.config();

async function deploy() {
    const VoxelDistribution = await ethers.getContractFactory("VoxelDistribution");
    const voxelDistribution = await VoxelDistribution.deploy(process.env.VOXEL_ERC20_ADDRESS as string);
    await voxelDistribution.deployed();
    console.log({
        voxelDistribution: voxelDistribution.address,
    });
}

deploy();
