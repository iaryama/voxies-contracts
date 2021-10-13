import { ethers } from "hardhat";
import { Rewards__factory } from "../typechain";

async function deploy() {
    const Rewards = (await ethers.getContractFactory("Rewards")) as Rewards__factory;
    const rewards = await Rewards.deploy();
    console.log("Rewards deployed at", rewards.address);
}
deploy();
