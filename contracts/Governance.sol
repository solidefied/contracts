/*
███████╗ ██████╗ ██╗     ██╗██████╗ ███████╗███████╗██╗███████╗██████╗ 
██╔════╝██╔═══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██║██╔════╝██╔══██╗
███████╗██║   ██║██║     ██║██║  ██║█████╗  █████╗  ██║█████╗  ██║  ██║
╚════██║██║   ██║██║     ██║██║  ██║██╔══╝  ██╔══╝  ██║██╔══╝  ██║  ██║
███████║╚██████╔╝███████╗██║██████╔╝███████╗██║     ██║███████╗██████╔╝
╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ 
*/
// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// user can have one token at a time
contract Governor is
    ERC721,
    ERC721Burnable,
    ERC721URIStorage,
    ERC721Enumerable,
    ERC2981,
    AccessControl,
    ReentrancyGuard
{
    bytes32 public constant PRODUCT_OWNER = keccak256("PRODUCT_OWNER");
    uint256 private _nextTokenId;
    uint256 public TOKEN_SUPPLY;
    address payable tresury =
        payable(0xEcE27420796b3C7fd55Bd7eA2d2bEc403e4c344c); //multisig address
    string public uri;
    mapping(uint => address[]) CompletedProducts; //token id to product owner

    // Sale parameters

    IERC20 public paymentToken;
    uint256 public rate;
    uint256 public softcap;
    uint256 public hardcap;
    bool public isSaleActive = false;
    bytes32 public merkleRoot;
    uint256 public mintCapPerWallet = 1;
    bool public isPrivate = false; //Closed Sale: true, OpenSale : False // Default is OpenSale
    address solidefiedAdmin;
    address[] public participatedUsers;
    uint public nftBought = 0;

    event SaleStarted();
    event SaleEnded();
    event TokensPurchased(address buyer, uint256 amount);

    constructor(
        address _paymentToken,
        uint _rate,
        uint _softcap,
        uint _hardcap,
        address _solidefiedAdmin,
        string memory _uri
    ) ERC721("Solidefied Governor", "POWER") {
        paymentToken = IERC20(_paymentToken);
        rate = _rate * 10 ** 18;
        softcap = _softcap;
        hardcap = _hardcap;
        solidefiedAdmin = _solidefiedAdmin;
        _setDefaultRoyalty(tresury, 200); // can change later
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRODUCT_OWNER, msg.sender);
        TOKEN_SUPPLY = 5;
        uri = _uri;
    }

    function _addProduct(uint _tokenId, address _productId) private {
        CompletedProducts[_tokenId].push(_productId);
    }

    function _getCompletedProducts(
        uint _tokenId
    ) public view returns (address[] memory products) {
        return CompletedProducts[_tokenId];
    }

    function _mint(address to) private {
        uint256 tokenId = _nextTokenId++;
        require(tokenId < TOKEN_SUPPLY, "Limit Reached");
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function assignNFT(address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(_to);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function setDefaultRoyalty(
        address _receiver,
        uint96 _royaltyRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _royaltyRate);
    }

    function setURI(string memory _uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uri = _uri;
    }

    function setTresury(
        address _tresury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tresury = payable(_tresury);
    }

    function setProductOwnerRole(
        address _user
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PRODUCT_OWNER, _user);
    }

    function getTokenOwnedBy(
        address owner
    ) public view returns (uint256 tokenId) {
        require(
            balanceOf(owner) == 1,
            "Owner does not have exactly one token."
        );
        return tokenOfOwnerByIndex(owner, 0);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        require(balanceOf(to) == 0, "Can't have more that one token");

        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721,
            AccessControl,
            ERC721URIStorage,
            ERC721Enumerable,
            ERC2981
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Sale functions

    function buyInOpenSale() external nonReentrant {
        require(isSaleActive, "Sale is not live");
        require(!isPrivate, "Restricted Sale");
        _buy();
    }

    function buyInClosedSale(bytes32[] memory proof) external nonReentrant {
        require(isSaleActive, "Sale is not live");
        require(
            isValid(proof, keccak256(abi.encodePacked(msg.sender))),
            "Unauthorized"
        );
        _buy();
    }

    function _buy() private {
        participatedUsers.push(msg.sender);
        IERC20(paymentToken).transferFrom(msg.sender, address(this), rate);
        _mint(msg.sender);
        nftBought++;
    }

    function startSale() external onlyRole(PRODUCT_OWNER) {
        require(!isSaleActive, "Sale already active");
        isSaleActive = true;
        emit SaleStarted();
    }

    function endSale() external onlyRole(PRODUCT_OWNER) {
        require(isSaleActive, "Sale not active");
        isSaleActive = false;
        emit SaleEnded();
    }

    function getNftBought() external view returns (uint nft) {
        return nftBought;
    }

    function isValid(
        bytes32[] memory proof,
        bytes32 leaf
    ) public view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function changeSoftcap(uint256 _softcap) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!isSaleActive, "Sale is Live");
        // require(_softcap < totalSupply, "Softcap should be less than total Supply");
        softcap = _softcap;
    }

    /*
     * @notice Change Rate
     * @param _rate: token rate per usdt
     */
    function changeRate(uint256 _rate) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!isSaleActive, "Sale is Live");
        rate = _rate;
    }

    /*
     * @notice Change Allowed user balance
     * @param _allowedUserBalance: amount allowed per user to purchase tokens in usdt
     */
    function changeMintCapPerWallet(
        uint256 _mintCapPerWallet
    ) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!isSaleActive, "Sale is Live");
        mintCapPerWallet = _mintCapPerWallet;
    }

    /*
     * @notice get total number of participated user
     * @return no of participated user
     */
    function getTotalParticipatedUser() public view returns (uint256) {
        return participatedUsers.length;
    }

    function getUsersList(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (address[] memory userAddress) {
        uint256 length = endIndex - startIndex;
        address[] memory _userAddress = new address[](length);

        for (uint256 i = startIndex; i < endIndex; i++) {
            address user = participatedUsers[i];
            uint256 listIndex = i - startIndex;
            _userAddress[listIndex] = user;
        }

        return (_userAddress);
    }

    function withdrawEther(
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(address(this).balance >= amount, "Insufficient balance");
        tresury.transfer(amount);
    }

    /*
     * @notice funds withdraw
     * @param _tokenAddress: token address to transfer
     * @param _value: token value to transfer from contract to owner
     */
    function fundsWithdrawal(
        address tokenAddress,
        uint256 _value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        IERC20(tokenAddress).transfer(tresury, _value);
    }

    receive() external payable {}
}
