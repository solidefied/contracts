// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Interface for the SentimentScore contract.
 */
interface ISentimentScore {
    /**
     * @dev Mint a new token with a specific URI to a given address.
     * @param to Address to mint the token to.
     * @param uri URI of the token metadata.
     */
    function safeMint(address to, string memory uri) external;

    /**
     * @dev Get the token URI for a given token ID.
     * @param tokenId ID of the token.
     * @return The URI of the token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /**
     * @dev Check if a given interface is supported.
     * @param interfaceId ID of the interface.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // Optional: Add any other relevant functions you wish to expose via this interface.
}
