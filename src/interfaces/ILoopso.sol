// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILoopso {
    enum TokenType {
        Fungible,
        NonFungible
    }

    /* ============================================== */
    /*  =================  STRUCTS  ================  */
    /* ============================================== */

    /**
    @dev Stores info about a chain A token on chain B.
    @param tokenAddress Address of token on chain A
    @param tokenChain chain ID of chain A
    @param tokenType Whether the token is fungible/non-fungible
    @param decimals Only applicable to fungible tokens. Number of decimals.
    @param symbol Token symbol
    @param name Token name
    @param wrappedTokenAddress The address of the token after it has been deployed on chain B
     */
    struct TokenAttestation {
        address tokenAddress;
        uint256 tokenChain;
        TokenType tokenType;
        uint8 decimals;
        string symbol;
        string name;
        address wrappedTokenAddress;
    }

    /**
    @dev Stores info about a token transfer from chain A to chain B
    @param timestamp When the transfer happened
    @param srcChain The chain ID where the transfer was initiated
    @param srcAddress The address of the account that initiated the transfer
    @param dstChain Chain ID where the transfer is being sent to
    @param dstAddress Address on chain B that will receive the transfer
    @param tokenAddress Address of token on chain A that is being transferred  
     */
    struct TokenTransferBase {
        uint256 timestamp;
        uint256 srcChain;
        address srcAddress;
        uint256 dstChain;
        address dstAddress;
        address tokenAddress;
    }

    /**
    @dev Used for fungible token transfers
    @param tokenTransfer Base token transfer info struct
    @param amount The amount of tokens being transferred
     */
    struct TokenTransfer {
        TokenTransferBase tokenTransfer;
        uint256 amount;
    }

    /**
    @dev Used for non-fungible token transfers
    @param tokenTransfer Base token transfer info struct
    @param tokenID ID of the NFT being transferred
    @param tokenURI Token URI of the NFT being transferred
     */
    struct TokenTransferNonFungible {
        TokenTransferBase tokenTransfer;
        uint256 tokenID;
        string tokenURI;
    }

    /* ============================================== */
    /*  =================  EVENTS  =================  */
    /* ============================================== */

    /** @dev Emitted by attestToken. Means a new token is supported by the bridge. */
    event TokenAttested(bytes32 indexed attestationID);

    /** @dev Emitted by bridgeTokens. transferID is used by the relayer to locate the transfer details. */
    event TokensBridged(
        bytes32 indexed transferID,
        TokenType indexed tokenType
    );

    /** @dev Emitted by bridgeTokensBack. Relayer should use indexed params to release the tokens on the other chain. */
    event TokensBridgedBack(
        uint256 indexed amount,
        address indexed to,
        bytes32 indexed attestationID
    );

    /** @dev Emitted by bridgeNonFungibleTokens. Relayer should use indexed params to release the tokens on the other chain. */
    event NonFungibleTokensBridgedBack(
        uint256 indexed tokenId,
        address indexed to,
        bytes32 indexed attestationID
    );

    /** @dev Emitted by releaseTokens. This means briding back wrapped tokens to the source chain was successful. */
    event TokensReleased(
        uint256 indexed amount,
        address indexed to,
        address indexed token
    );

    /** @dev Emitted by releaseWrappedTokens. This means briding tokens was successful. */
    event WrappedTokensReleased(
        uint256 indexed amount,
        address indexed to,
        bytes32 indexed attestationID
    );

    /** @dev Emitted by releaseWrappedNonFungibleTokens. This means bridging tokens was successful. */
    event WrappedNonFungibleTokensReleased(
        uint256 indexed tokenId,
        address indexed to,
        bytes32 indexed attestationID
    );

    /* ============================================== */
    /*  =============  ADD NEW TOKEN  ==============  */
    /* ============================================== */
    /**
    @dev Called by bridge admin on the destination chain to attest a token.
    Only attested tokens can be bridged.
    @param attestation Contains details that are used to identify a token from chain A on chain B.
     */
    function attestToken(TokenAttestation memory attestation) external;

    /* ============================================== */
    /*  ==============  BRIDGE ERC20  ==============  */
    /* ============================================== */

    /**
    @dev Called by users to bridge ERC20 tokens from source chain to destination chain.
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
    @dev Burns _amount of locked ERC20 tokens on the destination chain, emits an event that relayer picks up.
    @param _amount Amount of tokens to bridge back.
    @param _to Address the original tokens will be released to.
    @param _attestationID ID of the TokenAttestation struct we use to identify a chain A token on chain B.
     */
    function bridgeTokensBack(
        uint256 _amount,
        address _to,
        bytes32 _attestationID
    ) external;

    /**
    @dev Called by the relayer after it picks up a TokensBridgedBack event.
    It releases the bridged back tokens to the user.
    @param _amount The amount of tokens to release.
    @param _to The address to release the tokens to.
    @param _token The address of the token to release.
     */
    function releaseTokens(
        uint256 _amount,
        address _to,
        address _token
    ) external;

    /**
    @dev Called by the relayer after it picks up a bridge event from the source chain.
    It mints wrapped tokens equivalent to the tokens locked up on the source chain.
    @param _amount Amount of wrapped tokens to mint.
    @param _to The address the wrapped tokens will be minted to.
    @param _attestationID The ID we use to identify a chain A token on chain B.
     */
    function releaseWrappedTokens(
        uint256 _amount,
        address _to,
        bytes32 _attestationID
    ) external;

    /* ============================================== */
    /*  =============  BRIDGE ERC721  ==============  */
    /* ============================================== */

    /**
    @dev Called by users to bridge ERC721 tokens from source chain to destination chain.
    @param _token The address of the ERC721 to bridge
    @param _tokenID The ID of the token to bridge
    @param tokenURI Token URI of the ERC721
    @param _dstChain Destination chain ID
    @param _dstAddress Address that will receive the ERC721 on the destination chain     
     */
    function bridgeNonFungibleTokens(address _token, uint256 _tokenID, string memory tokenURI, uint256 _dstChain, address _dstAddress) external;

    /**
    @dev Burns the wrapped ERC721 with token ID on the destination chain, and emits an event that the relayer picks up.
    @param _tokenId The token ID of the ERC721
    @param _to The address that will receive the original ERC721 on the source chain
    @param _attestationID ID of the TokenAttestation struct we use to identify a chain A token on chain B.
     */
    function bridgeNonFungibleTokensBack(uint256 _tokenId, address _to, bytes32 _attestationID) external;

    /**
    @dev Called by the relayer after it picks up a bridge event from the source chain.
    It mints a wrapped ERC721 with the given token ID, setting the token URI as well.
    @param _tokenId The token ID of the NFT
    @param _tokenURI The token URI
    @param _to The address that will receive the NFT on the destination chain
    @param _attestationID ID of the TokenAttestation struct we use to identify a chain A token on chain B.
     */
    function releaseWrappedNonFungibleTokens(uint256 _tokenId, string calldata _tokenURI, address _to, bytes32 _attestationID) external;

    /**
    @dev Called by the relayer after it picks up a NonFungibleTokensBridgedBack event.
    It releases the bridged back token to the user.
    @param _tokenId The token ID of the NFT
    @param _to The address that will receive the NFT on the destination chain
    @param _token The address of the NFT on the source chain
     */
    function releaseNonFungibleTokens(uint256 _tokenId, address _to, address _token) external;    

    /* ============================================== */
    /*  =========== CONVENIENCE GETTERS ============  */
    /* ============================================== */
    /**
    @dev Check whether a token from a given chain is supported by the bridge.
    @param _tokenAddress The address of the token.
    @param _tokenChain The chain ID on which the token is deployed.
     */
    function isTokenSupported(address _tokenAddress, uint256 _tokenChain) external view returns (bool);

    /** @dev Returns the total number of tokens supported by the bridge. */
    function getSupportedTokensLength() external view returns (uint256);

    /** @dev Returns the attestation details for the token if it is a wrapped token, of not it returns an empty TokenAttestation struct. */
    function wrappedTokenInfo(address _wrappedToken) external returns (TokenAttestation memory);

    /** 
    @dev Get all supported tokens.
    @return TokenAttestation[] array
     */
    function getAllSupportedTokens() external view returns (TokenAttestation[] memory);
}
