import { ethers, run, artifacts } from "hardhat";
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

    try {
        if ((process.env.TRUSTED_FORWARDER_ADDRESS as string) != null) {
            const tokenArtifact = await artifacts.readArtifact("Loan");

            const loanToken = Loan.attach("0x716c0d8732b33a2a1E385B4a1Bdf75CdeCE96E56") as Loan;

            const receipt = await loanToken.setTrustedForwarder(
                process.env.TRUSTED_FORWARDER_ADDRESS as string
            );

            console.log(await receipt.wait());
        } else {
            console.error("Cannot setup trusted forwarder, please setup manually.");
        }
    } catch (e: any) {
        console.error(`error in setting up trusted forwarder: ${e.message}`);
    }
}
deploy();
