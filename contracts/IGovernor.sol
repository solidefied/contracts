// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IGovernor is IERC721 {
    function mint(address to) external;
    function setDefaultRoyalty(address _receiver, uint96 _royaltyRate) external;
    function setTokenSupply(uint256 _tokenSupply) external;
    function setBaseURI(string memory _uri) external;
    function setTreasury(address treasury) external;
    function setMinterRole(address _minter) external;
    function withdrawDonatedETH() external returns (bool);
    function withdrawDonatedTokens(address _erc20Token) external;
    function tokenMinted() external view returns (uint256);
    function _addProduct(uint _tokenId, address _productId) external;
    function _getCompletedProducts(
        uint _tokenId
    ) external view returns (address[] memory products);
}
