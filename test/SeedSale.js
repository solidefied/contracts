const { expect } = require("chai");
const { ethers } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");
describe("Governance Sale", () => {
    var acc1;
    var acc2;
    var acc3;
    var acc4;
    var acc5;
    var acc6;
    var seedNFT;
    var seedSale;
    var USDT;
    var USDC;
    var DAI;
    var tree;
    var buf2Hex;
    const zeroAdd = "0x0000000000000000000000000000000000000000";

    before("Deployment and token distribution", async () => {
        [acc1, acc2, acc3, acc4, acc5, acc6] = await ethers.getSigners();

        const addresses = [acc1.address, acc2.address, acc3.address, acc4.address]
        const leaves = addresses.map(x => keccak256(x));
        tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        buf2Hex = x => "0x" + x.toString('hex');
        const root = buf2Hex(tree.getRoot());
        console.log('root: ', root);

        const token1Contract = await ethers.getContractFactory("TetherToken");
        USDT = await token1Contract.deploy(1000000000000, "USDT", "USDT", 6);
        await USDT.deployed();
        const transferToken = await USDT.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(6).mul(20000));
        await transferToken.wait();
        const token2Contract = await ethers.getContractFactory("FakeUSDC");
        USDC = await token2Contract.deploy();
        await USDC.deployed();
        const mintUSDCtoAcc2 = await USDC.connect(acc1).mint(acc2.address, ethers.BigNumber.from(10).pow(6).mul(20000))
        await mintUSDCtoAcc2.wait();
        const mintUSDCtoAcc3 = await USDC.connect(acc1).mint(acc3.address, ethers.BigNumber.from(10).pow(6).mul(20000))
        await mintUSDCtoAcc3.wait();
        const token3Contract = await ethers.getContractFactory("Dai");
        DAI = await token3Contract.deploy(80001); //chainId as params
        await DAI.deployed();
        const mintDAI = await DAI.connect(acc1).mint(acc4.address, ethers.BigNumber.from(10).pow(18).mul(20000))
        await mintDAI.wait();

        const nftContract = await ethers.getContractFactory("Angel");
        seedNFT = await nftContract.deploy(acc5.address, "xyz.com");
        await seedNFT.deployed();

        const nftsaleContract = await ethers.getContractFactory("SeedSale");
        seedSale = await nftsaleContract.deploy(seedNFT.address, USDT.address, USDC.address, DAI.address, root);
        await seedSale.deployed();

        const checkSetToTrue = await seedSale.connect(acc1).setWhitelist(true);
        await checkSetToTrue.wait();
    });

    describe("Buy Token with USDT", () => {
        before("Buy func", async () => {
            const setAsMinter = await seedNFT.connect(acc1).setMinterRole(seedSale.address);
            await setAsMinter.wait();
            const proof = tree.getProof(keccak256(acc2.address)).map(x => buf2Hex(x.data))
            const approveContract = await USDT.connect(acc2).approve(seedSale.address, ethers.BigNumber.from(2).pow(256).sub(1))
            await approveContract.wait();
            const nftPurchaseTxn = await seedSale.connect(acc2).buyNFTWithToken(USDT.address, proof);
            await nftPurchaseTxn.wait();
        })
        it("Test that,NFT is Purchased by acc2", async () => {
            expect(await USDT.balanceOf(seedSale.address)).to.equal(ethers.BigNumber.from(10).pow(6).mul(2000))
            expect(await USDT.balanceOf(acc2.address)).to.equal(ethers.BigNumber.from(10).pow(6).mul(18000))
            expect(await seedNFT.balanceOf(acc2.address)).to.equal(1)
        })
    })

    describe("Buy Token with USDC", () => {
        before("Buy func", async () => {
            const setAsMinter = await seedNFT.connect(acc1).setMinterRole(seedSale.address);
            await setAsMinter.wait();
            const proof = tree.getProof(keccak256(acc2.address)).map(x => buf2Hex(x.data))
            const approveContract = await USDC.connect(acc2).approve(seedSale.address, ethers.BigNumber.from(2).pow(256).sub(1))
            await approveContract.wait();
            const nftPurchaseTxn = await seedSale.connect(acc2).buyNFTWithToken(USDC.address, proof);
            await nftPurchaseTxn.wait();
        })
        it("Test that,NFT is Purchased by acc2", async () => {
            expect(await USDC.balanceOf(seedSale.address)).to.equal(ethers.BigNumber.from(10).pow(6).mul(2000))
            expect(await USDC.balanceOf(acc2.address)).to.equal(ethers.BigNumber.from(10).pow(6).mul(18000))
            expect(await seedNFT.balanceOf(acc2.address)).to.equal(2)
        })
        it("Error:Contract will gives error for invalid user proof", async () => {
            await expect(seedSale.connect(acc2).buyNFTWithToken(USDC.address, [])).to.be.revertedWith("Unauthorized")
        })
    })

    describe("Buy Token with DAI", () => {
        before("Buy func", async () => {
            const proof = tree.getProof(keccak256(acc4.address)).map(x => buf2Hex(x.data))
            const approveContract = await DAI.connect(acc4).approve(seedSale.address, ethers.BigNumber.from(2).pow(256).sub(1))
            await approveContract.wait();
            const nftPurchaseTxn = await seedSale.connect(acc4).buyNFTWithToken(DAI.address, proof);
            await nftPurchaseTxn.wait();
        })
        it("Test that,NFT is Purchased by acc4", async () => {
            expect(await DAI.balanceOf(seedSale.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(2000))
            expect(await DAI.balanceOf(acc4.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(18000))
            expect(await seedNFT.balanceOf(acc4.address)).to.equal(1)
        })
    })

    describe("Buy Token with ETH", () => {
        before("Buy func", async () => {
            const proof = tree.getProof(keccak256(acc3.address)).map(x => buf2Hex(x.data))
            const nftPurchaseTxn = await seedSale.connect(acc3).buyNFTWithETH(proof, { value: ethers.utils.parseEther("1.5") });
            await nftPurchaseTxn.wait();
        })
        it("Test that,NFT is Purchased by acc3", async () => {
            expect(await seedNFT.balanceOf(acc3.address)).to.equal(1)
            expect(await ethers.provider.getBalance(acc3.address)).to.be.above(ethers.BigNumber.from(10).pow(17).mul(99984));
        })
    })

    describe("Buy Token with ETH ", () => {
        before("Buy func", async () => {
            const proof = tree.getProof(keccak256(acc4.address)).map(x => buf2Hex(x.data))
            const nftPurchaseTxn = await seedSale.connect(acc4).buyNFTWithETH(proof, { value: ethers.utils.parseEther("1.5") });
            await nftPurchaseTxn.wait();
        })
        it("Test that,NFT is Purchased by acc4", async () => {
            expect(await seedNFT.balanceOf(acc4.address)).to.equal(2)
        })
    })

    describe("set new root ", () => {
        before("setter func", async () => {
            const addresses = [acc1.address, acc2.address, acc3.address, acc4.address, acc5.address]
            const leaves = addresses.map(x => keccak256(x));
            tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
            buf2Hex = x => "0x" + x.toString('hex');
            const newRoot = buf2Hex(tree.getRoot());
            const setNewRoot = await seedSale.connect(acc1).setMerkleRoot(newRoot);
            await setNewRoot.wait();
        })
        it("Test that,NFT is Purchased by acc4", async () => {
            const newRoot = buf2Hex(tree.getRoot());
            expect(await seedSale.root()).to.equal(newRoot)
        })
    })

    describe("set new ETH price ", () => {
        before("setter func", async () => {
            const setNewETHPrice = await seedSale.connect(acc1).setPriceETH(ethers.BigNumber.from(10).pow(18).mul(1));
            await setNewETHPrice.wait();
        })
        it("Test that,NFT is Purchased by acc4", async () => {
            expect(await seedSale.priceInETH()).to.equal(ethers.BigNumber.from(10).pow(18).mul(1))
        })
    })

    describe("set new USD price ", () => {
        before("setter func", async () => {
            const setNewUSDPrice = await seedSale.connect(acc1).setPriceUSD(ethers.BigNumber.from(10).pow(4).mul(1000));
            await setNewUSDPrice.wait();
        })
        it("Test that,NFT is Purchased by acc4", async () => {
            expect(await seedSale.priceInUSD()).to.equal(ethers.BigNumber.from(10).pow(4).mul(1000))
        })
    })

    describe("set new treasury address ", () => {
        before("setter func", async () => {
            const setNewTreasury = await seedSale.connect(acc1).setTreasury(acc5.address);
            await setNewTreasury.wait();
        })
        it("Test that,NFT is Purchased by acc4", async () => {
            expect(await seedSale.TREASURY()).to.equal(acc5.address)
        })
    })

    describe("set whitelist disable ", () => {
        before("setter func", async () => {
            const setWhitelistDisable = await seedSale.connect(acc1).setWhitelist(false);
            await setWhitelistDisable.wait();
        })
        it("Test that,NFT is Purchased by acc4", async () => {
            expect(await seedSale.iswhitelistingEnabled()).to.equal(false)
        })
    })

    describe("Error:Withdraw tokens", () => {
        it("Check that contract should give error for withdraw tokens before pause", async () => {
            await expect(seedSale.connect(acc1).withdrawETH()).to.be.revertedWith("Pausable: not paused")
        })
    })

    describe("Pause Sale", () => {
        before("pause func", async () => {
            const pauseTxn = await seedSale.connect(acc1).pause();
            await pauseTxn.wait();
        })
        it("check that sale is paused", async () => {
            expect(await seedSale.paused()).to.equal(true)
        })
    })

    describe("Withdraw Native token ", () => {
        before("Withdraw native token func", async () => {
            const withdrawNativeTokenTxn = await seedSale.connect(acc1).withdrawETH();
            await withdrawNativeTokenTxn.wait();
        })
        it("check that contract balance should be 0ETH and acc5 balance should be ~1003ETH ", async () => {
            expect(await ethers.provider.getBalance(seedSale.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(0));
            expect(await ethers.provider.getBalance(acc5.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(10003));
        })
        it("Error:Contract should give error for unauthorized txn by acc3", async () => {
            await expect(seedSale.connect(acc3).withdrawETH()).to.be.revertedWith("Ownable: caller is not the owner")
        })
    });

    describe("Withdraw specific token  ", () => {
        before("Withdraw specific token func", async () => {
            const withdrawTokenTxn = await seedSale.connect(acc1).withdrawTokens(DAI.address, ethers.BigNumber.from(10).pow(18).mul(2000));
            await withdrawTokenTxn.wait();
        })
        it("Check balance is transfer to or not and it would be 10ETH", async () => {
            expect(await DAI.balanceOf(acc5.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(2000));
        })
        it("Error:Contract should give error for unauthorized txn by acc3", async () => {
            await expect(seedSale.connect(acc3).withdrawTokens(DAI.address, ethers.BigNumber.from(10).pow(18).mul(2000))).to.be.revertedWith("Ownable: caller is not the owner")
        })
    });

    describe("Unpause Sale", () => {
        before("unpause func", async () => {
            const unpauseTxn = await seedSale.connect(acc1).unpause();
            await unpauseTxn.wait();
        })
        it("check that sale is paused", async () => {
            expect(await seedSale.paused()).to.equal(false)
        })
    })

    describe("set acc6 as an new onwer", () => {
        before("setter func", async () => {
            const transferOwnerShipToAcc6 = await seedSale.connect(acc1).transferOwnership(acc6.address);
            await transferOwnerShipToAcc6.wait();
        })
        it("Test that acc6 is new owner", async () => {
            expect(await seedSale.owner()).to.equal(acc6.address)
        })
        it("Error:Contract should give error for unauthorized txn by acc3", async () => {
            await expect(seedSale.connect(acc3).transferOwnership(acc6.address)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("renounce onwership ", () => {
        before("renounce ownership func", async () => {
            const transferOwnerShipToZeroAdd = await seedSale.connect(acc6).renounceOwnership();
            await transferOwnerShipToZeroAdd.wait();
        })
        it("Test that acc6 is new owner", async () => {
            expect(await seedSale.owner()).to.equal(zeroAdd)
        })
        it("Error:Contract should give error for unauthorized txn by acc3", async () => {
            await expect(seedSale.connect(acc3).renounceOwnership()).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })
});