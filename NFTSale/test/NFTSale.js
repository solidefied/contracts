const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFT Sale", () => {
    var acc1;
    var acc2;
    var acc3;
    var acc4;
    var acc5;
    var nftsale;
    var nft;
    var token1;
    var token2;
    var token3;
    var tokenTrnsferTxn;

    before("Deployment and token distribution", async () => {
        [acc1, acc2, acc3, acc4, acc5] = await ethers.getSigners();
        const nftsaleContract = await ethers.getContractFactory("NFTSale");
        nftsale = await nftsaleContract.deploy();
        await nftsale.deployed();
        const nftContract = await ethers.getContractFactory("Governor");
        nft = await nftContract.deploy(acc1.address, "test.com", 4);
        await nft.deployed();
        const token1Contract = await ethers.getContractFactory("Token1");
        token1 = await token1Contract.deploy();
        await token1.deployed();
        const token2Contract = await ethers.getContractFactory("Token2");
        token2 = await token2Contract.deploy();
        await token2.deployed()
        const token3Contract = await ethers.getContractFactory("Token3");
        token3 = await token3Contract.deploy();
        await token3.deployed();
        tokenTrnsferTxn = await token1.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(18).mul(1000))
        await tokenTrnsferTxn.wait();
        tokenTrnsferTxn = await token2.connect(acc1).transfer(acc3.address, ethers.BigNumber.from(10).pow(18).mul(1000))
        await tokenTrnsferTxn.wait();
        tokenTrnsferTxn = await token3.connect(acc1).transfer(acc4.address, ethers.BigNumber.from(10).pow(18).mul(1000))
        await tokenTrnsferTxn.wait();
    });
    describe("Add NFT to sale ", () => {
        before("Add nft funcs", async () => {
            const AddNftTxn = await nftsale.connect(acc1).addSale(nft.address, [token1.address, token2.address, token3.address], [ethers.BigNumber.from(10).pow(17).mul(1), ethers.BigNumber.from(10).pow(18).mul(1), ethers.BigNumber.from(10).pow(18).mul(10)], ethers.BigNumber.from(10).pow(18).mul(1))
            await AddNftTxn.wait()
        })
        // it("get sale details ", async () => {
        //     const value = await nftsale.getSaleDetails(nft.address);
        //     console.log(value);
        // })
    })
    describe("Start Sale", () => {
        before("start sale funcs", async () => {
            const startSaleTxn = await nftsale.connect(acc1).setSaleActive(nft.address, true)
            await startSaleTxn.wait();
        })
    })

    describe("Enable Whitelisting", () => {
        before("set whitelisting to enable func", async () => {
            const WhiteListingActiveTxn = await nftsale.connect(acc1).setWhitelistingActive(nft.address, true);
            await WhiteListingActiveTxn.wait();
        })
    })

    describe("Whitelist user ", () => {
        before("whitelisting func", async () => {
            const WhiteListingTxn = await nftsale.connect(acc1).setWhitelist(nft.address, [acc2.address, acc3.address, acc4.address, acc5.address], true);
            await WhiteListingTxn.wait();
        })
        it("Check user is white listed or not ", async () => {
            console.log(await nftsale.connect(acc1).checkUserWhitelisted(nft.address, acc2.address))
        })
    })
});
