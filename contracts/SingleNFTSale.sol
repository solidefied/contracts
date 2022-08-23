// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IERC721 {
    function mintToken(address _receiver) external;

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function MINTER_ROLE() external view returns (bytes32);
}

contract SingleNFTSale is ReentrancyGuard, Ownable {
    bool public saleActive;

    uint256 totalPurchaseTokens;
    uint256 public priceInNativeTokens;

    address public nftContract;

    // Token index => Token address
    mapping(uint256 => address) purchaseTokens;
    // Token address => Price
    mapping(address => uint256) public priceInERC20Tokens;

    modifier purchaseEnabled() {
        require(
            IERC721(nftContract).hasRole(
                IERC721(nftContract).MINTER_ROLE(),
                address(this)
            ),
            "!MINTER"
        );
        require(saleActive, "!SALE");
        _;
    }

    // Owner can add multiple ERC20 tokens as purchase currency
    // Prices should be w.r.t coresponding token decimals
    constructor(
        address _nftContract,
        address[] memory _erc20Tokens,
        uint256[] memory _erc20Prices,
        uint256 _priceInNativeTokens
    ) {
        nftContract = _nftContract;
        for (uint8 i; i < _erc20Tokens.length; i++) {
            require(purchaseTokens[i] == address(0), "Invalid TOKEN");
            purchaseTokens[i] = _erc20Tokens[i];
            priceInERC20Tokens[_erc20Tokens[i]] = _erc20Prices[i];
        }
        priceInNativeTokens = _priceInNativeTokens;
        totalPurchaseTokens = _erc20Tokens.length;
        saleActive = true;
    }

    // Set NFT price in ERC20 tokens
    function setPurchaseTokenPrice(address _erc20Token, uint256 _erc20Price)
        public
        onlyOwner
    {
        bool existingToken;
        for (uint8 i; i < totalPurchaseTokens; i++) {
            if (purchaseTokens[i] == _erc20Token) {
                priceInERC20Tokens[_erc20Token] = _erc20Price;
                existingToken = true;
            }
        }
        if (!existingToken) {
            totalPurchaseTokens += 1;
            purchaseTokens[totalPurchaseTokens] = _erc20Token;
            priceInERC20Tokens[_erc20Token] = _erc20Price;
        }
    }

    // Set NFT price in native tokens
    function setPurchaseNativeTokenPrice(uint256 _priceInNativeTokens)
        public
        onlyOwner
    {
        priceInNativeTokens = _priceInNativeTokens;
    }

    // Pause feature for individual sales
    function setSaleActive(bool _active) public onlyOwner {
        saleActive = _active;
    }

    // Get purchase token details
    function getPurchaseTokenDetails()
        public
        view
        returns (
            address[] memory _purchaseToken,
            uint256[] memory _priceInERC20Tokens
        )
    {
        _purchaseToken = new address[](totalPurchaseTokens);
        _priceInERC20Tokens = new uint256[](totalPurchaseTokens);
        for (uint8 i; i < totalPurchaseTokens; i++) {
            _purchaseToken[i] = purchaseTokens[i];
            _priceInERC20Tokens[i] = priceInERC20Tokens[purchaseTokens[i]];
        }
    }

    // NFT collection owner need to give minter role to sale contract to let users purchase NFTs
    function purchaseNFT(address _purchaseToken)
        public
        purchaseEnabled
        nonReentrant
    {
        uint256 price = priceInERC20Tokens[_purchaseToken];
        IERC20(_purchaseToken).transferFrom(msg.sender, address(this), price);
        // NFT contract need to expose mintToken function
        IERC721(nftContract).mintToken(msg.sender);
    }

    function purchaseNFTByNativeTokens()
        public
        payable
        purchaseEnabled
        nonReentrant
    {
        require(priceInNativeTokens == msg.value, "Incorrect AMOUNT");
        // NFT contract need to expose mintToken function
        IERC721(nftContract).mintToken(msg.sender);
    }

    // Ony NFT admin can withdraw ERC20 tokens from NFT sale
    // function withdrawTokenPayments(address _nftContract, address _erc20Token, address _receiver) public onlyNFTContractAdmin(_nftContract) nonReentrant {
    //     require(saleTokenBalance[_nftContract][_erc20Token] > 0, "!BALANCE");
    //     uint256 balance = saleTokenBalance[_nftContract][_erc20Token];
    //     saleTokenBalance[_nftContract][_erc20Token] = 0;
    //     IERC20(_erc20Token).transfer(_receiver, balance);
    // }

    // // Ony NFT admin can withdraw tokens from NFT sale
    // function withdrawNativeTokenPayments(address _nftContract, address _receiver) public onlyNFTContractAdmin(_nftContract) nonReentrant {
    //     require(saleNativeTokenBalance[_nftContract] > 0, "!BALANCE");
    //     uint256 balance = saleNativeTokenBalance[_nftContract];
    //     saleNativeTokenBalance[_nftContract] = 0;
    //     payable(_receiver).transfer(balance);
    // }

    // Admin can withdraw all tokens
    function withdrawTokenPayments(address _erc20Token, address _receiver)
        public
        onlyOwner
        nonReentrant
    {
        // In case of Non standard ERC20 tokens change this function
        require(IERC20(_erc20Token).balanceOf(address(this)) > 0, "!BALANCE");
        IERC20(_erc20Token).transfer(
            _receiver,
            IERC20(_erc20Token).balanceOf(address(this))
        );
    }

    // Admin can withdraw all native tokens
    function withdrawNativeTokenPayments(address _receiver)
        public
        onlyOwner
        nonReentrant
    {
        require(address(this).balance > 0, "!BALANCE");
        payable(_receiver).transfer(address(this).balance);
    }
}
