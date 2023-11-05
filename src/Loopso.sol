// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


/* 
    - access control
        Emit event to support a token on one chain
        Offline node picks up, call support token on dest chain

        Send token: locks up tokens on src chain, emits event
        ReleaseToken: mints wrapped tokens based on call from dest chain
        Send back token: burn wrapped token, unlock token on src chain
 */

contract Loopso {

}