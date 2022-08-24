const { expect } = require("chai");
const { ethers } = require("hardhat");
describe("Sale", function () {
  let token;
  let token2;
  let sale;
  var acc1;
  var acc2;
  var acc3;
  var acc4;
  before(async function () {
    [acc1, acc2, acc3, acc4] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("BaseERC20");
    token = await Token.deploy("TestToken", "TT");
    await token.deployed();
    const Token2 = await ethers.getContractFactory("BaseERC20");
    token2 = await Token2.deploy("TestToken2", "TT2");
    await token2.deployed();
    const Sale = await ethers.getContractFactory("Sale1");
    sale = await Sale.deploy(4, token.address, ethers.BigNumber.from(10).pow(18).mul(10000), ethers.BigNumber.from(10).pow(18).mul(1000));
    const startSale = await sale.connect(acc1).startPresale();
    await startSale.wait();
  });

  it("Test that initialized value should be as equal to as it was submited", async () => {
    expect(await token.decimals()).to.equal(18);

    expect(await token.name()).to.equal("TestToken");

    expect(await token.symbol()).to.equal("TT");

    expect(await sale.hardcap()).to.equal(ethers.BigNumber.from(10).pow(18).mul(10000));

    expect(await sale.allowedUserBalance()).to.equal(ethers.BigNumber.from(10).pow(18).mul(1000));

    expect(await sale.rate()).to.equal(4);
  });

  describe("Buying Token", () => {
    before("triggering funcs by user", async () => {
      const transferToken = await token.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(18).mul(1000));
      await transferToken.wait();

      const approveCall = await token.connect(acc2).approve(sale.address, ethers.BigNumber.from(2).pow(256).sub(1));
      await approveCall.wait();

      const buyTokenWithUSDTSendfunc = await sale.connect(acc2).buyTokenWithUSDT(ethers.BigNumber.from(10).pow(18).mul(100));
      await buyTokenWithUSDTSendfunc.wait();
    });

    it("Test that claimable amount should be 400 ETH", async function () {
      expect(await sale.claimable(acc2.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(400));
    });
  });

  describe("Change User allowed balance ", () => {
    before("triggering funcs by owner", async () => {
      const changeAllowedBalanceAmount = await sale.connect(acc1).changeAllowedUserBalance(ethers.BigNumber.from(10).pow(18).mul(1500));
      await changeAllowedBalanceAmount.wait();
    });

    it("Test that User allowed balance should be 1500", async function () {
      expect(await sale.allowedUserBalance()).to.equal(ethers.BigNumber.from(10).pow(18).mul(1500));
    });
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).changeAllowedUserBalance(ethers.BigNumber.from(10).pow(18).mul(1500))).to.be.revertedWith("Ownable: caller is not the owner")
    });
  });

  describe("Change hardcap ", () => {
    before("triggering funcs by owner", async () => {
      const changeHardCapAmount = await sale.connect(acc1).changeHardCap(ethers.BigNumber.from(10).pow(18).mul(15000));
      await changeHardCapAmount.wait();
    });

    it("Test that Hardcap amount should be 15000", async function () {
      expect(await sale.hardcap()).to.equal(ethers.BigNumber.from(10).pow(18).mul(15000));
    });
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).changeHardCap(ethers.BigNumber.from(10).pow(18).mul(15000))).to.be.revertedWith("Ownable: caller is not the owner")
    });
  });

  describe("Change Rate ", () => {
    before("triggering funcs by owner", async () => {
      const changeRateValue = await sale.connect(acc1).changeRate(5);
      await changeRateValue.wait();
    });

    it("Test that Rate value should be 5", async function () {
      expect(await sale.rate()).to.equal(5);
    });
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).changeRate(5)).to.be.revertedWith("Ownable: caller is not the owner")
    });
  });

  describe("Change Ownership to acc3 ", () => {
    before("triggering funcs by owner", async () => {
      const changeOwner = await sale.connect(acc1).transferOwnership(acc3.address);
      await changeOwner.wait();
    });

    it("Test that Rate value should be 5", async function () {
      expect(await sale.owner()).to.equal(acc3.address);
    });
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).transferOwnership(acc4.address)).to.be.revertedWith("Ownable: caller is not the owner")
    })
  });

  describe("Fund withdraw", () => {
    it("Error:Test that func should throw error for round is not over yet", async () => {
      await expect(sale.connect(acc3).fundsWithdrawal(ethers.BigNumber.from(10).pow(18).mul(10))).to.be.revertedWith("The Private Sale Round 1 is not over")
    })
  });

  describe("Transfer ERC20 Token", () => {
    before("triggering funcs by owner", async () => {
      const transferToken2ToAcc2 = await token2.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(18).mul(100));
      await transferToken2ToAcc2.wait();
      const worngTrnsfer = await token2.connect(acc2).transfer(sale.address, ethers.BigNumber.from(10).pow(18).mul(50));
      await worngTrnsfer.wait();
      const transferTokenFromSale = await sale.connect(acc3).transferAnyERC20Tokens(token2.address, ethers.BigNumber.from(10).pow(18).mul(50));
      await transferTokenFromSale.wait();
    });
    it("check token is transfered or not", async () => {
      expect(await token2.balanceOf(acc3.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(50));
    })
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).transferAnyERC20Tokens(token2.address, ethers.BigNumber.from(10).pow(18).mul(50))).to.be.revertedWith("Ownable: caller is not the owner")
    })
  });

  describe("End sale and transfer remain amount to acc3", () => {
    before("triggering funcs by owner", async () => {
      const endSale = await sale.connect(acc3).endPresale();
      await endSale.wait();
      const withdrawFund = await sale.connect(acc3).fundsWithdrawal(ethers.BigNumber.from(10).pow(18).mul(10));
      await withdrawFund.wait();
    });
    it("check amount is transfered or not", async () => {
      expect(await token.balanceOf(acc3.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(10));
    })
  });

  describe("Renounce Ownership", () => {
    before("triggering funcs by owner", async () => {
      const changeOwnerToNullAdrs = await sale.connect(acc3).renounceOwnership();
      await changeOwnerToNullAdrs.wait();

    });
    it("check owner is null address or not", async () => {
      expect(await sale.owner()).to.equal("0x0000000000000000000000000000000000000000");
    })
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).renounceOwnership()).to.be.revertedWith("Ownable: caller is not the owner")
    })
  });

});