import { ethers } from "hardhat";
async function deploy() {
    // We get the contract to deploy
    const voxelEngine = await ethers.getContractFactory("VoxiesNFTEngine");
    const vox = await voxelEngine.deploy("VoxelNFT", "VOX");
    console.log("engine contract deployed at:", vox.address);
    const NFTSale = await ethers.getContractFactory("NFTSale");
    const nftSale = await NFTSale.deploy(vox.address);
}

deploy();
