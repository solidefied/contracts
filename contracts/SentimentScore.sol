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
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SentimentScore is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public _nextTokenId;

    constructor() ERC721("SentimentScore", "SCORE") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function safeMint(
        address to,
        string memory uri
    ) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721) returns (address) {
        address from = super._ownerOf(tokenId);

        // This condition ensures that the function proceeds in two scenarios:
        // 1. Minting a new token: `from` is the zero address, and `to` is a non-zero address.
        // 2. Burning a token: `to` is the zero address. This doesn't explicitly require `from` to be non-zero since _ownerOf will ensure the token exists.
        // It implicitly prevents transferring since it will fail for attempts to transfer from a non-zero `from` to a non-zero `to`.
        require(
            (from == address(0) && to != address(0)) || (to == address(0)),
            "SentimentScore: Tokens are non-transferable"
        );

        return super._update(to, tokenId, auth);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
