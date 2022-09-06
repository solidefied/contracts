const { expect } = require("chai");
const { ethers } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");

describe("Single NFT Sale V2", () => {
    var acc1;
    var acc2;
    var acc3;
    var acc4;
    var usdt;

    before("Deployment of USDT token", async () => {
        [acc1, acc2, acc3, acc4] = await ethers.getSigners();
        const token1Contract = await ethers.getContractFactory("Token");
        usdt = await token1Contract.deploy("USDT", "USDT");
        await usdt.deployed();
    });

    it("check deployed token's details", async () => {
        expect(await usdt.name()).to.equal("USDT");
        expect(await usdt.symbol()).to.equal("USDT");
        expect(await usdt.decimals()).to.equal(6);
        expect(await usdt.totalSupply()).to.equal(1000000000);
    })

    describe("transfer token to acc2", () => {
        before("transfer func", async () => {
            const transferTokenTxn = await usdt.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(4).mul(10));
            await transferTokenTxn.wait();
        })
        it("check that acc2 balance should be 10USDT", async () => {
            expect(await usdt.balanceOf(acc2.address)).to.equal(ethers.BigNumber.from(10).pow(4).mul(10));
        })
    });

    describe("Approve max allownace to acc3", () => {
        before("approve func", async () => {
            const approveTxn = await usdt.connect(acc2).approve(acc3.address, ethers.BigNumber.from(2).pow(256).sub(1));
            await approveTxn.wait();
        })
        it("check that acc3 allowance should 2^256 - 1", async () => {
            expect(await usdt.allowance(acc2.address, acc3.address)).to.equal(ethers.BigNumber.from(2).pow(256).sub(1));
        })
    });

    describe("Transfer Token to acc4 from acc2", () => {
        before("transfer from func", async () => {
            const transferTxn = await usdt.connect(acc3).transferFrom(acc2.address, acc4.address, ethers.BigNumber.from(10).pow(4).mul(1));
            await transferTxn.wait();
        })
        it("check that acc4 has 1USDT", async () => {
            expect(await usdt.balanceOf(acc4.address)).to.equal(ethers.BigNumber.from(10).pow(4).mul(1));
        })
    });

    describe("decrease allownace", () => {
        before("decrease allownace func", async () => {
            const decreaseAllowanceTxn = await usdt.connect(acc2).decreaseAllowance(acc3.address, ethers.BigNumber.from(2).pow(256).sub(1));
            await decreaseAllowanceTxn.wait();
        })
        it("check that acc3 allowance should be 0", async () => {
            expect(await usdt.allowance(acc2.address, acc3.address)).to.equal(ethers.BigNumber.from(0));
        })
    });

    describe("Increase allownace to acc3", () => {
        before("Increase allownace func", async () => {
            const approveTxn = await usdt.connect(acc2).increaseAllowance(acc3.address, ethers.BigNumber.from(6));
            await approveTxn.wait();
        })
        it("check that acc3 allowance should be 6", async () => {
            expect(await usdt.allowance(acc2.address, acc3.address)).to.equal(ethers.BigNumber.from(6));
        })
    });

});