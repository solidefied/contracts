const { ethers } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");

const main = async () => {
    const addresses = ["0xC9895432258a4f011Aa57b87c71E5815c12C469d", "0xe75e299247f8f62036Ab7611306A6a50394caa65", "0x1c0316FE3Aa6615a327B2f99692c7851c5C034Ce", "0xe1b0950be2aFDE015234f5E6f2234028D1E82156"]
    const leaves = addresses.map(x => keccak256(x));
    tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    buf2Hex = x => "0x" + x.toString('hex');
    const root = buf2Hex(tree.getRoot());
    console.log('root: ', root);

    const [acc1, acc2] = await ethers.getSigners();
    console.log('acc1: ', acc1.address);
    console.log('acc2: ', acc2.address);

    // const nftContract = await ethers.getContractFactory("Governor");
    // const nft = await nftContract.deploy(acc2.address, "test.com", 400);
    // await nft.deployed();
    // console.log('nft: ', nft.address);

    // const token1Contract = await ethers.getContractFactory("TetherToken");
    // const usdt = await token1Contract.deploy(1000, "USDT", "USDT", 6);
    // await usdt.deployed();
    // console.log('usdt: ', usdt.address);

    // const token2Contract = await ethers.getContractFactory("FakeUSDC");
    // const usdc = await token2Contract.deploy();
    // await usdc.deployed();
    // console.log('usdc: ', usdc.address);

    // const token3Contract = await ethers.getContractFactory("Dai");
    // const dai = await token3Contract.deploy(80001);
    // await dai.deployed();
    // console.log('dai: ', dai.address);

    const SingleSaleV2 = await ethers.getContractFactory("RaiseSale");
    const singleSaleV2 = await SingleSaleV2.deploy(ethers.BigNumber.from(10).pow(6).mul(300), ethers.BigNumber.from(10).pow(6).mul(150), "0x7723C983e2f58cecDbDD6E1C800e8E0B57e27Fd5", "0x1B4F6B9610Fa36567F2a66E99a744601d086f337", "0xA18a7aD649FbBcf9Fa84c32aeD02748ca4CD103d", root);
    await singleSaleV2.deployed();
    console.log('singleSaleV2: ', singleSaleV2.address);
}

main().then(() => process.exit(0)).catch((err) => { console.log(err); process.exit(1); })