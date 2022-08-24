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
    bool public freeMint;

    uint256 totalPurchaseTokens;
    uint256 public priceInNativeTokens;

    address public nftContract;
    address public TREASURY;

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
        uint256 _priceInNativeTokens,
        address _treasury
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
        TREASURY = _treasury;
    }

    // Set treasury where tokens will get withdrawn
    function setTreasury(address _treasury) external onlyOwner {
        TREASURY = _treasury;
    }

    function setFreeMint(bool _freeMint) external onlyOwner {
        freeMint = _freeMint;
    }

    // Set NFT price in ERC20 tokens
    function setPurchaseTokenPrice(address _erc20Token, uint256 _erc20Price)
        external
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
        external
        onlyOwner
    {
        priceInNativeTokens = _priceInNativeTokens;
    }

    // Pause sale
    function setSaleActive(bool _active) external onlyOwner {
        saleActive = _active;
    }

    // Get purchase token details
    function getPurchaseTokenDetails()
        external
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
    // NFT contract need to expose mintToken function
    function purchaseNFT(address _purchaseToken)
        external
        purchaseEnabled
        nonReentrant
    {
        if (!freeMint) {
            require(priceInERC20Tokens[_purchaseToken] > 0, "Incorrect AMOUNT");
            // Customize for non standard ERC20 tokens
            require(
                IERC20(_purchaseToken).transferFrom(
                    msg.sender,
                    address(this),
                    priceInERC20Tokens[_purchaseToken]
                ),
                "!TRANSFER"
            );
        }
        IERC721(nftContract).mintToken(msg.sender);
    }

    function purchaseNFTByNativeTokens()
        external
        payable
        purchaseEnabled
        nonReentrant
    {
        if (!freeMint) {
            require(priceInNativeTokens == msg.value, "Incorrect AMOUNT");
        }
        IERC721(nftContract).mintToken(msg.sender);
    }

    // Admin can withdraw all tokens to TREASURY
    function withdrawTokenPayments(address _erc20Token)
        external
        onlyOwner
        nonReentrant
    {
        // In case of Non standard ERC20 tokens change this function
        require(IERC20(_erc20Token).balanceOf(address(this)) > 0, "!BALANCE");
        IERC20(_erc20Token).transfer(
            TREASURY,
            IERC20(_erc20Token).balanceOf(address(this))
        );
    }

    // Admin can withdraw all native tokens to TREASURY
    function withdrawNativeTokenPayments() external onlyOwner nonReentrant {
        require(address(this).balance > 0, "!BALANCE");
        payable(TREASURY).transfer(address(this).balance);
    }
}
