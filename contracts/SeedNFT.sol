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

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Angel is ERC721,ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;
    uint public TOKEN_SUPPLY;
    address TREASURY;
    string public baseURI;

    constructor(address treasury, string memory _baseUri)
        ERC721("Solidefied Angel", "ANGEL")
    {
        TREASURY = treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        TOKEN_SUPPLY = 1000;
        baseURI = _baseUri;
    }

    function mintToken(address to) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < TOKEN_SUPPLY, "Limit Reached");
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function setTokenSupply(uint256 _tokenSupply)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        TOKEN_SUPPLY = _tokenSupply;
    }

    function setBaseURI(string memory _uri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = _uri;
    }

    function setMinterRole(address _minter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(MINTER_ROLE, _minter);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal  override(ERC721, ERC721Enumerable) {
        require(from == address(0) || to == address(0), "Not Transferable");
        super._beforeTokenTransfer(from, to, tokenId);
    }
    

    //to withdraw native currency(if any)
    function withdrawDonatedETH()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        (bool success, ) = TREASURY.call{value: getBalance()}("");
        return success;
    }

    function withdrawDonatedToken(address _tokenAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) > 0,
            "Low Balance"
        );
        IERC20(_tokenAddress).transfer(
            TREASURY,
            IERC20(_tokenAddress).balanceOf(address(this))
        );
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    // Every marketplace looks for this function to read the uri of a token
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "Invalid TokenId");

        return
            bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI)) : "";
    }

    //total token minted
    function tokenMinted() public view returns (uint) {
        return _tokenIdCounter.current();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721,ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}
