const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Seed NFT", () => {
  var acc1;
  var acc2;
  var acc3;
  var acc4;
  var acc5;
  var minterRoleBytes;
  var seedNft;
  var token;
  const zeroHex = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const zeroAdd = "0x0000000000000000000000000000000000000000";

  before("Deployement", async () => {
    [acc1, acc2, acc3, acc4, acc5] = await ethers.getSigners();
    const seedNftContract = await ethers.getContractFactory("Angel");
    seedNft = await seedNftContract.deploy(acc5.address, "xyz.com"); //acc4 as a trasuryAddress
    await seedNft.deployed();
    const setMinterTxn = await seedNft.setMinterRole(acc1.address); //assigned minter role to acc1
    await setMinterTxn.wait();
    minterRoleBytes = await seedNft.MINTER_ROLE();
    const tokenContract = await ethers.getContractFactory("BaseERC20");
    token = await tokenContract.deploy("Test Token", "TT");
    await token.deployed();
    const tokenTrnsferTxn = await token.connect(acc1).transfer(seedNft.address, ethers.BigNumber.from(10).pow(18).mul(1000))
    await tokenTrnsferTxn.wait();
  });

  it("Initial value checks", async () => {
    console.log("NFT Address: ", seedNft.address);
    expect(await seedNft.connect(acc1).name()).to.equal("Solidefied Angel");
    expect(await seedNft.connect(acc1).symbol()).to.equal("ANGEL");
    expect(await seedNft.baseURI()).to.equal("xyz.com");
  });

  it("Check that acc1 has a minter role", async () => {
    expect(await seedNft.hasRole(minterRoleBytes, acc1.address)).to.equal(true);
  });

  it("Check that acc2 has not a minter role", async () => {
    expect(await seedNft.hasRole(minterRoleBytes, acc2.address)).to.equal(false);
  });

  it("Check Total supply is 1000 or not", async () => {
    expect(await seedNft.TOKEN_SUPPLY()).to.equal(1000);
  });

  describe("Mint NFT Token for acc2", () => {
    before("minter func", async () => {
      const mintTokenTxn = await seedNft.connect(acc1).mint(acc2.address);
      await mintTokenTxn.wait();
    });
    it("Check token is minted or not", async () => {
      expect(await seedNft.ownerOf(0)).to.equal(acc2.address);
    });

    it("Error should generated error when passed address is Null", async () => {
      await expect(seedNft.connect(acc1).mint(zeroAdd)).to.be.revertedWith("ERC721: mint to the zero address");
    });

    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).mint(acc2.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${minterRoleBytes}`);
    });
  });

  describe("Set New BaseURI", () => {
    before("set baseuri func", async () => {
      const setBaseURItxn = await seedNft.connect(acc1).setBaseURI("xyzx.com");
      await setBaseURItxn.wait();
    });
    it("Check base uri is setted or not", async () => {
      expect(await seedNft.baseURI()).to.equal("xyzx.com");
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).setBaseURI("xyzx.com")).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  });

  describe("Change Total supply", () => {
    before("set token supply func", async () => {
      const SetTokenSupplyTxn = await seedNft.connect(acc1).setTokenSupply(260);
      await SetTokenSupplyTxn.wait();
    });
    it("Check Total supply is 260 or not", async () => {
      expect(await seedNft.TOKEN_SUPPLY()).to.equal(260);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).setTokenSupply(260)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  });

  describe("Revoke Minter Role from acc2", () => {
    before("revoke role func", async () => {
      const RevokeMinterRoleTxn = await seedNft.connect(acc1).revokeRole(minterRoleBytes, acc2.address);
      await RevokeMinterRoleTxn.wait();
    });
    it("Check that acc2 has not a minter role", async () => {
      expect(await seedNft.hasRole(minterRoleBytes, acc2.address)).to.equal(false);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).revokeRole(minterRoleBytes, acc2.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  });

  describe("Grant Minter role to acc2", () => {
    before("grant role func", async () => {
      const setMinterTxn = await seedNft.connect(acc1).grantRole(minterRoleBytes, acc2.address); //assigned minter role to acc1
      await setMinterTxn.wait();
    })
    it("Check that acc2 has a minter role", async () => {
      expect(await seedNft.hasRole(minterRoleBytes, acc2.address)).to.equal(true);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).grantRole(minterRoleBytes, acc2.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  })

  describe("Renounce Minter Role of acc2", () => {
    before("revoke role func", async () => {
      const RenounceMinterRoleTxn = await seedNft.connect(acc2).renounceRole(minterRoleBytes, acc2.address);
      await RenounceMinterRoleTxn.wait();
    });
    it("Check that acc2 has not a minter role", async () => {
      expect(await seedNft.hasRole(minterRoleBytes, acc2.address)).to.equal(false);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).renounceRole(minterRoleBytes, acc2.address)).to.be.revertedWith(`AccessControl: can only renounce roles for self`);
    });
  });

  describe("Withdraw Accidentally added token", () => {
    before("Withdraw func", async () => {
      const WithDrawTokenTxn = await seedNft.connect(acc1).withdrawDonatedToken(token.address);
      await WithDrawTokenTxn.wait();
    })
    it("Test that accidentally token should be transfered to treasuryAddress(acc5)", async () => {
      expect(await token.balanceOf(acc5.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(1000));
    });
    it("Error:Contract should give error for token balance is zero", async () => {
      await expect(seedNft.connect(acc1).withdrawDonatedToken(token.address)).to.be.revertedWith("Low Balance");
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).withdrawDonatedToken(token.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  })

  describe("Withdraw Accidentally added ETH", () => {
    before("Withdraw func", async () => {
      await acc3.sendTransaction({
        to: seedNft.address,
        value: ethers.utils.parseEther("5")
      });    //send ETH to other acc or contract     
      const WithDrawETHTxn = await seedNft.connect(acc1).withdrawDonatedETH();
      await WithDrawETHTxn.wait();
    })
    it("Check that withdrawed amount is transferd to acc5", async () => {
      expect(await ethers.provider.getBalance(acc5.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(10005))
    })
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(seedNft.connect(acc3).withdrawDonatedETH()).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  })
});
