// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILSP8Bridged {
    function burn(uint256 tokenId, bytes memory data) external;
    function mintWithTokenURI(address to, uint256 tokenId, string memory _tokenURI) external;
}