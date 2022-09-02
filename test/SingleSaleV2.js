const { expect } = require("chai");
const { ethers } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");
// window.Buffer = window.Buffer || Buffer;

describe("Single NFT Sale V2", () => {
    var acc1;
    var acc2;
    var acc3;
    var acc4;
    var acc5;
    var acc6;
    var acc7;
    var tree;    // retrun merkletree
    var buf2Hex; // return hex string func
    var newRoot;
    var nft;
    var usdt;
    var usdc;
    var dai;
    var singleSaleV2;
    var tokenTrnsferTxn;
    const zeroAdd = "0x0000000000000000000000000000000000000000";

    before("Deployment and token distribution", async () => {
        [acc1, acc2, acc3, acc4, acc5, acc6, acc7] = await ethers.getSigners();
        const addresses = [acc1.address, acc2.address, acc4.address, acc3.address, acc6.address]
        const leaves = addresses.map(x => keccak256(x));
        tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        buf2Hex = x => "0x" + x.toString('hex');
        const root = buf2Hex(tree.getRoot());
        console.log('root: ', root);
        const nftContract = await ethers.getContractFactory("Governor");
        nft = await nftContract.deploy(acc1.address, "test.com", 400); // acc1 as treasury 400 === 4% royaltyrate
        await nft.deployed();
        const token1Contract = await ethers.getContractFactory("Token");
        usdt = await token1Contract.deploy("USDT", "USDT");
        await usdt.deployed();
        const token2Contract = await ethers.getContractFactory("Token");
        usdc = await token2Contract.deploy("USDC", "USDC");
        await usdc.deployed()
        const token3Contract = await ethers.getContractFactory("BaseERC20");
        dai = await token3Contract.deploy("Dai", "Dai");
        await dai.deployed();
        tokenTrnsferTxn = await usdt.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(6).mul(100))
        await tokenTrnsferTxn.wait();
        tokenTrnsferTxn = await usdc.connect(acc1).transfer(acc3.address, ethers.BigNumber.from(10).pow(6).mul(100))
        await tokenTrnsferTxn.wait();
        tokenTrnsferTxn = await dai.connect(acc1).transfer(acc4.address, ethers.BigNumber.from(10).pow(18).mul(1000))
        await tokenTrnsferTxn.wait();
        const SingleSaleV2 = await ethers.getContractFactory("NFTPrimaryMint");
        singleSaleV2 = await SingleSaleV2.deploy(nft.address, acc7.address, ethers.BigNumber.from(10).pow(18).mul(2), 1022, usdt.address, usdc.address, dai.address, root); //acc7 as TREASURY, here 1022 is $10.22
        await singleSaleV2.deployed();
        const givingMinterRoleTxn = await nft.connect(acc1).setMinterRole(singleSaleV2.address);
        await givingMinterRoleTxn.wait();
    });

    it("Initial value checkes", async () => {
        expect(await singleSaleV2.owner()).to.equal(acc1.address);
        expect(await singleSaleV2.nftContract()).to.equal(nft.address);
        expect(await singleSaleV2.TREASURY()).to.equal(acc7.address);
        expect(await singleSaleV2.priceInETH()).to.equal(ethers.BigNumber.from(10).pow(18).mul(2));
        expect(await singleSaleV2.priceInUSD()).to.equal(1022);
        expect(await singleSaleV2.USDT()).to.equal(usdt.address);
        expect(await singleSaleV2.USDC()).to.equal(usdc.address);
        expect(await singleSaleV2.DAI()).to.equal(dai.address);
        expect(await singleSaleV2.iswhitelistingEnabled()).to.equal(false);
    })

    describe("Activate Whitelisting", () => {
        before("whitelist enable func", async () => {
            const startWhiteListing = await singleSaleV2.connect(acc1).setWhitelist(true);
            await startWhiteListing.wait();
        })
        it("check that whitelisting is enable", async () => {
            expect(await singleSaleV2.iswhitelistingEnabled()).to.equal(true);
        })
        it("Error:Test that not listed user of allowlist will get error for purchase nft", async () => {
            const proof = tree.getProof(keccak256(acc5.address)).map(x => buf2Hex(x.data))
            await expect(singleSaleV2.connect(acc5).buyNFTWithToken(usdt.address, proof)).to.be.revertedWith("Not a part of Allowlist");
        })
    });

    describe("Purchase NFT with USDT ", () => {
        before("Purchase NFT Func", async () => {
            const proof = tree.getProof(keccak256(acc2.address)).map(x => buf2Hex(x.data));
            const approveTxn = await usdt.connect(acc2).approve(singleSaleV2.address, ethers.BigNumber.from(2).pow(256).sub(1));
            await approveTxn.wait();
            const purchaseNFTTxn = await singleSaleV2.connect(acc2).buyNFTWithToken(usdt.address, proof);
            await purchaseNFTTxn.wait();
        })
        it("Check NFT balance of user, it should be 1", async () => {
            expect(await nft.balanceOf(acc2.address)).to.equal(ethers.BigNumber.from(1));
        })
        it("Check balance of sale contract, it should be 10.22 USDT", async () => {
            expect(await usdt.balanceOf(singleSaleV2.address)).to.equal(ethers.BigNumber.from(10).pow(4).mul(1022));
        })
    });

    describe("Purchase NFT with USDC", () => {
        before("Purchase NFT Func", async () => {
            const proof = tree.getProof(keccak256(acc3.address)).map(x => buf2Hex(x.data));
            const approveTxn = await usdc.connect(acc3).approve(singleSaleV2.address, ethers.BigNumber.from(2).pow(256).sub(1));
            await approveTxn.wait();
            const purchaseNFTTxn = await singleSaleV2.connect(acc3).buyNFTWithToken(usdc.address, proof);
            await purchaseNFTTxn.wait();
        })
        it("Check NFT balance of user, it should be 1", async () => {
            expect(await nft.balanceOf(acc3.address)).to.equal(ethers.BigNumber.from(1));
        })
        it("Check balance of sale contract, it should be 10.22 USDC", async () => {
            expect(await usdc.balanceOf(singleSaleV2.address)).to.equal(ethers.BigNumber.from(10).pow(4).mul(1022));
        })
    });

    describe("Purchase NFT with DAI", () => {
        before("Purchase NFT Func", async () => {
            const proof = tree.getProof(keccak256(acc4.address)).map(x => buf2Hex(x.data));
            const approveTxn = await dai.connect(acc4).approve(singleSaleV2.address, ethers.BigNumber.from(2).pow(256).sub(1));
            await approveTxn.wait();
            const purchaseNFTTxn = await singleSaleV2.connect(acc4).buyNFTWithToken(dai.address, proof);
            await purchaseNFTTxn.wait();
        })
        it("Check balnce of user it should be 1", async () => {
            expect(await nft.balanceOf(acc4.address)).to.equal(ethers.BigNumber.from(1));
        })
        it("Check balnce of sale it should be 10.22 DAI", async () => {
            expect(await dai.balanceOf(await singleSaleV2.address)).to.equal(ethers.BigNumber.from(10).pow(16).mul(1022));
        })
    });

    describe("Purchase NFT with ETH", () => {
        before("Purchase NFT Func", async () => {
            const proof = tree.getProof(keccak256(acc4.address)).map(x => buf2Hex(x.data));
            const purchaseNFTTxn = await singleSaleV2.connect(acc4).buyNFTWithETH(proof, { value: ethers.BigNumber.from(10).pow(18).mul(2) });
            await purchaseNFTTxn.wait();
        })
        it("Check balnce of user it should be 2", async () => {
            expect(await nft.balanceOf(acc4.address)).to.equal(ethers.BigNumber.from(2));
        })
        it("Check balnce of sale it should be 2 ETH", async () => {
            expect(await ethers.provider.getBalance(singleSaleV2.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(2));
        })
    });

    describe("Purchase NFT with ETH when whitelisting check is disable", () => {
        before("Purchase NFT Func", async () => {
            const stopWhiteListing = await singleSaleV2.connect(acc1).setWhitelist(false);
            await stopWhiteListing.wait();
            const purchaseNFTTxn = await singleSaleV2.connect(acc5).buyNFTWithETH([], { value: ethers.BigNumber.from(10).pow(18).mul(2) });
            await purchaseNFTTxn.wait();
        })
        it("Check balance of user, it should be 1", async () => {
            expect(await nft.balanceOf(acc5.address)).to.equal(ethers.BigNumber.from(1));
        })
        it("Check balance of sale contract, it should be 4 ETH", async () => {
            expect(await ethers.provider.getBalance(singleSaleV2.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(4));
        })
    });

    describe("Withdraw ETH", () => {
        before("Withdraw native token Func", async () => {
            const withdrawNativeTokenTxn = await singleSaleV2.connect(acc1).withdrawETH();
            await withdrawNativeTokenTxn.wait();
        })
        it("check that contract balance should be 0ETH and acc1 balance should be 10004ETH ", async () => {
            expect(await ethers.provider.getBalance(singleSaleV2.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(0));
            expect(await ethers.provider.getBalance(acc7.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(10004));
        })
    });

    describe("Withdraw specific token", () => {
        before("Withdraw specific token Func", async () => {
            const withdrawTokenTxn = await singleSaleV2.connect(acc1).withdrawTokens(usdt.address, ethers.BigNumber.from(10).pow(4).mul(1022));
            await withdrawTokenTxn.wait();
        })
        it("Check balance is transfer to or not and it would be 10token and 100token", async () => {
            expect(await usdt.balanceOf(acc7.address)).to.equal(ethers.BigNumber.from(10).pow(4).mul(1022));
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSaleV2.connect(acc4).withdrawTokens(usdt.address, ethers.BigNumber.from(10).pow(4).mul(1022))).to.be.revertedWith("Ownable: caller is not the owner")
        })
    });

    describe("Change MerkleTree root", () => {
        before("set new root funcs", async () => {
            const addresses = [acc1.address, acc2.address, acc4.address, acc3.address, acc5.address]
            const leaves = addresses.map(x => keccak256(x));
            tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
            newRoot = buf2Hex(tree.getRoot());
            console.log('newRoot: ', newRoot);
            const SetRootTxn = await singleSaleV2.connect(acc1).setMerkleRoot(newRoot);
            await SetRootTxn.wait();
        })
        it("Check that new root is set", async () => {
            expect(await singleSaleV2.root()).to.equal(newRoot);
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSaleV2.connect(acc4).setMerkleRoot(newRoot)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("Change treasury Address", () => {
        before("set new treasury address funcs", async () => {
            const SetTreasuryAddressTxn = await singleSaleV2.connect(acc1).setTreasury(acc6.address);
            await SetTreasuryAddressTxn.wait();
        })
        it("Check that treasury address is changed to acc6", async () => {
            expect(await singleSaleV2.TREASURY()).to.equal(acc6.address);
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSaleV2.connect(acc4).setTreasury(acc6.address)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("Change native token amount ", () => {
        before("change eth price funcs", async () => {
            const ChangeETHAmontTxn = await singleSaleV2.connect(acc1).setPriceETH(ethers.BigNumber.from(10).pow(18).mul(3));
            await ChangeETHAmontTxn.wait();
        })
        it("Check that native token price should be 3 ETH", async () => {
            expect(await singleSaleV2.priceInETH()).to.equal(ethers.BigNumber.from(10).pow(18).mul(3));
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSaleV2.connect(acc4).setPriceETH(ethers.BigNumber.from(10).pow(18).mul(3))).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("Change token amount ", () => {
        before("change USD price funcs", async () => {
            const ChangeUSDAmontTxn = await singleSaleV2.connect(acc1).setPriceUSD(1028);
            await ChangeUSDAmontTxn.wait();
        })
        it("Check that token price should be $10.28", async () => {
            expect(await singleSaleV2.priceInUSD()).to.equal(1028);
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSaleV2.connect(acc4).setPriceUSD(1028)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("Change ownership to acc4 ", () => {
        before("change ownership func", async () => {
            const ChangeOwnershipTxn = await singleSaleV2.connect(acc1).transferOwnership(acc4.address);
            await ChangeOwnershipTxn.wait();
        })
        it("Check that owner should be acc4", async () => {
            expect(await singleSaleV2.owner()).to.equal(acc4.address);
        })
        it("Error:Contract should give error for unauthorized txn by acc1", async () => {
            await expect(singleSaleV2.connect(acc1).transferOwnership(acc4.address)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("Renounce ownership", () => {
        before("renounce ownership func", async () => {
            const RenounceOwnershipTxn = await singleSaleV2.connect(acc4).renounceOwnership();
            await RenounceOwnershipTxn.wait();
        })
        it("Check that owner should be zero address", async () => {
            expect(await singleSaleV2.owner()).to.equal(zeroAdd);
        })
        it("Error:Contract should give error for unauthorized txn by acc1", async () => {
            await expect(singleSaleV2.connect(acc1).transferOwnership(acc4.address)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })
});