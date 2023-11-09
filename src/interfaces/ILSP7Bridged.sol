// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILSP7Bridged {
    function mint(address to, uint256 amount, bool force, bytes memory data) external;
    function burn(address from, uint256 amount, bytes memory data) external;
}
