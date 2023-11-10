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

contract Loopso is AccessControl, ILoopso, IERC721Receiver {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    // TODO: uint256 public BRIDGE_FEE

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
        emit TokenAttested(attestationID);
    }

    function bridgeTokens(
        address _token,
        uint256 _amount,
        uint256 _dstChain,
        address _dstAddress
    ) external {
        // 0. TODO - calculate fee paid to bridge & add fee to _amount
        // 1. transfer _amount tokens to the bridge from msg.sender
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed. Make sure bridge is approved to spend tokens.");
        // 2. create tokenTransfer struct
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
        // 3. save tokenTransfer struct
        tokenTransfers[_transferID] = _transfer;
        // 4. emit event
        emit TokensBridged(_transferID, TokenType.Fungible);
    }

    function bridgeNonFungibleTokens(address _token, uint256 _tokenID, string memory tokenURI, uint256 _dstChain, address _dstAddress) external {
        // 0. TODO: take fixed fee on NFT brdiging
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

    function bridgeTokensBack(uint256 _amount, address _to, bytes32 _attestationID) external {
        // 1. get attested token
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
        // 2. burn amount of tokens
        ILSP7Bridged(attestedToken.wrappedTokenAddress).burn(msg.sender, _amount, new bytes(0));
        // 3. emit proper event
        emit TokensBridgedBack(_amount, _to, _attestationID);
    }

    function bridgeNonFungibleTokensBack(uint256 _tokenId, address _to, bytes32 _attestationID) external {
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
        ILSP8Bridged(attestedToken.wrappedTokenAddress).burn(_tokenId, new bytes(0));
        emit NonFungibleTokensBridgedBack(_tokenId, _to, _attestationID);
    }

    function releaseWrappedTokens(uint256 _amount, address _to, bytes32 _attestationID) external onlyRelayer {
        // 1. get the attested token
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
        // 2. mint amount of tokens to the _to address
        ILSP7Bridged(attestedToken.wrappedTokenAddress).mint(_to, _amount, false, new bytes(0));
        // 3. emit event
        emit WrappedTokensReleased(_amount, _to, _attestationID);
    }

    function releaseWrappedNonFungibleTokens(uint256 _tokenId, string calldata _tokenURI, address _to, bytes32 _attestationID) external {
        // 1. get the attested token
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(attestedToken.tokenAddress != address(0), "Invalid _attestationID");
        // 2. mint the correct wrapped NFT
        ILSP8Bridged(attestedToken.wrappedTokenAddress).mintWithTokenURI(_to, _tokenId, _tokenURI);
        // 3. emit event
        emit WrappedNonFungibleTokensReleased(_tokenId, _to, _attestationID);
    }

    function releaseTokens(uint256 _amount, address _to, address _token) external onlyRelayer {
        bool success = IERC20(_token).transfer(_to, _amount);
        require(success, "Failed to payout tokens");
    }

    function releaseNonFungibleTokens(uint256 _tokenId, address _to, address _token) external {
        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);
    }

    function setTokenFactory(ITokenFactory _tokenFactory) external onlyAdmin {
        require(address(_tokenFactory) != address(0), "Can't set LSP Factory to the zero address");
        tokenFactory = _tokenFactory;
    }

    function onERC721Received(address /* operator */, address /* from */, uint256 /* tokenId */, bytes calldata /* data */) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
