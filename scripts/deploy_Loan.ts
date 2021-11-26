import { ethers, run } from "hardhat";
import { Loan, Loan__factory } from "../typechain";

async function deploy() {
    const Loan = (await ethers.getContractFactory("Loan")) as Loan__factory;
    const loan = await Loan.deploy(
        [process.env.Voxel_NFT_ENGINE_ADDRESS as string],
        process.env.VOXEL_ERC20_ADDRESS as string
    );
    console.log("Loan deployed at", loan.address);

    function delay(ms: number) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    await delay(10000);

    /**
     * Programmatic verification
     */
    try {
        // verify staking token
        await run("verify:verify", {
            address: loan.address,
            constructorArguments: [
                [process.env.Voxel_NFT_ENGINE_ADDRESS as string],
                process.env.VOXEL_ERC20_ADDRESS as string,
            ],
        });
    } catch (e: any) {
        console.error(`error in verifying: ${e.message}`);
    }
}
deploy();
