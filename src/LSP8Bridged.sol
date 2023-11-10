// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@lukso/LSP8/presets/LSP8CompatibleERC721MintableInit.sol";
import "@lukso/LSP8/LSP8Errors.sol";
import "@lukso/LSP8/LSP8Constants.sol";

contract LSP8Bridged is LSP8CompatibleERC721MintableInit {
    function burn(bytes32 tokenId, bytes memory data) public {
        if (!_isOperatorOrOwner(msg.sender, tokenId)) {
            revert LSP8NotTokenOperator(tokenId, msg.sender);
        }
        _burn(tokenId, data);
    }

    function mintWithTokenURI(address to, uint256 tokenId, string memory _tokenURI) public onlyOwner {
        mint(to, bytes32(tokenId), true, new bytes(0));
        setTokenURI(tokenId, _tokenURI);
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        bytes32 _tokenURIKey = keccak256(abi.encodePacked("TOKEN_URI", tokenId));
        _setData(_tokenURIKey, bytes(_tokenURI));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(bytes32(tokenId)), "Token is not minted");

        bytes32 _tokenURIKey = keccak256(abi.encodePacked("TOKEN_URI", tokenId));
        return string(_getData(_tokenURIKey));
    }
}