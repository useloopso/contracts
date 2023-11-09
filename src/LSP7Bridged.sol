// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@lukso/LSP7/presets/LSP7CompatibleERC20MintableInit.sol";

// TODO: Set decimals in initializer
contract LSP7Bridged is LSP7CompatibleERC20MintableInit {
    function burn(
        address from,
        uint256 amount,
        bytes memory data
    ) public virtual {
        if (msg.sender != from) {
            _spendAllowance(msg.sender, from, amount);
        }
        _burn(from, amount, data);
    }
}
