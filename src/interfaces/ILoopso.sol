// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILoopso {
    enum TokenType {
        Fungible,
        NonFungible
    }

    struct TokenAttestation {
        address tokenAddress;
        uint256 tokenChain;
        TokenType tokenType;
        uint8 decimals;
        string symbol;
        string name;
        address wrappedTokenAddress;
    }

    struct TokenTransferBase {
        uint256 timestamp;
        uint256 srcChain;
        address srcAddress;
        uint256 dstChain;
        address dstAddress;
        address tokenAddress;
    }

    struct TokenTransfer {
        TokenTransferBase tokenTransfer;
        uint256 amount;
    }

    struct TokenTransferNonFungible {
        TokenTransferBase tokenTransfer;
        uint256 tokenID;
    }

    /** @dev Emitted by attestToken. Means a new token is supported by the bridge. */
    event TokenAttested(bytes32 indexed tokenID);

    /** @dev Emitted by bridgeTokens. transferID is used by the relayer as it helps locate the transfer details. */
    event TokensBridged(bytes32 indexed transferID);

    /** @dev Emitted by bridgeTokensBack. Relayer should use indexed params to release the tokens on the other chain. */
    event TokensBridgedBack(uint256 indexed amount, address indexed to, bytes32 indexed tokenID);

    /** @dev Emitted by releaseTokens. This means briding back wrapped tokens to the source chain was successful. */
    event TokensReleased(uint256 indexed amount, address indexed to, address indexed token);

    /** @dev Emitted by releaseWrappedTokens. This briding tokens was succesful. */
    event WrappedTokensReleased(uint256 indexed amount, address indexed to, bytes32 indexed tokenID);

    /**
    @dev Called by bridge admin on the destination chain to attest a token.
    Only attested tokens can be bridged.
    @param attestation Contains details that are used to identify a token from chain A on chain B.
     */
    function attestToken(TokenAttestation memory attestation) external;

    /**
    @dev Called by users to bridge tokens from source chain to destination chain.
    @param _token The address of the token to bridge.
    @param _amount The amount of tokens to bridge.
    @param _dstChain Chain ID where we are bridging to.
    @param _dstAddress Address the wrapped tokens will be released to on the destination chain. 
     */
    function bridgeTokens(
        address _token,
        uint256 _amount,
        uint256 _dstChain,
        address _dstAddress
    ) external;

    /**
    @dev Burns _amount of locked tokens on the destination chain, emits an event that relayer picks up.
    @param _amount Amount of tokens to bridge back.
    @param _to Address the original tokens will be released to.
    @param _tokenID ID of the TokenAttestation struct we use to identify a chain A token on chain B.
     */
    function bridgeTokensBack(uint256 _amount, address _to, bytes32 _tokenID) external;

    /**
    @dev Called by the relayer after it picks up a TokensBridgedBackEvent.
    It releases the bridged back tokens to the user.
    @param _amount The amount of tokens to release.
    @param _to The address to release the tokens to.
    @param _token The address of the token to release.
     */
    function releaseTokens(uint256 _amount, address _to, address _token) external;

    /**
    @dev Called by the relayer after it picks up a bridge event from the source chain.
    It mints wrapped tokens equivalent to the tokens locked up on the source chain.
    @param _amount Amount of wrapped tokens to mint.
    @param _to The address the wrapped tokens will be minted to.
    @param _tokenID The ID we use to identify a chain A token on chain B.
     */
    function releaseWrappedTokens(uint256 _amount, address _to, bytes32 _tokenID) external;
}
