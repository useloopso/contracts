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
import "./Constants.sol";

// TODO implement bridging for chains base token
contract Loopso is Constants, AccessControl, ILoopso, IERC721Receiver {
    address public feeReceiver;

    address public discountNft;

    bytes32[] public attestationIds;
    mapping(address => bytes32) wrappedTokenToAttestationId;
    mapping(bytes32 => TokenAttestation) public attestedTokens; // from token ID to TokenAttestation on dest chain
    mapping(bytes32 => TokenTransfer) public tokenTransfers; // from transfer ID to transfer on source chain
    mapping(bytes32 => TokenTransferNonFungible)
        public tokenTransfersNonFungible;

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
    function attestToken(
        TokenAttestation memory attestation
    ) external onlyRelayer {
        address _newTokenAddress;

        if (attestation.tokenType == TokenType.Fungible) {
            _newTokenAddress = tokenFactory.createNewLSP7(
                attestation.name,
                attestation.symbol
            );
        } else {
            _newTokenAddress = tokenFactory.createNewLSP8(
                attestation.name,
                attestation.symbol
            );
        }

        attestation.wrappedTokenAddress = _newTokenAddress;
        bytes32 attestationID = keccak256(
            abi.encodePacked(attestation.tokenAddress, attestation.tokenChain)
        );

        attestedTokens[attestationID] = attestation;

        wrappedTokenToAttestationId[_newTokenAddress] = attestationID;

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
        require(
            !isWrappedToken(_token),
            "This is a wrapped token. Call bridgeTokensBack instead."
        );
        
        uint256 _bridgeFee = hasDiscountNft() ? 0 : calculateFungibleFee(_amount);

        uint256 _amountAfterFee = _amount - _bridgeFee;

        bool success = IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _amountAfterFee
        );
        require(
            success,
            "Transfer failed. Make sure bridge is approved to spend tokens."
        );

        if (!hasDiscountNft()) {
            success = IERC20(_token).transferFrom(msg.sender, address(this), _bridgeFee);
            require(success, "Fee transfer failed. Make sure the bridge is approved to spend tokens.");
        }

        TokenTransfer memory _transfer = TokenTransfer(
            TokenTransferBase(
                block.timestamp,
                block.chainid,
                msg.sender,
                _dstChain,
                _dstAddress,
                _token
            ),
            _amountAfterFee
        );

        bytes32 _transferID = keccak256(
            abi.encodePacked(
                block.timestamp,
                block.chainid,
                msg.sender,
                _dstChain,
                _dstAddress,
                _token,
                _amount
            )
        );

        tokenTransfers[_transferID] = _transfer;

        emit TokensBridged(_transferID, TokenType.Fungible);
    }

    /** @dev See ILoopso.sol - bridgeTokensBack */
    function bridgeTokensBack(
        uint256 _amount,
        address _to,
        bytes32 _attestationID
    ) external {
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(
            attestedToken.tokenAddress != address(0),
            "Invalid _attestationID"
        );

        ILSP7Bridged(attestedToken.wrappedTokenAddress).burn(
            msg.sender,
            _amount,
            new bytes(0)
        );

        emit TokensBridgedBack(_amount, _to, _attestationID);
    }

    /** @dev See ILoopso.sol - releaseTokens */
    function releaseTokens(
        uint256 _amount,
        address _to,
        address _token
    ) external onlyRelayer {
        bool success = IERC20(_token).transfer(_to, _amount);
        require(success, "Failed to payout tokens");
        emit TokensReleased(_amount, _to, _token);
    }

    /** @dev See ILoopso.sol - releaseWrappedTokens */
    function releaseWrappedTokens(
        uint256 _amount,
        address _to,
        bytes32 _attestationID
    ) external onlyRelayer {
        // 1. get the attested token
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(
            attestedToken.tokenAddress != address(0),
            "Invalid _attestationID"
        );
        // 2. mint amount of tokens to the _to address
        ILSP7Bridged(attestedToken.wrappedTokenAddress).mint(
            _to,
            _amount,
            true,
            new bytes(0)
        );
        // 3. emit event
        emit WrappedTokensReleased(_amount, _to, _attestationID);
    }

    /* ============================================== */
    /*  =============  BRIDGE ERC721  ==============  */
    /* ============================================== */
    /** @dev See ILoopso.sol - bridgeNonFungibleTokens */
    function bridgeNonFungibleTokens(
        address _token,
        uint256 _tokenID,
        string memory tokenURI,
        uint256 _dstChain,
        address _dstAddress
    ) external payable {
        require(
            !isWrappedToken(_token),
            "This is a wrapped token. Call bridgeNonFungibleTokensBack instead."
        );

        if (!hasDiscountNft()) {
            require(msg.value == FEE_NON_FUNGIBLE, "Pls pay fee ser we poor");
            (bool success, ) = feeReceiver.call{value: FEE_NON_FUNGIBLE}("");
            require(success, "Fee payment failed.");
        }

        // transfer IERC721 from user to bridge
        IERC721(_token).safeTransferFrom(msg.sender, address(this), _tokenID);
        // create token transfer struct
        TokenTransferNonFungible memory _transfer = TokenTransferNonFungible(
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

        bytes32 _transferID = keccak256(
            abi.encodePacked(
                block.timestamp,
                block.chainid,
                msg.sender,
                _dstChain,
                _dstAddress,
                _token,
                _tokenID
            )
        );
        // save token transfer struct
        tokenTransfersNonFungible[_transferID] = _transfer;
        // emit event
        emit TokensBridged(_transferID, TokenType.NonFungible);
    }

    /** @dev See ILoopso.sol - bridgeNonFungibleTokensBack */
    function bridgeNonFungibleTokensBack(
        uint256 _tokenId,
        address _to,
        bytes32 _attestationID
    ) external {
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(
            attestedToken.tokenAddress != address(0),
            "Invalid _attestationID"
        );
        ILSP8Bridged(attestedToken.wrappedTokenAddress).burn(
            _tokenId,
            new bytes(0)
        );
        emit NonFungibleTokensBridgedBack(_tokenId, _to, _attestationID);
    }

    /** @dev See ILoopso.sol - releaseWrappedNonFungibleTokens */
    function releaseWrappedNonFungibleTokens(
        uint256 _tokenId,
        string calldata _tokenURI,
        address _to,
        bytes32 _attestationID
    ) external {
        // 1. get the attested token
        TokenAttestation memory attestedToken = attestedTokens[_attestationID];
        require(
            attestedToken.tokenAddress != address(0),
            "Invalid _attestationID"
        );
        // 2. mint the correct wrapped NFT
        ILSP8Bridged(attestedToken.wrappedTokenAddress).mintWithTokenURI(
            _to,
            _tokenId,
            _tokenURI
        );
        // 3. emit event
        emit WrappedNonFungibleTokensReleased(_tokenId, _to, _attestationID);
    }

    /** @dev See ILoopso.sol - releaseNonFungibleTokens */
    function releaseNonFungibleTokens(
        uint256 _tokenId,
        address _to,
        address _token
    ) external {
        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);
    }

    /* ============================================== */
    /*  =========== CONVENIENCE GETTERS ============  */
    /* ============================================== */
    /** @dev See ILoopso.sol - isTokenSupported */
    function isTokenSupported(
        address _tokenAddress,
        uint256 _tokenChain
    ) external view returns (bool) {
        if (_tokenAddress == address(0)) {
            return false;
        }
        bytes32 attestationID = keccak256(
            abi.encodePacked(_tokenAddress, _tokenChain)
        );
        TokenAttestation memory attestedToken = attestedTokens[attestationID];
        return
            _tokenAddress == attestedToken.tokenAddress &&
            _tokenChain == attestedToken.tokenChain;
    }

    /** @dev See ILoopso.sol - getSupportedTokensLength */
    function getSupportedTokensLength() external view returns (uint256) {
        return attestationIds.length;
    }

    /** @dev See ILoopso.sol - getAllSupportedTokens */
    function getAllSupportedTokens()
        external
        view
        returns (TokenAttestation[] memory)
    {
        TokenAttestation[] memory attestations = new TokenAttestation[](
            attestationIds.length
        );
        for (uint256 i = 0; i < attestationIds.length; i++) {
            attestations[i] = attestedTokens[attestationIds[i]];
        }
        return attestations;
    }

    function isWrappedToken(address _token) public view returns (bool) {
        return wrappedTokenToAttestationId[_token] != bytes32(0);
    }

    function wrappedTokenInfo(
        address _wrappedToken
    ) external view returns (TokenAttestation memory) {
        return attestedTokens[wrappedTokenToAttestationId[_wrappedToken]];
    }

    /* ============================================== */
    /*  =================  ADMIN  ==================  */
    /* ============================================== */
    function setTokenFactory(ITokenFactory _tokenFactory) external onlyAdmin {
        require(
            address(_tokenFactory) != address(0),
            "Can't set LSP Factory to the zero address"
        );
        tokenFactory = _tokenFactory;
    }

    function setFungibleFee(uint256 _fee) external onlyAdmin {
        require(MIN_FEE < _fee && _fee < MAX_FEE, "Trying to set fee out of bounds");
        FEE_FUNGIBLE = _fee;
    }

    function setNonFungibleFee(uint256 _fee) external onlyAdmin {
        require(MIN_FEE < _fee && _fee < MAX_FEE, "Trying to set fee out of bounds");
        FEE_NON_FUNGIBLE = _fee;
    }

    function setFeeReceiver(address _feeReceiver) external onlyAdmin {
        require(_feeReceiver != address(0), "Receiver cant be the zero address");
        feeReceiver = _feeReceiver;
    }

    function setDiscountNft(address _discountNft) external onlyAdmin {
        discountNft = _discountNft;
    }

    /* ============================================== */
    /*  ===============  INTERNAL  =================  */
    /* ============================================== */
    function calculateFungibleFee(uint256 _amount) internal view returns (uint256) {
        if (FEE_FUNGIBLE == 0) {
            return 0;
        }
        return (_amount * FEE_FUNGIBLE) / 10000;
    }

    function hasDiscountNft() internal view returns (bool) {
        return discountNft == address(0) ? false : IERC721(discountNft).balanceOf(msg.sender) > 0;
    }

    /* ============================================== */
    /*  ============= ERC721 RECEIVER ==============  */
    /* ============================================== */
    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
