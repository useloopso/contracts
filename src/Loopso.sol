// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/ILoopso.sol";
import "./interfaces/ILSPFactory.sol";
import "./interfaces/IERCFactory.sol";
import "./interfaces/ILSP7Bridged.sol";

contract Loopso is AccessControl, ILoopso {
    uint256 constant LUKSO_CHAIN_ID = 4201;
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    // TODO: uint256 public BRIDGE_FEE

    mapping(bytes32 => TokenAttestation) public attestedTokens; // from token ID to TokenAttestation on dest chain
    mapping(bytes32  => TokenTransfer) public tokenTransfers; // from transfer ID to transfer on source chain

    ILSPFactory public lspFactory;
    IERCFactory public ercFactory;

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

        if (block.chainid == LUKSO_CHAIN_ID) {
            if (attestation.tokenType == TokenType.Fungible) {
             _newTokenAddress = lspFactory.createNewLSP7(attestation.name, attestation.symbol);
            } else {
                _newTokenAddress = lspFactory.createNewLSP8(attestation.name, attestation.symbol);
            }
        } else {
            if (attestation.tokenType == TokenType.Fungible) {
             _newTokenAddress = ercFactory.createNewERC20(attestation.name, attestation.symbol);
            } else {
                _newTokenAddress = ercFactory.createNewERC721(attestation.name, attestation.symbol);
            }
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
        emit TokensBridged(_transferID);
    }

    function bridgeNonFungibleTokens(address _token, uint256 _tokenID, uint256 _dstChain, address _dstAddress) external {
        // TODO
    }

    function bridgeTokensBack(uint256 _amount, address _to, bytes32 _tokenID) external {
        // 1. get attested token
        TokenAttestation memory attestedToken = attestedTokens[_tokenID];
        require(attestedToken.tokenAddress != address(0), "Invalid _tokenID");
        // 2. burn amount of tokens
        ILSP7Bridged(attestedToken.wrappedTokenAddress).burn(msg.sender, _amount, new bytes(0));
        // 3. emit proper event
        emit TokensBridgedBack(_amount, _to, _tokenID);
    }

    function bridgeNonFungibleTokensBack() external {
        // TODO
    }

    function releaseWrappedTokens(uint256 _amount, address _to, bytes32 _tokenID) external onlyRelayer {
        // 1. get the attested token
        TokenAttestation memory attestedToken = attestedTokens[_tokenID];
        require(attestedToken.tokenAddress != address(0), "Invalid _tokenID");
        // 2. mint amount of tokens to the _to address
        ILSP7Bridged(attestedToken.wrappedTokenAddress).mint(_to, _amount, false, new bytes(0));
        // 3. emit event
        emit WrappedTokensReleased(_amount, _to, _tokenID);
    }

    function releaseWrappedNonFungibleTokens() external {
        // TODO
    }

    function releaseTokens(uint256 _amount, address _to, address _token) external onlyRelayer {
        bool success = IERC20(_token).transfer(_to, _amount);
        require(success, "Failed to payout tokens");
    }

    function releaseNonFungibleTokens() external {
        // TODO
    }

    function setLSPFactory(ILSPFactory _lspFactory) external onlyAdmin {
        require(address(_lspFactory) != address(0), "Can't set LSP Factory to the zero address");
        lspFactory = _lspFactory;
    }

    function setERCFactory(IERCFactory _ercFactory) external onlyAdmin {
        require(address(_ercFactory) != address(0), "Can't set ERC Factory to the zero address");
        ercFactory = _ercFactory;
    }
}
