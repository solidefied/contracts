//SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC721Collection {
    function mintToken(address _receiver) external;
    function hasRole(bytes32 role, address account) external returns (bool);
    function owner() external view returns(address);
    function tokenSupply() external view returns (uint);
    function tokenMinted() external view returns (uint256);
}

contract NFTSale is ReentrancyGuard {
    uint public totalSales;
    
    struct Sale {
        bool active;
        bool whitelistingActive;
        uint nativeTokenPrice;
        uint totalPurchaseTokens;
        // uint totalWhitelistedAddress;
        mapping(address => bool) whitelist;
        // mapping(address => bool) whitelistAddressTouched;
        mapping(address => uint) purchasePrice;
        mapping(uint => address) purchaseToken;
    }

    //NFT collection address => Sale details
    mapping(address => Sale) saleDetails;
    //User address => Token address => balance
    mapping(address => mapping(address => uint)) public userTokenBalance;
    //User address => Native token balance
    mapping(address => uint) public userNativeTokenBalance;

    // Considering NFT collection is ownable, but what if not?
    modifier onlyCollectionOwner(address _nftCollection) {
        require(IERC721Collection(_nftCollection).owner() == msg.sender, "!OWNER");
        _;
    }

    // Only collection owner can add listing
    function addSale(address _nftCollection, address[] calldata _erc20Tokens, uint[] calldata _erc20Prices, uint _nativeTokenPrice) public onlyCollectionOwner(_nftCollection) {
        require(saleDetails[_nftCollection].active == false, "Collection previously listed");
        for(uint8 i; i<_erc20Tokens.length; i++){
            require(saleDetails[_nftCollection].purchaseToken[i] == address(0), "Invalid TOKEN");
            require(_erc20Prices[i] != 0, "Invalid PRICE");
            saleDetails[_nftCollection].purchaseToken[i] = _erc20Tokens[i];
            saleDetails[_nftCollection].purchasePrice[_erc20Tokens[i]] = _erc20Prices[i];
        }
        saleDetails[_nftCollection].nativeTokenPrice = _nativeTokenPrice;
        saleDetails[_nftCollection].totalPurchaseTokens = _erc20Tokens.length;
        saleDetails[_nftCollection].active = true;
        totalSales = totalSales + 1;
    }

    // Pause feature for individual sales
    function setSaleActive(address _nftCollection, bool _active) public onlyCollectionOwner(_nftCollection) {
        saleDetails[_nftCollection].active = _active;
    }

    // Set whitelist addresses
    function setWhitelist(address _nftCollection, address[] calldata _whitelist, bool _marked) public onlyCollectionOwner(_nftCollection) {
        for(uint i; i<_whitelist.length; i++){
            // Below code prepares for retrieving entire whitelist
            // if(saleDetails[_nftCollection].whitelistAddressTouched[_whitelist[i]] == false && _marked == true){
            //     //mark touched
            //     //total + 1
            // } else if(saleDetails[_nftCollection].whitelistAddressTouched[_whitelist[i]] == false && _marked == false){
            //     // do nothing
            // } else if(saleDetails[_nftCollection].whitelistAddressTouched[_whitelist[i]] == true && saleDetails[_nftCollection].whitelist[_whitelist[i]] == true && _marked == true){
            //     //do nothing
            // } else if(saleDetails[_nftCollection].whitelistAddressTouched[_whitelist[i]] == true && saleDetails[_nftCollection].whitelist[_whitelist[i]] == true && _marked == false){
            //     //total - 1 //alternate solution mark as untouched
            // } else if(saleDetails[_nftCollection].whitelistAddressTouched[_whitelist[i]] == true && saleDetails[_nftCollection].whitelist[_whitelist[i]] == false && _marked == true){
            //     // total + 1 //condition will not exist if above alternate solution is implemented
            // } else if(saleDetails[_nftCollection].whitelistAddressTouched[_whitelist[i]] == true && saleDetails[_nftCollection].whitelist[_whitelist[i]] == false && _marked == false){
            //     //do nothing //can mark it as untouched
            // }

            // if(saleDetails[_nftCollection].whitelist[_whitelist[i]] == true && _marked == false){
            //     saleDetails[_nftCollection].totalWhitelistedAddress -= 1;
            // } else if(saleDetails[_nftCollection].whitelist[_whitelist[i]] == false && _marked == true){
            //     saleDetails[_nftCollection].totalWhitelistedAddress += 1;
            // }

            saleDetails[_nftCollection].whitelist[_whitelist[i]] = _marked;
        }
    }

    // Enable/disable whitelisting
    function setWhitelistingActive(address _nftCollection, bool _active) public onlyCollectionOwner(_nftCollection) {
        saleDetails[_nftCollection].whitelistingActive = _active;
    }

    // Get sale details
    function getSaleDetails(address _nftCollection) public view returns (address[] memory _purchaseToken, uint[] memory _purchasePrice, uint _nativeTokenPrice, bool _active) {
        _purchaseToken = new address[](saleDetails[_nftCollection].totalPurchaseTokens);
        _purchasePrice = new uint[](saleDetails[_nftCollection].totalPurchaseTokens);
        for(uint8 i; i<saleDetails[_nftCollection].totalPurchaseTokens; i++){
            _purchaseToken[i] = saleDetails[_nftCollection].purchaseToken[i];
            _purchasePrice[i] = saleDetails[_nftCollection].purchasePrice[saleDetails[_nftCollection].purchaseToken[i]];
        }
        _nativeTokenPrice = saleDetails[_nftCollection].nativeTokenPrice;
        _active = saleDetails[_nftCollection].active;
    }

    // Check if whitelisted in sale
    function checkUserWhitelisted(address _nftCollection, address _userAddress) public view returns (bool _whitelisted) {
        _whitelisted = saleDetails[_nftCollection].whitelist[_userAddress];
    }

    //NFT collection owner need to give minter role to sale contract to let users purchase NFTs
    function purchaseNFT(address _nftCollection, address _purchaseToken) public payable nonReentrant {
        require(saleDetails[_nftCollection].active, "!SALE");
        require(saleDetails[_nftCollection].whitelistingActive == false || saleDetails[_nftCollection].whitelist[msg.sender], "!WHITELISTED");
        if(msg.value > 0){
            require(saleDetails[_nftCollection].nativeTokenPrice == msg.value, "Insufficient AMOUNT");
            userNativeTokenBalance[msg.sender] += msg.value;
        } else {
            uint price = saleDetails[_nftCollection].purchasePrice[_purchaseToken];
            // Keeping earnings in sale contract
            userTokenBalance[msg.sender][_purchaseToken] += price;
            IERC20(_purchaseToken).transferFrom(msg.sender, address(this), price);
        }
        // NFT collection need to expose mintToken function. Change in case of other interface. What if function is a fake
        IERC721Collection(_nftCollection).mintToken(msg.sender);
    }

    function withdrawTokenPayments(address _erc20Token) public nonReentrant {
        require(userTokenBalance[msg.sender][_erc20Token] > 0, "!BALANCE");
        uint balance = userTokenBalance[msg.sender][_erc20Token];
        userTokenBalance[msg.sender][_erc20Token] = 0;
        IERC20(_erc20Token).transfer(msg.sender, balance);
    }

    function withdrawNativeTokenPayments() public nonReentrant {
        require(userNativeTokenBalance[msg.sender] > 0, "!BALANCE");
        uint balance = userNativeTokenBalance[msg.sender];
        userNativeTokenBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }
}