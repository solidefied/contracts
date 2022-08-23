// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 


contract Governor is ERC721, ERC2981, AccessControl{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIdCounter;

    uint public TOKEN_SUPPLY;
    string public baseURI;
    address TREASURY;


    constructor(address treasury,string memory _baseUri, uint96 _royaltyRate) ERC721("Solidefied Governor", "POWER") {
        TREASURY = treasury;
        _setDefaultRoyalty(TREASURY, _royaltyRate);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        TOKEN_SUPPLY = 250;
        baseURI = _baseUri;
    }


    // to set or update default royalty fee for every token
    function setDefaultRoyalty(address _receiver, uint96 _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _royaltyRate);
    }

    // to set or update total token supply
    function setTokenSupply(uint256 _tokenSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TOKEN_SUPPLY = _tokenSupply;
    }


     // to set or update the baseUri.
    function setBaseURI(string memory _uri) external onlyRole(DEFAULT_ADMIN_ROLE){
        baseURI = _uri;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }


    function setMinterRole(address _minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, _minter);
    }

    // User with Minter Role can mint token by calling this function
    function mintToken(address to) external onlyRole(MINTER_ROLE) {
         uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < TOKEN_SUPPLY, "Limit Reached");
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    } 

    //to withdraw native currency(if any)
    function withdrawFund(address destination) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        (bool success, ) = destination.call{value: getBalance()}("");
        return success;
    }
// Add function to revo any ERC20 tokens sent by accident

// function transferAnyERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
//         IERC20(_tokenAddr).transfer(_to, _amount);
//     }



    function getBalance() public view returns(uint) {
       return address(this).balance;
    }

    // Every marketplace looks for this function to read the uri of a token
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId),"Invalid TokenId");

         return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, _tokenId.toString()))
            : "";
    }


    //total token minted
    function tokenMinted() public view returns(uint){
        return _tokenIdCounter.current();
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


}