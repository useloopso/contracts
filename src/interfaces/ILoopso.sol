// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILoopso {
    struct TokenAttestation {
        address tokenAddress;
        uint256 tokenChain;
        uint8 decimals;
        string symbol;
        string name;
    }

    struct TokenTransfer {
        bytes32 transferID;
        uint256 timestamp;
        uint256 nonce;
        uint256 srcChain;
        address srcAddress;
        uint256 dstChain;
        address dstAddress;
        bytes32 tokenID;
        uint256 amount;
        uint256 fee;
    }

    event TokenAttested(bytes32 indexed tokenID);
    event TokenBridged(bytes32 indexed transferID);

    /**
    @dev Called by bridge admin on the destination chain to attest a token
    Only attested tokens can be bridged
     */
    function attestToken(TokenAttestation memory attestation) external;

    /**
    @dev Locks _amount from _token into this contract on the source chain. 
    Emits an event that the offchain node should pick up and then call releaseTokens on the destination chain.
     */
    function bridgeTokens(
        address _token,
        uint256 _amount,
        uint256 _dstChain,
        address _dstAddress
    ) external;

    /**
    @dev Called by the offchain node after it picks up a bridge event from the source chain.
    It mints wrapped tokens equivalent to the tokens locked up on the source chain.
     */
    function releaseTokens(bytes32 _transferID) external;

    /**
    @dev Burns _amount of locked tokens on the destination chain, and makes them available for withdraw on the source chain.
     */
    function bridgeTokensBack(bytes32 _tokenID, uint256 _amount) external;
}
