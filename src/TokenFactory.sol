// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITokenFactory.sol";
import "./LSP7Bridged.sol";
import "./LSP8Bridged.sol";

contract TokenFactory is Ownable, ITokenFactory {
    address public bridge;
    address public masterLSP7;
    address public masterLSP8;
    address[] public lsp7s;
    address[] public lsp8s;

    constructor(address _masterLSP7, address _masterLSP8, address _bridge) Ownable(msg.sender) {
        masterLSP7 = _masterLSP7;
        masterLSP8 = _masterLSP8;
        bridge = _bridge;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge can call");
        _;
    }

    function setMasterLSP7(address _masterLSP7) external onlyOwner {
        require(_masterLSP7 != address(0), "Can't set master LSP7 to zero address");
        masterLSP7 = _masterLSP7;
        emit MasterLSP7Set(masterLSP7);
    }

    function setMasterLSP8(address _masterLSP8) external onlyOwner {
        require(_masterLSP8 != address(0), "Can't set master LSP8 to zero address");
        masterLSP8 = _masterLSP8;
        emit MasterLSP8Set(masterLSP8);
    }

    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Can't set bridge to zero address");
        bridge = _bridge;
    }

    function createNewLSP7(string memory _name, string memory _symbol) external onlyBridge returns (address) {
        LSP7Bridged _lsp7 = LSP7Bridged(payable(Clones.clone(masterLSP7)));
        _lsp7.initialize(_name, _symbol, bridge);
        lsp7s.push(address(_lsp7));
        emit NewLSP7(address(_lsp7));
        return address(_lsp7);
    }

    function createNewLSP8(string memory _name, string memory _symbol) external onlyBridge returns (address) {
        LSP8Bridged _lsp8 = LSP8Bridged(payable(Clones.clone(masterLSP8)));
        _lsp8.initialize(_name, _symbol, bridge, 0);
        lsp8s.push(address(_lsp8));
        emit NewLSP8(address(_lsp8));
        return address(_lsp8);
    }
}
