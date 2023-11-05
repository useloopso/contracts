// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ILoopso.sol";

contract Loopso is AccessControl, ILoopso {

    mapping(bytes32 => TokenAttestation) attestedTokens; // from token ID to TokenAttestation on dest chain
    mapping(bytes32  => TokenTransfer) tokenTransfers; // from transfer ID to transfer on source chain

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    function attestToken(TokenAttestation memory attestation) external onlyAdmin {
        // TODO
    }

    function bridgeTokens(
        address _token,
        uint256 _amount,
        uint256 _dstChain,
        address _dstAddress
    ) external {
        // TODO
    }

    function releaseTokens(uint256 _amount, address _to, bytes32 _tokenID) external onlyAdmin {
        // TODO
    }

    function bridgeTokensBack(uint256 _amount, address _to, bytes32 _tokenID) external {
        // TODO
    }
}
