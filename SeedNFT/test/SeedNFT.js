const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Seed NFT", () => {
  var acc1;
  var acc2;
  var acc3;
  var acc4;
  var minterRoleBytes;
  var seedNft;

  before("Deployement", async () => {
    [acc1, acc2, acc3, acc4] = await ethers.getSigners();
    const seedNftContract = await ethers.getContractFactory("Angel");
    seedNft = await seedNftContract.deploy(acc1.address, "xyz.com");
    await seedNft.deployed();
    const setMinterTxn = await seedNft.setMinterRole(acc1.address); //assigned minter role to acc1
    await setMinterTxn.wait();
    minterRoleBytes = await seedNft.MINTER_ROLE();
  });

  it("Initialiation check", async () => {
    console.log("seedNft: ", seedNft.address);
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
      const mintTokenTxn = await seedNft.connect(acc1).mintToken(acc2.address);
      await mintTokenTxn.wait();
    });
    it("Check token is minted or not", async () => {
      expect(await seedNft.ownerOf(0)).to.equal(acc2.address);
    });

    it("Error should generated when passed address is Null", async () => {
      await expect(seedNft.connect(acc1).mintToken("0x0000000000000000000000000000000000000000")).to.be.revertedWith("Receiver required");
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
  });

  // describe("Transfer NFT to acc3", () => {
  //   before("safe transfer funcs", async () => {
  //     const TransferFromTxn = await seedNft.connect(acc2).transferFrom(acc2.address, acc3.address, 0);
  //     await TransferFromTxn.wait();
  //   });
  //   it("Check token is transfered or not", async () => {
  //     expect(await seedNft.ownerOf(0)).to.equal(acc3.address);
  //   });
  // });

  describe("Change Total supply", () => {
    before("set token supply func", async () => {
      const SetTokenSupplyTxn = await seedNft.connect(acc1).setTokenSupply(260);
      await SetTokenSupplyTxn.wait();
    });
    it("Check Total supply is 260 or not", async () => {
      expect(await seedNft.TOKEN_SUPPLY()).to.equal(260);
    });
  });

  // describe("Grant Minter Role to acc2", () => {
  //   before("grant role func", async () => {
  //     const GrantMinterRoleTxn = await seedNft.grantRole(minterRoleBytes, acc2.address);
  //     await GrantMinterRoleTxn.wait();
  //   });
  //   it("Check that acc2 has a minter role", async () => {
  //     expect(await seedNft.hasRole(minterRoleBytes, acc2.address)).to.equal(true);
  //   });
  // });

  // describe("Revoke Minter Role from acc2", () => {
  //   before("revoke role func", async () => {
  //     const RevokeMinterRoleTxn = await seedNft.connect(acc1).revokeRole(minterRoleBytes, acc2.address);
  //     await RevokeMinterRoleTxn.wait();
  //   });
  //   it("Check that acc2 has not a minter role", async () => {
  //     expect(await seedNft.hasRole(minterRoleBytes, acc2.address)).to.equal(false);
  //   });
  // });
});
