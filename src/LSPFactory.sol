// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LSPFactory is Ownable {
    address public bridge;
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDE_ROLE");
    address public masterLSP7;

    constructor(address _masterLSP7, address _bridge) {
        masterLSP7 = _masterLSP7;
        bridge = _bridge;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge can call");
        _;
    }

    function setMasterLSP7(address _masterLSP7) external onlyOwner {
        require(_masterLSP7 != address(0), "Can't set master LSP7 to zero address");
        masterLSP7 = _masterLSP7;
    }

    function createNewLSP7(string memory _name, string memory _symbol) external onlyBridge returns (address) {
        LSP7DigitalAssetInitAbstract _lsp7 = LSP7DigitalAssetInitAbstract(Clones.clone(masterLSP7));
        _lsp7._initialize(_name, _symbol, owner(), false);
        return address(0);
    }
}
