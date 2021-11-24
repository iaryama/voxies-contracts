import { ethers } from "hardhat";
import { Loan__factory } from "../typechain";

async function deploy() {
    const Loan = (await ethers.getContractFactory("Loan")) as Loan__factory;
    const loan = await Loan.deploy(
        [process.env.Voxel_NFT_ENGINE_ADDRESS as string],
        process.env.VOXEL_ERC20_ADDRESS as string
    );
    console.log("Loan deployed at", loan.address);
}
deploy();
