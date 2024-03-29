const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Governance NFT", () => {
  var acc1;
  var acc2;
  var acc3;
  var acc4;
  var acc5;
  var minterRoleBytes;
  var governance;
  var token;
  const zeroHex = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const zeroAdd = "0x0000000000000000000000000000000000000000";

  before("Deployement", async () => {
    [acc1, acc2, acc3, acc4, acc5] = await ethers.getSigners();
    const governanceContract = await ethers.getContractFactory("Governor");
    governance = await governanceContract.deploy(acc4.address, "xyz.com", 4); //acc4 as treasuryAddress,BaseURI,Royalty Rate
    await governance.deployed();
    const setMinterTxn = await governance.setMinterRole(acc1.address); //assigned minter role to acc1
    await setMinterTxn.wait();
    minterRoleBytes = await governance.MINTER_ROLE();
    const tokenContract = await ethers.getContractFactory("BaseERC20");
    token = await tokenContract.deploy("Test Token", "TT");
    await token.deployed();
    const tokenTrnsferTxn = await token.connect(acc1).transfer(governance.address, ethers.BigNumber.from(10).pow(18).mul(1000))
    await tokenTrnsferTxn.wait();
  });

  it("Initial value checks", async () => {
    console.log("NFT Address: ", governance.address);
    expect(await governance.name()).to.equal("Solidefied Governor");
    expect(await governance.symbol()).to.equal("POWER");
    expect(await governance.baseURI()).to.equal("xyz.com");
  });

  it("Check that acc1 has a minter role", async () => {
    expect(await governance.hasRole(minterRoleBytes, acc1.address)).to.equal(true);
  });

  it("Check that acc2 has not a minter role", async () => {
    expect(await governance.hasRole(minterRoleBytes, acc2.address)).to.equal(false);
  });

  it("Check Total supply is 250 or not", async () => {
    expect(await governance.TOKEN_SUPPLY()).to.equal(250);
  });

  describe("Mint NFT Token for acc2", () => {
    before("minter func", async () => {
      const mintTokenTxn = await governance.connect(acc1).mint(acc2.address);
      await mintTokenTxn.wait();
    });
    it("Check token is minted or not", async () => {
      expect(await governance.ownerOf(0)).to.equal(acc2.address);
    });

    it("Error should generated error when passed address is Null", async () => {
      await expect(governance.connect(acc1).mint(zeroAdd)).to.be.revertedWith("ERC721: mint to the zero address");
    });

    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).mint(acc2.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${minterRoleBytes}`);
    });
  });

  describe("Set New BaseURI", () => {
    before("set baseuri func", async () => {
      const setBaseURItxn = await governance.connect(acc1).setBaseURI("xyzx.com");
      await setBaseURItxn.wait();
    });
    it("Check base uri is setted or not", async () => {
      expect(await governance.baseURI()).to.equal("xyzx.com");
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).setBaseURI("xyzx.com")).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  });

  describe("Set new treasury", () => {
    before("set treasury func", async () => {
      const setBaseURItxn = await governance.connect(acc1).setTreasury(acc5.address);
      await setBaseURItxn.wait();
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).setTreasury(acc5.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  });

  describe("Transfer NFT to acc3", () => {
    before("safe transfer funcs", async () => {
      const TransferFromTxn = await governance.connect(acc2).transferFrom(acc2.address, acc3.address, 0);
      await TransferFromTxn.wait();
    });
    it("Check token is transfered or not", async () => {
      expect(await governance.ownerOf(0)).to.equal(acc3.address);
    });
  });

  describe("Change Total supply", () => {
    before("set token supply func", async () => {
      const SetTokenSupplyTxn = await governance.connect(acc1).setTokenSupply(260);
      await SetTokenSupplyTxn.wait();
    });
    it("Check Total supply is 260 or not", async () => {
      expect(await governance.TOKEN_SUPPLY()).to.equal(260);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).setTokenSupply(260)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  });

  describe("Revoke Minter Role from acc2", () => {
    before("revoke role func", async () => {
      const RevokeMinterRoleTxn = await governance.connect(acc1).revokeRole(minterRoleBytes, acc2.address);
      await RevokeMinterRoleTxn.wait();
    });
    it("Check that acc2 has not a minter role", async () => {
      expect(await governance.hasRole(minterRoleBytes, acc2.address)).to.equal(false);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).revokeRole(minterRoleBytes, acc2.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  });

  describe("Grant Minter role to acc2", () => {
    before("grant role func", async () => {
      const setMinterTxn = await governance.connect(acc1).grantRole(minterRoleBytes, acc2.address); //assigned minter role to acc1
      await setMinterTxn.wait();
    })
    it("Check that acc2 has a minter role", async () => {
      expect(await governance.hasRole(minterRoleBytes, acc2.address)).to.equal(true);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).grantRole(minterRoleBytes, acc2.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  })

  describe("Renounce Minter Role of acc2", () => {
    before("revoke role func", async () => {
      const RenounceMinterRoleTxn = await governance.connect(acc2).renounceRole(minterRoleBytes, acc2.address);
      await RenounceMinterRoleTxn.wait();
    });
    it("Check that acc2 has not a minter role", async () => {
      expect(await governance.hasRole(minterRoleBytes, acc2.address)).to.equal(false);
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).renounceRole(minterRoleBytes, acc2.address)).to.be.revertedWith(`AccessControl: can only renounce roles for self`);
    });
  });

  describe("Withdraw Accidentally added token", () => {
    before("Withdraw func", async () => {
      const WithDrawTokenTxn = await governance.connect(acc1).withdrawDonatedTokens(token.address);
      await WithDrawTokenTxn.wait();
    })
    it("Test that accidentally token should be transfered to treasuryAddress", async () => {
      expect(await token.balanceOf(acc5.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(1000));
    });
    it("Error:Contract should give error for token balance is zero", async () => {
      await expect(governance.connect(acc1).withdrawDonatedTokens(token.address)).to.be.revertedWith("!BALANCE");
    });
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).withdrawDonatedTokens(token.address)).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  })

  describe("Withdraw Accidentally added ETH", () => {
    before("Withdraw func", async () => {
      await acc3.sendTransaction({
        to: governance.address,
        value: ethers.utils.parseEther("5")
      });    //send ETH to other acc or contract     
      const WithDrawETHTxn = await governance.connect(acc1).withdrawDonatedETH();
      await WithDrawETHTxn.wait();
    })
    it("Check that withdrawed amount is transferd to treasury address", async () => {
      expect(await ethers.provider.getBalance(acc5.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(10005))
    })
    it("Error:Contract should give error for unauthorized txn by acc3", async () => {
      await expect(governance.connect(acc3).withdrawDonatedETH()).to.be.revertedWith(`AccessControl: account ${acc3.address.toLowerCase()} is missing role ${zeroHex}`);
    });
  })

});