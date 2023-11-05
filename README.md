# Loopso smart contracts

## Token attestation:    
- Chain B must be able to identify a Chain A token   
- addresses don't mean anything since they can differ from chain-to-chain    
- we use attestations: The bridge admin calls on Chain B with details of a Chain A token    
- afterwards Chain B can use this to idenfity a Chain A token    

## Example: bridging 200 USDC from mainnet to Lukso.    
1. user calls ```bridgeTokens(uint256 _amount, address _to, bytes32 _tokenID)```, where ```_tokenID``` is the id of the attestation we recorded about the token. The bridge takes ```_amount``` tokens from the user.    
2. Bridge emits ```TokensBridged``` event with the transfer ID.    
3. Relayer uses the transfer ID to get the transfer details from the bridge. We can implement verification etc. here.    
4. Relayer calls ```releaseWrappedTokens``` on Chain B.    
5. Chain B mints ```_amount``` wrapped tokens, and emits an event that we can use on the frontend to notify the user that briding was successful.    

If the user wants to bridge back, it calls ```bridgeTokensBack```, which burns the amounts of wrapped tokens, and emits a ```TokensBridgedBack``` event which is similar to ```TokensBridged```. Relayer picks it up, calls ```releaseTokens``` on Chain A. The Chain A bridge transfers the amount of tokens to the user.  

![loopso](https://github.com/useloopso/contracts/assets/44027725/0fe78522-4a53-4cc7-8b90-7333e38ed38e)
