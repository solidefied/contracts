const { ethers } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");

const main = async () => {

    const addresses = ["0xC9895432258a4f011Aa57b87c71E5815c12C469d", "0xe75e299247f8f62036Ab7611306A6a50394caa65", "0xabe21e003E1a3677e3dE35F5a8CC87abB2478B59", "0x2998bdc4cc8dB9CfD17878f528C73caEc8FBC6b8"]
    const leaves = addresses.map(x => keccak256(x));
    tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    buf2Hex = x => "0x" + x.toString('hex');
    const root = buf2Hex(tree.getRoot());
    console.log('root: ', root);

    const [acc1, acc2] = await ethers.getSigners();
    console.log('acc1: ', acc1.address);
    console.log('acc2: ', acc2.address);

    const nftContract = await ethers.getContractFactory("Governor");
    const nft = await nftContract.deploy(acc2.address, "test.com", 400);
    await nft.deployed();
    console.log('nft: ', nft.address);

    const token1Contract = await ethers.getContractFactory("Token");
    const usdt = await token1Contract.deploy("USDT", "USDT");
    await usdt.deployed();
    console.log('usdt: ', usdt.address);

    const token2Contract = await ethers.getContractFactory("Token");
    const usdc = await token2Contract.deploy("USDC", "USDC");
    await usdc.deployed();
    console.log('usdc: ', usdc.address);

    const token3Contract = await ethers.getContractFactory("BaseERC20");
    const dai = await token3Contract.deploy("Dai", "Dai");
    await dai.deployed();
    console.log('dai: ', dai.address);

    const SingleSaleV2 = await ethers.getContractFactory("NFTPrimaryMint");
    const singleSaleV2 = await SingleSaleV2.deploy(nft.address, acc2.address, ethers.BigNumber.from(10).pow(18).mul(2), 102200, usdt.address, usdc.address, dai.address, root);
    await singleSaleV2.deployed();
    console.log('singleSaleV2: ', singleSaleV2.address);
}

main().then(() => process.exit(0)).catch((err) => { console.log(err); process.exit(1); })