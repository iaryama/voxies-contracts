import { ethers } from "hardhat";
import dotenv from "dotenv";
dotenv.config();
async function deploy() {
    // We get the contract to deploy
    const NFTSale = await ethers.getContractFactory("NFTSale");
    const nftSale = await NFTSale.deploy(
        process.env.VOXEL_ERC20_ADDRESS as string,
        "0xb1FAa64af8Ad9E139F0D265c5e4731bC6c9C9C7D",
        100
    );
    console.log("NFTSale contract deployed at:", nftSale.address);
}

deploy();
