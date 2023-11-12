// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/ILoopso.sol";
import "./interfaces/ITokenFactory.sol";
import "./interfaces/ILSP7Bridged.sol";
import "./interfaces/ILSP8Bridged.sol";

// TODO implement fee mechanism
contract Loopso is AccessControl, ILoopso, IERC721Receiver {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    bytes32[] public attestationIds;
    mapping(bytes32 => TokenAttestation) public attestedTokens; // from token ID to TokenAttestation on dest chain
    mapping(bytes32  => TokenTransfer) public tokenTransfers; // from transfer ID to transfer on source chain
    mapping(bytes32 => TokenTransferNonFungible) public tokenTransfersNonFungible;

    ITokenFactory public tokenFactory;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(RELAYER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier onlyRelayer() {
        _checkRole(RELAYER_ROLE);
        _;
    }

    /* ============================================== */
    /*  =============  ADD NEW TOKEN  ==============  */
    /* ============================================== */
    /** @dev See ILoopso.sol - attestToken */
    function attestToken(TokenAttestation memory attestation) external onlyAdmin {
        address _newTokenAddress;

        if (attestation.tokenType == TokenType.Fungible) {
            _newTokenAddress = tokenFactory.createNewLSP7(attestation.name, attestation.symbol);
        } else {
            _newTokenAddress = tokenFactory.createNewLSP8(attestation.name, attestation.symbol);
        }

        attestation.wrappedTokenAddress = _newTokenAddress;
        bytes32 attestationID = keccak256(abi.encodePacked(attestation.tokenAddress, attestation.tokenChain));
        attestedTokens[attestationID] = attestation;
        attestationIds.push(attestationID);
        emit TokenAttested(attestationID);
    }

    /* ============================================== */
    /*  ==============  BRIDGE ERC20  ==============  */
    /* ============================================== */
    /** @dev See ILoopso.sol - bridgeTokens */
    function bridgeTokens(
        address _token,
        uint256 _amount,
        uint256 _dstChain,
        address _dstAddress
    ) external {
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed. Make sure bridge is approved to spend tokens.");
      
        TokenTransfer memory _transfer = TokenTransfer(
            TokenTransferBase(
                block.timestamp,
                block.chainid,
                msg.sender,
                _dstChain,
                _dstAddress,
                _token
            ),
            _amount
        );
        bytes32 _transferID = keccak256(abi.encodePacked(block.timestamp, block.chainid, msg.sender,_dstChain,_dstAddress,_token,_amount));
        
        tokenTransfers[_transferID] = _transfer;
   
        emit TokensBridged(_transferID, TokenType.Fungible);
    }

    /** @dev See ILoopso.sol - bridgeTokensBack */
    function bridgeTokensBack(uint256 _amount, address _to, bytes32 _attestationID) external {
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
      
        ILSP7Bridged(attestedToken.wrappedTokenAddress).burn(msg.sender, _amount, new bytes(0));
      
        emit TokensBridgedBack(_amount, _to, _attestationID);
    }

    /** @dev See ILoopso.sol - releaseTokens */
    function releaseTokens(uint256 _amount, address _to, address _token) external onlyRelayer {
        bool success = IERC20(_token).transfer(_to, _amount);
        require(success, "Failed to payout tokens");
    }

    /** @dev See ILoopso.sol - releaseWrappedTokens */
    function releaseWrappedTokens(uint256 _amount, address _to, bytes32 _attestationID) external onlyRelayer {
        // 1. get the attested token
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
        // 2. mint amount of tokens to the _to address
        ILSP7Bridged(attestedToken.wrappedTokenAddress).mint(_to, _amount, true, new bytes(0));
        // 3. emit event
        emit WrappedTokensReleased(_amount, _to, _attestationID);
    }

    /* ============================================== */
    /*  =============  BRIDGE ERC721  ==============  */
    /* ============================================== */
    /** @dev See ILoopso.sol - bridgeNonFungibleTokens */
    function bridgeNonFungibleTokens(address _token, uint256 _tokenID, string memory tokenURI, uint256 _dstChain, address _dstAddress) external {
        // transfer IERC721 from user to bridge
        IERC721(_token).safeTransferFrom(msg.sender, address(this), _tokenID);
        // create token transfer struct
        TokenTransferNonFungible memory _transfer  = TokenTransferNonFungible(
            TokenTransferBase(
                block.timestamp,
                block.chainid,
                msg.sender,
                _dstChain,
                _dstAddress,
                _token
            ),
            _tokenID,
            tokenURI
        );
        bytes32 _transferID = keccak256(abi.encodePacked(block.timestamp, block.chainid, msg.sender, _dstChain, _dstAddress, _token, _tokenID));
        // save token transfer struct
        tokenTransfersNonFungible[_transferID] = _transfer;
        // emit event
        emit TokensBridged(_transferID, TokenType.NonFungible);
    }

    /** @dev See ILoopso.sol - bridgeNonFungibleTokensBack */
    function bridgeNonFungibleTokensBack(uint256 _tokenId, address _to, bytes32 _attestationID) external {
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
        ILSP8Bridged(attestedToken.wrappedTokenAddress).burn(_tokenId, new bytes(0));
        emit NonFungibleTokensBridgedBack(_tokenId, _to, _attestationID);
    }

    /** @dev See ILoopso.sol - releaseWrappedNonFungibleTokens */
    function releaseWrappedNonFungibleTokens(uint256 _tokenId, string calldata _tokenURI, address _to, bytes32 _attestationID) external {
        // 1. get the attested token
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
        // 2. mint the correct wrapped NFT
        ILSP8Bridged(attestedToken.wrappedTokenAddress).mintWithTokenURI(_to, _tokenId, _tokenURI);
        // 3. emit event
        emit WrappedNonFungibleTokensReleased(_tokenId, _to, _attestationID);
    }

    /** @dev See ILoopso.sol - releaseNonFungibleTokens */
    function releaseNonFungibleTokens(uint256 _tokenId, address _to, address _token) external {
        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);
    }

    /* ============================================== */
    /*  =========== CONVENIENCE GETTERS ============  */
    /* ============================================== */
    /** @dev See ILoopso.sol - isTokenSupported */
    function isTokenSupported(address _tokenAddress, uint256 _tokenChain) external view returns (bool) {
        if (_tokenAddress == address(0)) {
            return false;
        }
        bytes32 attestationID = keccak256(abi.encodePacked(_tokenAddress, _tokenChain));
        TokenAttestation memory attestedToken = attestedTokens[attestationID];
        return _tokenAddress == attestedToken.tokenAddress && _tokenChain == attestedToken.tokenChain;
    }

    /** @dev See ILoopso.sol - getSupportedTokensLength */
    function getSupportedTokensLength() external view returns (uint256) {
        return attestationIds.length;
    }

    /** @dev See ILoopso.sol - getAllSupportedTokens */
    function getAllSupportedTokens() external view returns (TokenAttestation[] memory) {
        TokenAttestation[] memory attestations = new TokenAttestation[](attestationIds.length);
        for (uint256 i = 0; i < attestationIds.length; i++) {
            attestations[i] = attestedTokens[attestationIds[i]];
        }
        return attestations;
    }

    /* ============================================== */
    /*  =================  ADMIN  ==================  */
    /* ============================================== */
    function setTokenFactory(ITokenFactory _tokenFactory) external onlyAdmin {
        require(address(_tokenFactory) != address(0), "Can't set LSP Factory to the zero address");
        tokenFactory = _tokenFactory;
    }
    
    /* ============================================== */
    /*  ============= ERC721 RECEIVER ==============  */
    /* ============================================== */
    function onERC721Received(address /* operator */, address /* from */, uint256 /* tokenId */, bytes calldata /* data */) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
