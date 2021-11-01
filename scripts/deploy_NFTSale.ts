import { ethers } from "hardhat";
import dotenv from "dotenv";
dotenv.config();
async function deploy() {
    // We get the contract to deploy
    const NFTSale = await ethers.getContractFactory("NFTSale");
    const nftSale = await NFTSale.deploy(process.env.Voxel_NFT_ENGINE_ADDRESS as string);
    console.log("NFTSale contract deployed at:", nftSale.address);
}

deploy();
