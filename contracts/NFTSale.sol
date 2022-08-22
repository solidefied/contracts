//SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
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

    function ADMIN_ROLE() external view returns (bytes32);

    function MINTER_ROLE() external view returns (bytes32);
}

contract NFTSale is ReentrancyGuard {
    uint256 public totalSales;

    struct Sale {
        bool active;
        bool whitelistingActive;
        uint256 nativeTokenPrice;
        uint256 totalPurchaseTokens;
        mapping(address => bool) whitelist;
        mapping(address => uint256) purchasePrice;
        mapping(uint256 => address) purchaseToken;
    }

    //NFT collection address => Sale details
    mapping(address => Sale) saleDetails;
    //User address => Token address => balance
    mapping(address => mapping(address => uint256)) public userTokenBalance;
    //User address => Native token balance
    mapping(address => uint256) public userNativeTokenBalance;

    // Only NFT contract admins can add sale
    modifier onlyNFTContractAdmin(address _nftContract) {
        require(
            IERC721(_nftContract).hasRole(
                IERC721(_nftContract).ADMIN_ROLE(),
                msg.sender
            ),
            "!NFT Contract ADMIN"
        );
        _;
    }

    // Only collection owner can add listing
    // Owner can add multiple ERC20 tokens as purchase currency
    // Prices should be w.r.t coresponding token decimals
    function addSale(
        address _nftContract,
        address[] memory _erc20Tokens,
        uint256[] memory _erc20Prices,
        uint256 _nativeTokenPrice
    ) public onlyNFTContractAdmin(_nftContract) {
        require(
            saleDetails[_nftContract].active == false,
            "Collection previously listed"
        );
        for (uint8 i; i < _erc20Tokens.length; i++) {
            require(
                saleDetails[_nftContract].purchaseToken[i] == address(0),
                "Invalid TOKEN"
            );
            saleDetails[_nftContract].purchaseToken[i] = _erc20Tokens[i];
            saleDetails[_nftContract].purchasePrice[
                _erc20Tokens[i]
            ] = _erc20Prices[i];
        }
        saleDetails[_nftContract].nativeTokenPrice = _nativeTokenPrice;
        saleDetails[_nftContract].totalPurchaseTokens = _erc20Tokens.length;
        saleDetails[_nftContract].active = true;
        totalSales += 1;
    }

    // Set NFT price in ERC20 tokens
    function setPurchaseTokenPrice(
        address _nftContract,
        address _erc20Token,
        uint256 _erc20Price
    ) public onlyNFTContractAdmin(_nftContract) {
        bool existingToken;
        for (uint8 i; i < saleDetails[_nftContract].totalPurchaseTokens; i++) {
            if (saleDetails[_nftContract].purchaseToken[i] == _erc20Token) {
                saleDetails[_nftContract].purchasePrice[
                    _erc20Token
                ] = _erc20Price;
                existingToken = true;
            }
        }
        if (!existingToken) {
            saleDetails[_nftContract].totalPurchaseTokens += 1;
            saleDetails[_nftContract].purchaseToken[
                saleDetails[_nftContract].totalPurchaseTokens
            ] = _erc20Token;
            saleDetails[_nftContract].purchasePrice[_erc20Token] = _erc20Price;
        }
    }

    // Set NFT price in native tokens
    function setPurchaseNativeTokenPrice(
        address _nftContract,
        uint256 _nativeTokenPrice
    ) public onlyNFTContractAdmin(_nftContract) {
        saleDetails[_nftContract].nativeTokenPrice = _nativeTokenPrice;
    }

    // Pause feature for individual sales
    function setSaleActive(address _nftContract, bool _active)
        public
        onlyNFTContractAdmin(_nftContract)
    {
        saleDetails[_nftContract].active = _active;
    }

    // Set whitelist addresses
    function setWhitelist(address _nftContract, address[] calldata _whitelist)
        public
        onlyNFTContractAdmin(_nftContract)
    {
        for (uint256 i; i < _whitelist.length; i++) {
            saleDetails[_nftContract].whitelist[_whitelist[i]] = true;
        }
    }

    // Enable/disable whitelisting
    function setWhitelistingActive(address _nftContract, bool _active)
        public
        onlyNFTContractAdmin(_nftContract)
    {
        saleDetails[_nftContract].whitelistingActive = _active;
    }

    // Get sale details
    function getSaleDetails(address _nftContract)
        public
        view
        returns (
            address[] memory _purchaseToken,
            uint256[] memory _purchasePrice,
            uint256 _nativeTokenPrice,
            bool _active,
            bool _whitelistingActive
        )
    {
        _purchaseToken = new address[](
            saleDetails[_nftContract].totalPurchaseTokens
        );
        _purchasePrice = new uint256[](
            saleDetails[_nftContract].totalPurchaseTokens
        );
        for (uint8 i; i < saleDetails[_nftContract].totalPurchaseTokens; i++) {
            _purchaseToken[i] = saleDetails[_nftContract].purchaseToken[i];
            _purchasePrice[i] = saleDetails[_nftContract].purchasePrice[
                saleDetails[_nftContract].purchaseToken[i]
            ];
        }
        _nativeTokenPrice = saleDetails[_nftContract].nativeTokenPrice;
        _active = saleDetails[_nftContract].active;
        _whitelistingActive = saleDetails[_nftContract].whitelistingActive;
    }

    // Check if whitelisted in sale
    function checkUserWhitelisted(address _nftContract, address _userAddress)
        public
        view
        returns (bool _whitelisted)
    {
        _whitelisted = saleDetails[_nftContract].whitelist[_userAddress];
    }

    // NFT collection owner need to give minter role to sale contract to let users purchase NFTs
    // To purchase using ERC20 token pass ERC20 token address in _purchaseToken
    // To purchase using native tokens send native token while _purchaseToken is ZERO_ADDR
    function purchaseNFT(address _nftContract, address _purchaseToken)
        public
        payable
        nonReentrant
    {
        require(
            IERC721(_nftContract).hasRole(
                IERC721(_nftContract).MINTER_ROLE(),
                address(this)
            ),
            "!MINTER"
        );
        require(saleDetails[_nftContract].active, "!SALE");
        require(
            saleDetails[_nftContract].whitelistingActive == false ||
                saleDetails[_nftContract].whitelist[msg.sender],
            "!WHITELISTED"
        );
        if (_purchaseToken == address(0)) {
            require(
                saleDetails[_nftContract].nativeTokenPrice == msg.value,
                "Incorrect AMOUNT"
            );
            userNativeTokenBalance[msg.sender] += msg.value;
        } else {
            uint256 price = saleDetails[_nftContract].purchasePrice[
                _purchaseToken
            ];
            // Keeping earnings in sale contract
            userTokenBalance[msg.sender][_purchaseToken] += price;
            IERC20(_purchaseToken).transferFrom(
                msg.sender,
                address(this),
                price
            );
        }
        // NFT contract need to expose mintToken function
        IERC721(_nftContract).mintToken(msg.sender);
    }

    function withdrawTokenPayments(address _erc20Token) public nonReentrant {
        require(userTokenBalance[msg.sender][_erc20Token] > 0, "!BALANCE");
        uint256 balance = userTokenBalance[msg.sender][_erc20Token];
        userTokenBalance[msg.sender][_erc20Token] = 0;
        IERC20(_erc20Token).transfer(msg.sender, balance);
    }

    function withdrawNativeTokenPayments() public nonReentrant {
        require(userNativeTokenBalance[msg.sender] > 0, "!BALANCE");
        uint256 balance = userNativeTokenBalance[msg.sender];
        userNativeTokenBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }
}