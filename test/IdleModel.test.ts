import hre, { ethers } from "hardhat";
import { expect, use } from "chai";
import { Contract } from "@ethersproject/contracts";
import { BigNumber } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IdleModelTest, IUniswapV2Router02, IERC20, IIdleToken } from "../typechain";

const toWei = ethers.utils.parseEther;
use(require("chai-bignumber")());

// get contract ABI via Etherscan API
const getVerifiedContractAt = async (address: string): Promise<Contract> => {
    // @ts-ignore
    return hre.ethers.getVerifiedContractAt(address);
};

describe("IdleModel", async function () {
    const signerAddr = "0x28c6c06298d514db089934071355e5743bf21d60"; // wBTC holder
    const idleHolderAddr = "0xEEe593DbddD91840D1Eb41ADd64f048AF3C45d21";

    const UNISWAPV2_ROUTERV2_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
    const IDLEWBTCV4_ADDRESS = "0x8C81121B15197fA0eEaEE1DC75533419DcfD3151";
    const IDLE_ADDRESS = "0x875773784af8135ea0ef43b5a374aad105c5d39e";
    const WBTC_ADDRESS = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599";
    const WETH9_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
    const WBTC_DECIMALS = 8;
    const WBTC_EXP_SCALE = BigNumber.from(10).pow(WBTC_DECIMALS);
    const amount = BigNumber.from(10).mul(WBTC_EXP_SCALE); // wBTC amount

    let wallet: SignerWithAddress;
    let forge: SignerWithAddress;
    let reffral: SignerWithAddress;

    let idleModel: IdleModelTest;
    let uniswapV2Router: IUniswapV2Router02;
    let idleWBTC: IIdleToken;
    let idle: IERC20;
    let wBTC: IERC20;
    let IdleModelTestFactory;
    before(async () => {
        [wallet, forge, reffral] = await ethers.getSigners();
        IdleModelTestFactory = await ethers.getContractFactory("IdleModelTest");
    });
    beforeEach(async function () {
        idleModel = (await IdleModelTestFactory.deploy()) as IdleModelTest;
        uniswapV2Router = (await getVerifiedContractAt(UNISWAPV2_ROUTERV2_ADDRESS)) as IUniswapV2Router02;
        idle = (await getVerifiedContractAt(IDLE_ADDRESS)) as IERC20;
        wBTC = (await getVerifiedContractAt(WBTC_ADDRESS)) as IERC20;
        idleWBTC = (await getVerifiedContractAt(IDLEWBTCV4_ADDRESS)) as IIdleToken;

        await idleModel.initialize(
            forge.address,
            WBTC_ADDRESS,
            IDLEWBTCV4_ADDRESS,
            IDLE_ADDRESS,
            UNISWAPV2_ROUTERV2_ADDRESS,
            reffral.address,
        );
        await wallet.sendTransaction({ to: signerAddr, value: toWei("10") }); // get some eth from a wallet
        await ethers.provider.send("hardhat_impersonateAccount", [signerAddr]);
    });
    afterEach(async () => {
        await hre.network.provider.request({
            method: "hardhat_reset",
            params: [
                {
                    forking: {
                        jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
                        blockNumber: parseInt(process.env.BLOCK_NUMBER),
                    },
                },
            ],
        });
    });

    it("get correct address", async () => {
        expect(await idleModel.idleToken()).to.eq(IDLEWBTCV4_ADDRESS);
        expect(await idleModel.forge()).to.eq(forge.address);
    });

    it("initial balance", async () => {
        expect(await idleModel.underlyingBalanceInModel()).to.eq(0);
        expect(await idleModel.underlyingBalanceWithInvestment()).to.eq(0);
    });

    const invest = async (signer, amount) => {
        await wBTC.connect(signer).transfer(idleModel.address, amount);
        await idleModel.invest();
    };

    it("invest: forge can invest assets to idleWBTC", async () => {
        expect(await idleModel.underlyingBalanceInModel()).to.eq(0);
        expect((await wBTC.balanceOf(signerAddr)).gt(amount)).to.be.true;

        const signer = ethers.provider.getSigner(signerAddr);
        await invest(signer, amount);
        // expect(await idleWBTC.balanceOf(idleModel.address)).to.be.gt(0);
        expect(await idleModel.underlyingBalanceInModel()).to.eq(0);
        expect(await idleModel.underlyingBalanceWithInvestment()).not.to.eq(0);
    });

    it("redeemUnderlying: redeem deposited asset", async () => {
        expect(await idleModel.underlyingBalanceWithInvestment()).to.eq(0);
        const signer = ethers.provider.getSigner(signerAddr);
        await invest(signer, amount);
        await idleModel.redeemUnderlying(amount, idleModel.address);
        const fee = amount.div(100); // idle fi withdraw fee 10% ??
        expect(await wBTC.balanceOf(idleModel.address)).to.be.gt(amount.sub(fee));
    });

    it("withdrawTo:only forge can withdraw", async () => {
        await expect(idleModel.withdrawTo(amount, forge.address)).to.be.revertedWith("MODEL : Only Forge");
    });

    it("withdrawTo:when enough amount in model", async () => {
        const amountToWithdraw = amount.div(10);
        const signer = ethers.provider.getSigner(signerAddr);
        await wBTC.connect(signer).transfer(idleModel.address, amount);
        const forgeSigner = ethers.provider.getSigner(forge.address);
        await idleModel.connect(forgeSigner).withdrawTo(amountToWithdraw, wallet.address);
        expect(await wBTC.balanceOf(wallet.address)).to.be.eq(amountToWithdraw);
        expect(await wBTC.balanceOf(idleModel.address)).to.be.eq(amount.sub(amountToWithdraw));
    });

    it("withdrawTo: when not enough amount in model", async () => {
        const amountToInvest = amount.div(10);
        const balanceInModel = amount.sub(amountToInvest);
        const signer = ethers.provider.getSigner(signerAddr);
        await invest(signer, amountToInvest);
        await wBTC.connect(signer).transfer(idleModel.address, balanceInModel);

        const forgeSigner = ethers.provider.getSigner(forge.address);
        await idleModel.connect(forgeSigner).withdrawTo(amount, wallet.address);
        // should be one of them because of rounding of solidity calculations
        expect(await wBTC.balanceOf(wallet.address)).to.satisfy((balance: BigNumber) => {
            if (balance.eq(amount) || balance.eq(amount.sub(1))) return true;
            else return false;
        });
    });

    it("claimGovToken: can claim IDLE", async () => {
        const signer = ethers.provider.getSigner(signerAddr);
        await invest(signer, amount);
        await idleModel.claimGovToken();
        expect(await idle.balanceOf(idleModel.address)).not.to.eq(0);
    });

    it("swapGovTokenToUnderlying:swap IDLE to WBTC via UniswapV2", async () => {
        const idleAmount = toWei("10");
        await ethers.provider.send("hardhat_impersonateAccount", [idleHolderAddr]);
        const holder = ethers.provider.getSigner(idleHolderAddr);

        // see https://uniswap.org/docs/v2/smart-contracts/library#getamountsout
        const path = [idle.address, WETH9_ADDRESS, WBTC_ADDRESS];
        const expectedAmountsOut = await uniswapV2Router.getAmountsOut(idleAmount, path);
        expect(expectedAmountsOut[2]).to.be.gt(0);

        await idle.connect(holder).transfer(idleModel.address, idleAmount);
        await idleModel.swapGovTokenToUnderlying();

        expect(await idle.balanceOf(idleModel.address)).to.eq(0);
        expect(await wBTC.balanceOf(idleModel.address)).to.eq(expectedAmountsOut[2]);
    });
});
