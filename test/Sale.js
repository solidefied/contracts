const { expect } = require("chai");
const { ethers } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");
describe("Sale", function () {
  let USDT;
  let USDC;
  let DAI;
  let sale;
  var acc1;
  var acc2;
  var acc3;
  var acc4;
  var acc5;
  var acc6;
  let tree;
  var buf2Hex;
  const zeroAdd = "0x0000000000000000000000000000000000000000";

  before(async function () {
    [acc1, acc2, acc3, acc4, acc5, acc6] = await ethers.getSigners();
    const addresses = [acc1.address, acc2.address, acc3.address, acc4.address]
    const leaves = addresses.map(x => keccak256(x));
    tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    buf2Hex = x => "0x" + x.toString('hex');
    const root = buf2Hex(tree.getRoot());
    console.log('root: ', root);

    const token1Contract = await ethers.getContractFactory("TetherToken");
    USDT = await token1Contract.deploy(10000000000, "USDT", "USDT", 6);
    await USDT.deployed();
    const token2Contract = await ethers.getContractFactory("FakeUSDC");
    const transferToken = await USDT.connect(acc1).transfer(acc2.address, ethers.BigNumber.from(10).pow(6).mul(200));
    await transferToken.wait();
    USDC = await token2Contract.deploy();
    await USDC.deployed();
    const mintUSDCtoAcc2 = await USDC.connect(acc1).mint(acc2.address, ethers.BigNumber.from(10).pow(6).mul(300))
    await mintUSDCtoAcc2.wait();
    const mintUSDCtoAcc3 = await USDC.connect(acc1).mint(acc3.address, ethers.BigNumber.from(10).pow(6).mul(500))
    await mintUSDCtoAcc3.wait();
    const token3Contract = await ethers.getContractFactory("Dai");
    DAI = await token3Contract.deploy(80001); //chainId as params
    await DAI.deployed();
    const mintDAI = await DAI.connect(acc1).mint(acc4.address, ethers.BigNumber.from(10).pow(18).mul(300))
    await mintDAI.wait();
    const Sale = await ethers.getContractFactory("RaiseSale");
    sale = await Sale.deploy(ethers.BigNumber.from(10).pow(6).mul(300), ethers.BigNumber.from(10).pow(6).mul(100), USDT.address, USDC.address, DAI.address, root);
    await sale.deployed();
    const checkSetToTrue = await sale.connect(acc1).setWhitelist(true);
    await checkSetToTrue.wait();
  });

  it("Initial value checks", async () => {
    expect(await sale.owner()).to.equal(acc1.address);
    expect(await sale.paused()).to.equal(false);
    expect(await sale.iswhitelis()).to.equal(true);
    expect(await sale.priceInUSD()).to.equal(5000000);
    expect(await sale.USDT()).to.equal(USDT.address);
    expect(await sale.USDC()).to.equal(USDC.address);
    expect(await sale.DAI()).to.equal(DAI.address);
    expect(await sale.hardcap()).to.equal(ethers.BigNumber.from(10).pow(6).mul(300));
    expect(await sale.allowedUserBalance()).to.equal(ethers.BigNumber.from(10).pow(6).mul(100));
  });

  describe("Buying Token with USDT", () => {
    before("triggering funcs by user", async () => {
      const approveCall = await USDT.connect(acc2).approve(sale.address, ethers.BigNumber.from(2).pow(256).sub(1));
      await approveCall.wait();

      const proof = tree.getProof(keccak256(acc2.address)).map(x => buf2Hex(x.data))

      const buyTokenWithUSDTSendfunc = await sale.connect(acc2).buyToken(USDT.address, ethers.BigNumber.from(10).pow(6).mul(50), proof);
      await buyTokenWithUSDTSendfunc.wait();
    });

    it("Test that claimable amount should be 10 ETH", async function () {
      expect(await sale.claimable(acc2.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(10));
    });

    it("ERROR:Non-Whitelisted user cannot buy token", async () => {
      const proof = tree.getProof(keccak256(acc5.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc5).buyToken(USDT.address, ethers.BigNumber.from(10).pow(6).mul(5), proof)).to.be.revertedWith("Unauthorized")
    });

    it("ERROR:user cannot buy token with wrong token", async () => {
      const proof = tree.getProof(keccak256(acc2.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc2).buyToken(zeroAdd, ethers.BigNumber.from(10).pow(6).mul(5), proof)).to.be.revertedWith("Invalid TOKEN")
    });
  });

  describe("Buying Token with USDT by buyTokenUSDT", () => {
    before("triggering funcs by user", async () => {

      const proof = tree.getProof(keccak256(acc2.address)).map(x => buf2Hex(x.data))

      const buyTokenWithUSDTSendfunc = await sale.connect(acc2).buyTokenUSDT(ethers.BigNumber.from(10).pow(6).mul(50), proof);
      await buyTokenWithUSDTSendfunc.wait();
    });

    it("Test that claimable amount should be 20 ETH", async function () {
      expect(await sale.claimable(acc2.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(20));
    });

    it("ERROR:Non-Whitelisted user cannot buy token", async () => {
      const proof = tree.getProof(keccak256(acc5.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc5).buyToken(USDT.address, ethers.BigNumber.from(10).pow(6).mul(5), proof)).to.be.revertedWith("Unauthorized")
    });

    it("ERROR:user cannot buy token with wrong token", async () => {
      const proof = tree.getProof(keccak256(acc2.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc2).buyToken(zeroAdd, ethers.BigNumber.from(10).pow(6).mul(5), proof)).to.be.revertedWith("Invalid TOKEN")
    });
  });

  describe("Buying Token with USDC", () => {
    before("triggering funcs by user", async () => {
      const approveCall = await USDC.connect(acc3).approve(sale.address, ethers.BigNumber.from(2).pow(256).sub(1));
      await approveCall.wait();

      const proof = tree.getProof(keccak256(acc3.address)).map(x => buf2Hex(x.data))

      const buyTokenWithUSDTSendfunc = await sale.connect(acc3).buyToken(USDC.address, ethers.BigNumber.from(10).pow(6).mul(100), proof);
      await buyTokenWithUSDTSendfunc.wait();
    });

    it("Test that claimable amount should be 20 ETH", async function () {
      expect(await sale.claimable(acc3.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(20));
    });

    it("ERROR:Non-Whitelisted user cannot buy token", async () => {
      const proof = tree.getProof(keccak256(acc5.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc5).buyToken(USDC.address, ethers.BigNumber.from(10).pow(6).mul(5), proof)).to.be.revertedWith("Unauthorized")
    });

    it("ERROR:user cannot buy token with wrong token", async () => {
      const proof = tree.getProof(keccak256(acc3.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc3).buyToken(zeroAdd, ethers.BigNumber.from(10).pow(6).mul(5), proof)).to.be.revertedWith("Invalid TOKEN")
    });
  });

  describe("Buying Token with DAI", () => {
    before("triggering funcs by user", async () => {
      const approveCall = await DAI.connect(acc4).approve(sale.address, ethers.BigNumber.from(2).pow(256).sub(1));
      await approveCall.wait();

      const proof = tree.getProof(keccak256(acc4.address)).map(x => buf2Hex(x.data))

      const buyTokenWithUSDTSendfunc = await sale.connect(acc4).buyToken(DAI.address, ethers.BigNumber.from(10).pow(18).mul(100), proof);
      await buyTokenWithUSDTSendfunc.wait();
    });

    it("Test that claimable amount should be 1 ETH", async function () {
      expect(await sale.claimable(acc4.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(20));
    });

    it("ERROR:Non-Whitelisted user cannot buy token", async () => {
      const proof = tree.getProof(keccak256(acc5.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc5).buyToken(DAI.address, ethers.BigNumber.from(10).pow(18).mul(5), proof)).to.be.revertedWith("Unauthorized")
    });

    it("ERROR:user cannot buy token with wrong token", async () => {
      const proof = tree.getProof(keccak256(acc4.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc4).buyToken(DAI.address, ethers.BigNumber.from(10).pow(18).mul(5), proof)).to.be.revertedWith("Hardcap reached")
    });
  });

  describe("Change hardcap ", () => {
    before("triggering funcs by owner", async () => {
      const changeHardCapAmount = await sale.connect(acc1).changeHardCap(ethers.BigNumber.from(10).pow(18).mul(380));
      await changeHardCapAmount.wait();
    });
    it("Test that Hardcap amount should be 380", async function () {
      expect(await sale.hardcap()).to.equal(ethers.BigNumber.from(10).pow(18).mul(380));
    });
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).changeHardCap(ethers.BigNumber.from(10).pow(18).mul(300))).to.be.revertedWith("Ownable: caller is not the owner")
    });
  });

  describe("Purchase new token in sale", () => {
    it("Error:User should get error if amount is greater then allowed token amount", async () => {
      const proof = tree.getProof(keccak256(acc4.address)).map(x => buf2Hex(x.data))
      await expect(sale.connect(acc4).buyToken(DAI.address, ethers.BigNumber.from(10).pow(18).mul(100), proof)).to.be.revertedWith("Exceeded allowance")
    })
  })

  describe("Change User allowed balance ", () => {
    before("triggering funcs by owner", async () => {
      const changeAllowedBalanceAmount = await sale.connect(acc1).changeAllowedUserBalance(ethers.BigNumber.from(10).pow(18).mul(150));
      await changeAllowedBalanceAmount.wait();
    });

    it("Test that User allowed balance should be 150", async function () {
      expect(await sale.allowedUserBalance()).to.equal(ethers.BigNumber.from(10).pow(18).mul(150));
    });
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).changeAllowedUserBalance(ethers.BigNumber.from(10).pow(18).mul(150))).to.be.revertedWith("Ownable: caller is not the owner")
    });
  });


  describe("Change Ownership to acc5 ", () => {
    before("triggering funcs by owner", async () => {
      const changeOwner = await sale.connect(acc1).transferOwnership(acc5.address);
      await changeOwner.wait();
    });

    it("Acc5 should be the owner", async function () {
      expect(await sale.owner()).to.equal(acc5.address);
    });
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).transferOwnership(acc4.address)).to.be.revertedWith("Ownable: caller is not the owner")
    })
  });

  describe("Fund withdraw", () => {
    it("Error:Test that func should throw error for round is not over yet", async () => {
      await expect(sale.connect(acc5).fundsWithdrawal(USDT.address, ethers.BigNumber.from(10).pow(18).mul(10))).to.be.revertedWith("Pausable: not paused")
    })
  });

  describe("Transfer ERC20 Token", () => {
    before("triggering funcs by owner", async () => {
      const worngTrnsfer = await USDC.connect(acc2).transfer(sale.address, ethers.BigNumber.from(10).pow(6).mul(50));
      await worngTrnsfer.wait();
      const pauseSale = await sale.connect(acc5).pause();
      await pauseSale.wait();
      const transferTokenFromSale = await sale.connect(acc5).fundsWithdrawal(USDC.address, ethers.BigNumber.from(10).pow(6).mul(50));
      await transferTokenFromSale.wait();
    });
    it("check token is transfered or not", async () => {
      expect(await USDC.balanceOf(acc1.address)).to.equal(ethers.BigNumber.from(10).pow(6).mul(50));
    })
    it("Error:Test that func should throw error for non-owner address", async () => {
      await expect(sale.connect(acc2).fundsWithdrawal(USDC.address, ethers.BigNumber.from(10).pow(6).mul(50))).to.be.revertedWith("Ownable: caller is not the owner")
    })
  });

  describe("transfer Eth", () => {
    before("triggering funcs by owner", async () => {
      const signer = ethers.provider.getSigner(acc2.address)
      await signer.sendTransaction({
        to: sale.address,
        value: ethers.utils.parseEther("5")
      })
      const sendETHBackToTreasury = await sale.connect(acc5).withdrawETH();
      await sendETHBackToTreasury.wait();
    })
    it("Check that ETH send back to Treasury", async () => {
      expect(await ethers.provider.getBalance(sale.address)).to.equal(ethers.BigNumber.from(10).pow(18).mul(0))
      expect(await ethers.provider.getBalance(acc1.address)).to.greaterThanOrEqual(ethers.BigNumber.from(10).pow(18).mul(10004))
    })
  })

  describe("transfer amount to treasury acc1", () => {
    before("triggering funcs by owner", async () => {
      const withdrawFund = await sale.connect(acc5).fundsWithdrawal(USDT.address, ethers.BigNumber.from(10).pow(6).mul(5));
      await withdrawFund.wait();
    });
    it("check amount is transfered or not", async () => {
      expect(await USDT.balanceOf(acc1.address)).to.equal(ethers.BigNumber.from(10).pow(6).mul(9805));
    })
  });

  describe("Set new treasury account", () => {
    before("triggering funcs by owner", async () => {
      const withdrawFund = await sale.connect(acc5).setTreasury(acc6.address);
      await withdrawFund.wait();
    });
    it("check that acc6 is treasury ", async () => {
      expect(await sale.TREASURY()).to.equal(acc6.address);
    })
  });

  describe("Renounce Ownership", () => {
    before("triggering funcs by owner", async () => {
      const changeOwnerToNullAdrs = await sale.connect(acc5).renounceOwnership();
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