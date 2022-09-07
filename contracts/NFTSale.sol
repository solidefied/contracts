/*
███████╗ ██████╗ ██╗     ██╗██████╗ ███████╗███████╗██╗███████╗██████╗ 
██╔════╝██╔═══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██║██╔════╝██╔══██╗
███████╗██║   ██║██║     ██║██║  ██║█████╗  █████╗  ██║█████╗  ██║  ██║
╚════██║██║   ██║██║     ██║██║  ██║██╔══╝  ██╔══╝  ██║██╔══╝  ██║  ██║
███████║╚██████╔╝███████╗██║██████╔╝███████╗██║     ██║███████╗██████╔╝
╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ 
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


interface IERC721 {
    function mintToken(address _receiver) external;
}

contract NFTPrimaryMint is ReentrancyGuard, Ownable,Pausable{

    bool public iswhitelistingEnabled;
    uint256 public priceInETH ; //80000000000000000; // 0.08 ETH
    uint256 public priceInUSD;
    address public nftContract;
    address public TREASURY;
    IERC20 public USDT;
    IERC20 public USDC;
    IERC20 public DAI;
    bytes32 public root;
    uint256 public CENTS = 10**4;

    // address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // 6 decimals
    // address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // 6 decimals
    // address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // 18 decimals

    constructor(
        address _nftContract,
        address _treasury,
        uint256 _priceInETH,
        uint256 _priceInUSD,
        address _usdtAddress,
        address _usdcAddress,
        address _daiAddress,
        bytes32 _root
    ) {
        nftContract = _nftContract;
        TREASURY = _treasury;
        priceInETH = _priceInETH;
        priceInUSD = _priceInUSD; //e.g. $10.22 => 102200
        USDT = IERC20(_usdtAddress);
        USDC = IERC20(_usdcAddress);
        DAI = IERC20(_daiAddress);
        root = _root;
    }

    modifier isWhitelisted(bytes32[] memory proof) {
        if(iswhitelistingEnabled){
            require(isValid(proof, keccak256(abi.encodePacked(msg.sender))), "Unauthorized");
        }
        _;
    }

    function isValid(bytes32[] memory proof, bytes32 leaf) public view returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }


    function setTreasury(address _treasury) external onlyOwner {
        TREASURY = _treasury;
    }
//Only Testing
    function setMerkleRoot(bytes32 _root) external onlyOwner {
         root =  _root;
    }

    function setPriceETH(uint _priceInETH) public onlyOwner {
        priceInETH = _priceInETH;
    }

    function setPriceUSD(uint _priceInUSD) public onlyOwner {
        priceInUSD = _priceInUSD;
    }

    function setWhitelist(bool _active) external onlyOwner {
        iswhitelistingEnabled = _active;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }





    function buyNFTWithToken(address _purchaseToken, bytes32[] memory proof) external whenNotPaused() nonReentrant isWhitelisted (proof) {
        require( IERC20(_purchaseToken) == USDT || IERC20(_purchaseToken) == USDC || IERC20(_purchaseToken) == DAI, "Invalid Token");
        uint amount = (priceInUSD * 10 ** (IERC20Metadata(_purchaseToken).decimals())) / CENTS;
        uint oBal = IERC20Metadata(_purchaseToken).balanceOf(address(this));
        IERC20(_purchaseToken).transferFrom(msg.sender, address(this), amount);
        uint nBal = IERC20Metadata(_purchaseToken).balanceOf(address(this));
        require(nBal >= oBal + amount,"Transfere Failed");
        IERC721(nftContract).mintToken(msg.sender);
    }

    function TESTINGbuyNFTWithToken(address _purchaseToken) external whenNotPaused() nonReentrant {
        require( IERC20(_purchaseToken) == USDT || IERC20(_purchaseToken) == USDC || IERC20(_purchaseToken) == DAI, "Invalid Token");
        uint amount = (priceInUSD * 10 ** (IERC20Metadata(_purchaseToken).decimals())) / CENTS;
        uint oBal = IERC20Metadata(_purchaseToken).balanceOf(address(this));
        IERC20(_purchaseToken).transferFrom(msg.sender, address(this), amount);
        uint nBal = IERC20Metadata(_purchaseToken).balanceOf(address(this));
        require(nBal >= oBal + amount,"Transfere Failed");
        IERC721(nftContract).mintToken(msg.sender);
    }


    function buyNFTWithETH(bytes32[] memory proof) external payable whenNotPaused() nonReentrant isWhitelisted(proof) {
        require(msg.value >= priceInETH, "Incorrect amount");
        IERC721(nftContract).mintToken(msg.sender);
    }

    function withdrawTokens(address _erc20Token) external onlyOwner nonReentrant whenPaused()
    {
         IERC20(_erc20Token).transfer(TREASURY, IERC20Metadata(_erc20Token).balanceOf(address(this)));

    }

    function withdrawETH() external onlyOwner nonReentrant whenPaused() {
        require(address(this).balance > 0, "!BALANCE");
        payable(TREASURY).transfer(address(this).balance);
    }
}