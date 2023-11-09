// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITokenFactory {
    event NewLSP7(address indexed tokenAddress);
    event NewLSP8(address indexed tokenAddress);

    event MasterLSP7Set(address indexed masterLSP7);
    event MasterLSP8Set(address indexed masterLSP8);

    function createNewLSP7(string memory _name, string memory _symbol) external returns (address);

    function createNewLSP8(string memory _name, string memory _symbol) external returns (address);
}