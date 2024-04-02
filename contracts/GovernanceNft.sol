/*
███████╗ ██████╗ ██╗     ██╗██████╗ ███████╗███████╗██╗███████╗██████╗ 
██╔════╝██╔═══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██║██╔════╝██╔══██╗
███████╗██║   ██║██║     ██║██║  ██║█████╗  █████╗  ██║█████╗  ██║  ██║
╚════██║██║   ██║██║     ██║██║  ██║██╔══╝  ██╔══╝  ██║██╔══╝  ██║  ██║
███████║╚██████╔╝███████╗██║██████╔╝███████╗██║     ██║███████╗██████╔╝
╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ 
*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Governor is ERC721, ERC721Enumerable, ERC2981, AccessControl {
    using Counters for Counters.Counter;
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;
    uint256 public TOKEN_SUPPLY;
    address payable TREASURY;
    string public baseURI;

    constructor(
        address treasury,
        string memory _baseUri,
        uint96 _royaltyRate
    ) ERC721("Solidefied Governor", "POWER") {
        TREASURY = payable(treasury);
        _setDefaultRoyalty(TREASURY, _royaltyRate);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        TOKEN_SUPPLY = 250;
        baseURI = _baseUri;
    }

    function mint(address to) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < TOKEN_SUPPLY, "Limit Reached");
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
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

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "Invalid TokenId");

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _tokenId.toString()))
                : "";
    }

    function tokenMinted() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}
