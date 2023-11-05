// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ILoopso.sol";

contract Loopso is AccessControl, ILoopso {
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

    function releaseTokens(bytes32 _transferID) external onlyAdmin {
        // TODO
    }

    function bridgeTokensBack(bytes32 _tokenID, uint256 _amount) external {
        // TODO
    }
}
