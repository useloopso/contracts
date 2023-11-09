// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERCFactory {
    event NewERC20(address indexed tokenAddress);
    event NewERC721(address indexed tokenAddress);

    event MasterERC20Set(address indexed masterLSP7);
    event MasterERC721Set(address indexed masterLSP8);

    function createNewERC20(string memory _name, string memory _symbol) external returns (address);

    function createNewERC721(string memory _name, string memory _symbol) external returns (address);
}