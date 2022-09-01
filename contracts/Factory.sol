//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Pair.sol";

contract Factory{
    mapping(address => address) public pairs;

    function createPair(address tokenAddress) public returns (address pairAddress){
        require(tokenAddress!=address(0), "invalid token address");
        require(pairs[tokenAddress] == address(0), "This pair already exists");

        Pair pair = new Pair(tokenAddress);
        pairs[tokenAddress] = address(pair);

        pairAddress = address(pair);
    }

    function getPair(address tokenAddress) public view returns (address pairAddress){
        pairAddress = pairs[tokenAddress];
        require(pairAddress != address(0), "Pair does not exist");
        
    }
}