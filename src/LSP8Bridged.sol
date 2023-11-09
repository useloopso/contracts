// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@lukso/LSP8/presets/LSP8CompatibleERC721MintableInit.sol";
import "@lukso/LSP8/LSP8Errors.sol";

// TODO: Set/get token URI
contract LSP8Bridged is LSP8CompatibleERC721MintableInit {
    function burn(bytes32 tokenId, bytes memory data) public {
        if (!_isOperatorOrOwner(msg.sender, tokenId)) {
            revert LSP8NotTokenOperator(tokenId, msg.sender);
        }
        _burn(tokenId, data);
    }
}