import { ethers } from "hardhat";
import { IdleModelTest } from "../typechain";

const main = async () => {
    // Kovan testnet contract address
    const WBTC_ADDRESS = "0x577d296678535e4903d59a4c929b718e1d575e0a";
    const IDLETOKEN_ADDRESS = "0x0de23D3bc385a74E2196cfE827C8a640B8774B9f"; // IdleUSDC
    const GOV_TOKEN_ADDRESS = "0xab6bdb5ccf38ecda7a92d04e86f7c53eb72833df"; // IDLE
    const UNISWAPV2_ROUTERV2_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

    const [wallet, forge, reffral] = await ethers.getSigners();

    const IdleModelFactory = await ethers.getContractFactory("IdleModel");
    const idleModel = (await IdleModelFactory.deploy()) as IdleModelTest;

    console.log("idleModel.address :>> ", idleModel.address);

    // idleModel.initialize(
    //     forge.address,
    //     WBTC_ADDRESS,
    //     IDLETOKEN_ADDRESS,
    //     GOV_TOKEN_ADDRESS,
    //     UNISWAPV2_ROUTERV2_ADDRESS,
    //     reffral.address,
    // );
};
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
