import { ethers } from "hardhat";

async function deploy() {
    const Voxel = await ethers.getContractFactory("Voxel");
    const voxel = await Voxel.deploy(300000000, "Voxel Token", "VOXEL");
    await voxel.deployed();
    console.log({
        voxel: voxel.address,
    });
}

deploy();
