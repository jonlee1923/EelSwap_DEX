pragma solidity ^0.5.16;

import './interfaces/IEelswapFactory.sol';
import './EelswapPair.sol';

contract EelswapFactory is IEelswapFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    address owner;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

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

        //This is done to have a deterministic contract, where we decide how the address of the contract is determined
        //https://ethereum-blockchain-developer.com/110-upgrade-smart-contracts/12-metamorphosis-create2/
        //https://medium.com/coinmonks/pre-compute-contract-deployment-address-using-create2-8c01e80ab7da 
        bytes memory bytecode = type(EelswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly{
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IEelswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}