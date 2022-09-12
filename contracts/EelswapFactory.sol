pragma solidity ^0.5.16;

import './interfaces/IEelswapFactory.sol';

contract EelswapFactory is IEelswapFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    address owner;

    event airCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor() public {
        owner = msg.sender;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Identical Addresses");
        // This is done to ensure the tokens are in order
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        require(token0 != address(0), "Token should not be from zero address");
        require(getPair[token0][token1] == address(0), "The pair already exists");

        // Create a pair contract
    }
}