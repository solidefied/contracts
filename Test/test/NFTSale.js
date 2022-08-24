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
        const token1Contract = await ethers.getContractFactory("BaseERC20");
        token1 = await token1Contract.deploy("Test 1", "TT1");
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
            const AddNftTxn = await nftsale.connect(acc1).addSale(nft.address, [token1.address, token2.address], [ethers.BigNumber.from(10).pow(18).mul(10), ethers.BigNumber.from(10).pow(18).mul(100)], ethers.BigNumber.from(10).pow(18).mul(1));
            await AddNftTxn.wait();
        })
        it("Check that nft is listed or not for sale", async () => {            
            const deatils = await nftsale.getSaleDetails(nft.address);
            expect(deatils._active).to.equal(true);
        })
        it("Error:Test that contract should throw error for listing again token for sale",async()=>{
            await expect(nftsale.connect(acc1).addSale(nft.address, [token1.address, token2.address, token3.address,"0x0000000000000000000000000000000000000000"], [ethers.BigNumber.from(10).pow(17).mul(1), ethers.BigNumber.from(10).pow(18).mul(1), ethers.BigNumber.from(10).pow(18).mul(10)], ethers.BigNumber.from(10).pow(18).mul(1))).to.be.revertedWith("Collection previously listed");
         })
    });

    describe("Start Sale", () => {
        before("start sale funcs", async () => {
            const startSaleTxn = await nftsale.connect(acc1).setSaleActive(nft.address, true)
            await startSaleTxn.wait();
        })
    }); 

    describe("Enable Whitelisting", () => {
        before("set whitelisting to enable func", async () => {
            const WhiteListingActiveTxn = await nftsale.connect(acc1).setWhitelistingActive(nft.address, true);
            await WhiteListingActiveTxn.wait();
        })
        it("Check that whitelisting is enabled", async () => {
            const deatils = await nftsale.getSaleDetails(nft.address);
            expect(deatils._whitelistingActive).to.equal(true);
        })
    });

    describe("With out Minter role ", () => {     
        it("Error:Check that contract should throw error for not assign minter role", async () => {
            await expect(nftsale.connect(acc2).purchaseNFT(nft.address,token1.address)).to.be.revertedWith("!MINTER");
        });
    });

    describe("Purchase NFT before whitelisting user",()=>{
        before("Set minter role",async()=>{
            const givingMinterRoleTxn = await nft.connect(acc1).setMinterRole(nftsale.address);
            await givingMinterRoleTxn.wait();
        })
        it("Error:Test that before whitelisting causing error for purchase nft",async()=>{
            await expect(nftsale.connect(acc2).purchaseNFT(nft.address,"0x0000000000000000000000000000000000000000",{value:`${ethers.BigNumber.from(10).pow(18).mul(1)}`})).to.be.revertedWith("!WHITELISTED");
        })
    });

    describe("Whitelist user", () => {
        before("whitelisting func", async () => {
            const WhiteListingTxn = await nftsale.connect(acc1).setWhitelist(nft.address, [acc2.address, acc3.address, acc4.address, acc5.address]);
            await WhiteListingTxn.wait();
        })
        it("Check user is white listed or not ", async () => {
            expect(await nftsale.connect(acc1).checkUserWhitelisted(nft.address, acc2.address)).to.equal(true);
            expect(await nftsale.connect(acc1).checkUserWhitelisted(nft.address, acc3.address)).to.equal(true);
            expect(await nftsale.connect(acc1).checkUserWhitelisted(nft.address, acc4.address)).to.equal(true);
        })
    });     

    describe("Purchase token with not listed erc20 token ",()=>{
        it("Error:Test that contract should give error for trying to purchase with non listed token",async()=>{
          await expect(nftsale.connect(acc2).purchaseNFT(nft.address,token3.address)).to.be.revertedWith("Incorrect AMOUNT")
        })       
    })

    describe("Add New token to exists",()=>{
        before("add new token func ",async()=>{
            const setNewToKenTxn =await nftsale.connect(acc1).setPurchaseTokenPrice(nft.address,token3.address,ethers.BigNumber.from(10).pow(2).mul(23))
            await setNewToKenTxn.wait();
        })
        it("check token is added or not with its price",async()=>{
            const details = await nftsale.getSaleDetails(nft.address);
            await expect(details._purchaseToken[2]).to.equal(token3.address);
            await expect(details._purchasePrice[2]).to.equal(ethers.BigNumber.from(10).pow(2).mul(23));            
        })
    })
    
    describe("Purchase NFT with token1 ", () => {
        before("Purchase NFT Func", async () => {
            const givingMinterRoleTxn = await nft.connect(acc1).setMinterRole(nftsale.address);
            await givingMinterRoleTxn.wait();
            const approveTxn = await token1.connect(acc2).approve(nftsale.address,ethers.BigNumber.from(2).pow(256).sub(1));
            await approveTxn.wait();
            const purchaseNFTTxn = await nftsale.connect(acc2).purchaseNFT(nft.address,token1.address);
            await purchaseNFTTxn.wait();
        })
        it("Check balnce of user it should be 1", async () => {
            const balance = await nft.balanceOf(acc2.address)
            expect(balance).to.equal(ethers.BigNumber.from(1));
        });
    });

    describe("Purchase NFT with native Token ", () => {
        before("Purchase NFT Func", async () => {
            const givingMinterRoleTxn = await nft.connect(acc1).setMinterRole(nftsale.address);
            await givingMinterRoleTxn.wait();
            const purchaseNFTTxn = await nftsale.connect(acc2).purchaseNFT(nft.address,"0x0000000000000000000000000000000000000000",{value:`${ethers.BigNumber.from(10).pow(18).mul(1)}`});
            await purchaseNFTTxn.wait();
        })
        it("Check balnce of user it should be 2", async () => {
            const balance = await nft.balanceOf(acc2.address)
            expect(balance).to.equal(ethers.BigNumber.from(2));
        });
        it("Error:Test that wrong input value cause error for purchase nft",async()=>{
            await expect(nftsale.connect(acc2).purchaseNFT(nft.address,"0x0000000000000000000000000000000000000000",{value:`${ethers.BigNumber.from(10).pow(18).mul(10)}`})).to.be.revertedWith("Incorrect AMOUNT");
        })
    });

    describe("Withdraw Native token ", () => {
        before("Withdraw native token Func", async () => {            
            const withdrawNativeTokenTxn = await nftsale.connect(acc1).withdrawNativeTokenPayments(nft.address,acc1.address);
            await withdrawNativeTokenTxn.wait();
        })            
    });

    describe("Withdraw specific token  ", () => {
        before("Withdraw specific token Func", async () => {            
            const withdrawTokenTxn = await nftsale.connect(acc1).withdrawTokenPayments(nft.address,token1.address,acc5.address);
            await withdrawTokenTxn.wait();
        }) 
        it("Check balance is transfer to or not and it would be 10ETH",async()=>{
            const balance = await token1.balanceOf(acc5.address);
            expect(balance).to.equal(ethers.BigNumber.from(10).pow(18).mul(10));
        })           
    });

});