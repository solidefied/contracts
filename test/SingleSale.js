const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Single NFT Sale", () => {
    var acc1;
    var acc2;
    var acc3;
    var acc4;
    var acc5;
    var acc6;
    var singleSale;
    var nft;
    var token1;
    var token2;
    var token3;
    var tokenTrnsferTxn;
    const zeroAdd = "0x0000000000000000000000000000000000000000";

    before("Deployment and token distribution", async () => {
        [acc1, acc2, acc3, acc4, acc5, acc6] = await ethers.getSigners();
        const nftContract = await ethers.getContractFactory("Governor");
        nft = await nftContract.deploy(acc1.address, "test.com", 4);
        await nft.deployed();
        const token1Contract = await ethers.getContractFactory("BaseERC20");
        token1 = await token1Contract.deploy("Test 1", "TT1");
        await token1.deployed();
        const token2Contract = await ethers.getContractFactory("BaseERC20");
        token2 = await token2Contract.deploy("Test 2", "TT2");
        await token2.deployed()
        const token3Contract = await ethers.getContractFactory("BaseERC20");
        token3 = await token3Contract.deploy("Test 1", "TT1");
        await token3.deployed();
        tokenTrnsferTxn = await token1.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(18).mul(1000))
        await tokenTrnsferTxn.wait();
        tokenTrnsferTxn = await token2.connect(acc1).transfer(acc3.address, ethers.BigNumber.from(10).pow(18).mul(1000))
        await tokenTrnsferTxn.wait();
        tokenTrnsferTxn = await token3.connect(acc1).transfer(acc4.address, ethers.BigNumber.from(10).pow(18).mul(1000))
        await tokenTrnsferTxn.wait();
        const SingleSale = await ethers.getContractFactory("SingleNFTSale");
        singleSale = await SingleSale.deploy(nft.address, [token1.address, token2.address], [ethers.BigNumber.from(10).pow(18).mul(10), ethers.BigNumber.from(10).pow(18).mul(100)], ethers.BigNumber.from(10).pow(18).mul(1), acc5.address); //acc5 as TREASURY 
        await singleSale.deployed();
        const givingMinterRoleTxn = await nft.connect(acc1).setMinterRole(singleSale.address);
        await givingMinterRoleTxn.wait();
    });

    it("Initial value checkes", async () => {
        expect(await singleSale.owner()).to.equal(acc1.address);
        expect(await singleSale.nftContract()).to.equal(nft.address);
        expect(await singleSale.saleActive()).to.equal(true);
        expect(await singleSale.TREASURY()).to.equal(acc5.address);
        expect(await singleSale.priceInNativeTokens()).to.equal(ethers.BigNumber.from(10).pow(18).mul(1));
        const PurchaseTokenDetails = await singleSale.getPurchaseTokenDetails()
        expect(PurchaseTokenDetails[0][0]).to.equal(token1.address);
        expect(PurchaseTokenDetails[0][1]).to.equal(token2.address);
        expect(PurchaseTokenDetails[1][0]).to.equal(ethers.BigNumber.from(10).pow(18).mul(10));
        expect(PurchaseTokenDetails[1][1]).to.equal(ethers.BigNumber.from(10).pow(18).mul(100));
    })


    describe("Change Treasury Address", () => {
        before("set whitelisting to enable func", async () => {
            const setTreasuryAddrTxn = await singleSale.connect(acc1).setTreasury(acc6.address);
            await setTreasuryAddrTxn.wait();
        })
        it("Check that whitelisting is enabled", async () => {
            expect(await singleSale.TREASURY()).to.equal(acc6.address);
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSale.connect(acc4).setTreasury(acc6.address)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    });

    describe("Change Native token price", () => {
        before("set whitelisting to enable func", async () => {
            const setTreasuryAddrTxn = await singleSale.connect(acc1).setPurchaseNativeTokenPrice(ethers.BigNumber.from(10).pow(18).mul(2));
            await setTreasuryAddrTxn.wait();
        })
        it("Check that whitelisting is enabled", async () => {
            expect(await singleSale.priceInNativeTokens()).to.equal(ethers.BigNumber.from(10).pow(18).mul(2));
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSale.connect(acc4).setPurchaseNativeTokenPrice(ethers.BigNumber.from(10).pow(18).mul(2))).to.be.revertedWith("Ownable: caller is not the owner")
        })
    });

    describe("Change Owner ", () => {
        before("Set new owner", async () => {
            const setOwnerTxn = await singleSale.connect(acc1).transferOwnership(acc2.address);
            await setOwnerTxn.wait();
        })
        it("Check that owner is acc2", async () => {
            expect(await singleSale.owner()).to.equal(acc2.address);
        })
        it("Error:Contract should give error for unauthorized txn by acc3", async () => {
            await expect(singleSale.connect(acc4).transferOwnership(acc2.address)).to.be.revertedWith("Ownable: caller is not the owner");
        })
    });

    describe("Purchase token with not listed erc20 token ", () => {
        it("Error:Test that contract should give error for trying to purchase with non listed token", async () => {
            await expect(singleSale.connect(acc2).purchaseNFT(token3.address)).to.be.revertedWith("Incorrect AMOUNT")
        })
    })

    // describe("Add New token to exists sale", () => {
    //     before("add new token func ", async () => {
    //         const setNewToKenTxn = await singleSale.connect(acc2).setPurchaseTokenPrice(token3.address, ethers.BigNumber.from(10).pow(18).mul(23));
    //         await setNewToKenTxn.wait();
    //     })
    //     it("check token is added or not with its price", async () => {
    //         const PurchaseTokenDetails = await singleSale.getPurchaseTokenDetails();
    //         console.log(PurchaseTokenDetails);
    //         expect(PurchaseTokenDetails[0][2]).to.equal(token3.address);
    //         expect(PurchaseTokenDetails[1][2]).to.equal(ethers.BigNumber.from(10).pow(2).mul(23));
    //     })
    //     it("Error:Contract should give error for unauthorized txn by acc4", async () => {
    //         await expect(singleSale.connect(acc3).setPurchaseTokenPrice(oken3.address, ethers.BigNumber.from(10).pow(2).mul(23))).to.be.revertedWith("Ownable: caller is not the owner")
    //     })
    // })

    describe("Change native token price", () => {
        before("set new price func ", async () => {
            const setNativeToKenPriceTxn = await singleSale.connect(acc2).setPurchaseNativeTokenPrice(ethers.BigNumber.from(10).pow(18).mul(2));
            await setNativeToKenPriceTxn.wait();
        })
        it("check token is added or not with its price", async () => {
            expect(await singleSale.priceInNativeTokens()).to.equal(ethers.BigNumber.from(10).pow(18).mul(2));
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSale.connect(acc3).setPurchaseNativeTokenPrice(ethers.BigNumber.from(10).pow(2).mul(2))).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("Purchase NFT with token1 ", () => {
        before("Purchase NFT Func", async () => {
            const changeOwership = await singleSale.connect(acc2).transferOwnership(acc1.address);
            await changeOwership.wait();
            const approveTxn = await token1.connect(acc2).approve(singleSale.address, ethers.BigNumber.from(2).pow(256).sub(1));
            await approveTxn.wait();
            const purchaseNFTTxn = await singleSale.connect(acc2).purchaseNFT(token1.address);
            await purchaseNFTTxn.wait();
        })
        it("Check balnce of user it should be 1", async () => {
            const balance = await nft.balanceOf(acc2.address)
            expect(balance).to.equal(ethers.BigNumber.from(1));
        });
    });

    describe("Purchase NFT with token2 ", () => {
        before("Purchase NFT Func", async () => {
            const approveTxn = await token2.connect(acc3).approve(singleSale.address, ethers.BigNumber.from(2).pow(256).sub(1));
            await approveTxn.wait();
            const purchaseNFTTxn = await singleSale.connect(acc3).purchaseNFT(token2.address);
            await purchaseNFTTxn.wait();
        })
        it("Check balnce of user it should be 1", async () => {
            const balance = await nft.balanceOf(acc3.address)
            expect(balance).to.equal(ethers.BigNumber.from(1));
        });
    });

    describe("Purchase NFT with native token ", () => {
        before("Purchase NFT Func", async () => {
            const purchaseNFTTxn = await singleSale.connect(acc2).purchaseNFTByNativeTokens({ value: ethers.BigNumber.from(10).pow(18).mul(2) });
            await purchaseNFTTxn.wait();
        })
        it("Check balance of user it should be 2 and contract balance should be 2ETH", async () => {
            const balance = await nft.balanceOf(acc2.address)
            expect(balance).to.equal(2);
            expect(await ethers.provider.getBalance(singleSale.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(2));
        });
        it("Error:Test that wrong input value cause error for purchase nft", async () => {
            await expect(singleSale.connect(acc2).purchaseNFTByNativeTokens({ value: ethers.BigNumber.from(10).pow(18).mul(10) })).to.be.revertedWith("Incorrect AMOUNT");
        })
    });

    describe("Withdraw Native token", () => {
        before("Withdraw native token Func", async () => {
            const withdrawNativeTokenTxn = await singleSale.connect(acc1).withdrawNativeTokenPayments();
            await withdrawNativeTokenTxn.wait();
        })
        it("check that contract balance should be 0ETH and acc1 balance should be 10002ETH ", async () => {
            expect(await ethers.provider.getBalance(singleSale.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(0));
            expect(await ethers.provider.getBalance(acc6.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(10002));
        })
    });

    describe("Withdraw specific token  ", () => {
        before("Withdraw specific token Func", async () => {
            const withdrawTokenTxn = await singleSale.connect(acc1).withdrawTokenPayments(token1.address);
            await withdrawTokenTxn.wait();
        })
        it("Check balance is transfer to or not and it would be 10token and 100token", async () => {
            const balance = await token1.balanceOf(acc6.address);
            expect(balance).to.equal(ethers.BigNumber.from(10).pow(18).mul(10));
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSale.connect(acc4).withdrawTokenPayments(token1.address)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    });

    describe("Free mint", () => {
        before("free mint funcs", async () => {
            const startSaleTxn = await singleSale.connect(acc1).setFreeMint(true)
            await startSaleTxn.wait();
        })
        it("Test that Free mint is enable", async () => {
            expect(await singleSale.freeMint()).to.equal(true)
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSale.connect(acc4).setFreeMint(true)).to.be.revertedWith("Ownable: caller is not the owner")
        })
    });

    describe("Mint Free NFT ", () => {
        before("Purchase NFT Func", async () => {
            const purchaseNFTTxn = await singleSale.connect(acc2).purchaseNFTByNativeTokens({ value: ethers.BigNumber.from(10).pow(18).mul(0) });
            await purchaseNFTTxn.wait();
        })
        it("Check balance of user it should be 3 and contract balance should be 0ETH", async () => {
            const balance = await nft.balanceOf(acc2.address)
            expect(balance).to.equal(3);
            expect(await ethers.provider.getBalance(singleSale.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(0));
        });
    });

    describe("Renounce Ownership ", () => {
        before("Set new owner", async () => {
            const RenounceOwnershipTxn = await singleSale.connect(acc1).renounceOwnership();
            await RenounceOwnershipTxn.wait();
        })
        it("Check that ownership is transfered to zero address", async () => {
            expect(await singleSale.owner()).to.equal(zeroAdd);
        })
        it("Error:Contract should give error for unauthorized txn by acc4", async () => {
            await expect(singleSale.connect(acc4).renounceOwnership()).to.be.revertedWith("Ownable: caller is not the owner");
        })
    });
});