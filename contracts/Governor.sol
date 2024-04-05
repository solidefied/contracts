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

// user can have one token at a time
contract Governor is
    ERC721,
    ERC721Burnable,
    ERC721URIStorage,
    ERC721Enumerable,
    ERC2981,
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _nextTokenId;
    uint256 public TOKEN_SUPPLY;
    address payable TREASURY; //multisig address
    string public baseURI;
    // address[] Assessments;

    mapping(uint => address[]) CompletedProducts; //token id to product owner

    constructor(
        address treasury,
        string memory _baseUri,
        uint96 _royaltyRate
    ) ERC721("Solidefied Governor", "POWER") {
        TREASURY = payable(treasury);
        _setDefaultRoyalty(TREASURY, _royaltyRate);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        TOKEN_SUPPLY = 5;
        baseURI = _baseUri;
    }

    function _addProduct(uint _tokenId, address _productId) private {
        CompletedProducts[_tokenId].push(_productId);
    }

    function _getCompletedProducts(
        uint _tokenId
    ) public view returns (address[] memory products) {
        return CompletedProducts[_tokenId];
    }

    function mint(address to) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = _nextTokenId++;
        require(tokenId < TOKEN_SUPPLY, "Limit Reached");
        _safeMint(to, tokenId);
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

    function setTokenSupply(
        uint256 _tokenSupply
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TOKEN_SUPPLY = _tokenSupply;
    }

    function setBaseURI(
        string memory _uri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _uri;
    }

    function setTreasury(
        address treasury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TREASURY = payable(treasury);
    }

    function setMinterRole(
        address _minter
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, _minter);
    }

    function withdrawDonatedETH()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        TREASURY.transfer(address(this).balance);
        return true;
    }

    function withdrawDonatedTokens(
        address _erc20Token
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // In case of Non standard ERC20 tokens change this function
        require(IERC20(_erc20Token).balanceOf(address(this)) > 0, "!BALANCE");
        IERC20(_erc20Token).transfer(
            TREASURY,
            IERC20(_erc20Token).balanceOf(address(this))
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
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

    receive() external payable {}
}
