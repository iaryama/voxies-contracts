import { ethers } from "hardhat";
import dotenv from "dotenv";
dotenv.config();
async function deploy() {
    // We get the contract to deploy
    const NFTAuction = await ethers.getContractFactory("NftAuction");
    const nftAuction = await NFTAuction.deploy(
        process.env.VOXEL_ERC20_ADDRESS as string,
        process.env.Voxel_NFT_ENGINE_ADDRESS as string
    );
    console.log("NFTAuction contract deployed at:", nftAuction.address);
}

deploy();
