// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Constants {
    uint256 constant MIN_FEE = 0; // min fungible fee
    uint256 constant MAX_FEE = 100; // max fungible fee
    uint256 public FEE_FUNGIBLE = 0; // current fee set for fungible

    uint256 constant MIN_FEE_NON_FUNGIBLE = 0; // min fungible fee
    uint256 constant MAX_FEE_NON_FUNGIBLE = 0.002 ether; // max fungible fee
    uint256 public FEE_NON_FUNGIBLE = 10; // current fee set for non-fungible

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
}
