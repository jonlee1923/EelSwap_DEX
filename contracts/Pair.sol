//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Pair contract is essentially ERC20 and IERC20 is the interface contract 
// that will be used to interact with other ERC20 contracts if need be
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// This interface is added to be able to interact with other exchanges 
// It allows us to call the functions listed
interface IPair{

    //Defined as external payable to allow the function to accept value
    function ethToTokenSwap(uint256 expectedTokenAmount) external payable;
    function ethToTokenTransfer(uint256 expectedTokenAmount, address recipient) external payable;
}

interface IFactory {
    function getExchange(address tokenAddress) external returns (address);
}

contract Pair is ERC20 {
    address public tokenAddress;
    address public factoryAddress;

    // The indexed keyword allows us to search for these events using indexed parameters as filters
    event SwapForTokens(address indexed buyer, uint256 indexed ethGiven, uint256 tokensRecieved);
    event SwapForEth(address indexed buyer, uint256 indexed tokensGiven, uint256 ethRecieved);
    event AddLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    uint constant txFee = 0;

    // constructor takes in a parameter for the address of the token, for this pair contract
    constructor(address token) ERC20("Swap V1", "Swap-V1"){
        require(token != address(0), "Invalid address");
        tokenAddress = token;
        factoryAddress = msg.sender;
    }

    function getReserves() public view returns (uint256 tokenReserve, uint256 ethReserve) {
        tokenReserve = IERC20(tokenAddress).balanceOf(address(this));
        ethReserve = address(this).balance;
    }

    function addLiquidity(uint256 inputTokenAmount uint) public payable returns (uint256 lpTokenAmount){
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();

        // uint256 requiredTokenInput = msg.value * tokenReserve/ethReserve; //calculate the amount of tokenInput required to ensure the ratio is the same
        
        //New liquidity pool
        if (tokenReserve == 0) {
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), inputTokenAmount);
            lpTokenAmount = ethReserve; 
        }
        //Existing liquidity pool
        else{
            ethReserve -= msg.value; //This is done as the msg.value has already been added to the ethReserve
            uint256 requiredTokenInput = msg.value * tokenReserve/ethReserve; //calculate the amount of tokenInput required to ensure the ratio is the same
            require(inputTokenAmount >= requiredTokenInput, "Insufficient input amount of ERC20 Tokens");
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), inputTokenAmount);
            lpTokenAmount = (totalSupply() * msg.value) / ethReserve;
        }

        _mint(msg.sender, lpTokenAmount);
        emit AddLiquidity(msg.sender, msg.value, inputTokenAmount);
    }

    function removeLiquidity(uint256 lpTokenAmount) public returns (uint256 ethAmount, uint256 tokenAmount){
        require(lpTokenAmount > 0, "Please input a valid amount of LP Tokens to burn/redeem");

        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        ethAmount = (ethReserve * lpTokenAmount) / totalSupply();
        tokenAmount = (tokenReserve * lpTokenAmount) / totalSupply();

        _burn(msg.sender, lpTokenAmount);
        (bool sent, ) = (msg.sender).call{value: ethAmount}("");
        require(sent, "Transaction of Ether was unsuccessful");
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
    }

    function getOutputAmount(uint256 ipAmount, uint256 ipReserve, uint256 opReserve) private pure returns (uint256 opAmount) {
        require(ipReserve > 0 && opReserve > 0, "There are no reserves");
        uint256 ipAmountPlusFee = ipAmount * (1000 - txFee);
        opAmount = ipAmountPlusFee * opReserve / (1000 * ipReserve + ipAmountPlusFee);
    }

    //Use this function to get the exchange amount
    function getTokenAmountForSwap(uint256 ethAmount) public view returns (uint256 tokenAmount){
        require(ethAmount > 0, "ETH amount cannot be zero");

        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        //Amount of ETH in exchange for tokens
        tokenAmount = getOutputAmount(ethAmount, ethReserve, tokenReserve);
    }

    //Use this function to get the exchange amount
    function getEthAmountForSwap(uint256 tokenAmount) public view returns (uint256 ethAmount){
        require(ethAmount > 0, "ETH amount cannot be zero");

        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        //Amount of ETH in exchange for tokens
        ethAmount = getOutputAmount(tokenAmount, tokenReserve, ethReserve);
    }

    //Base function to be called by other functions
    function ethForTokenBasic(uint256 tokenAmount, address recipient) private {
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        uint256 tokensRecieved = getOutputAmount(msg.value, ethReserve - msg.value, tokenReserve);

        require(tokensRecieved >= tokenAmount, "Amount swapped does not meet your stipulated amount, reverting swap");

        IERC20(tokenAddress).transfer(recipient, tokensRecieved);
        emit SwapForTokens(recipient, msg.value, tokensRecieved);
    }

    //Can be used to swap for oneself and also to maybe swap and pay others
    function ethForTokenHigh(uint256 tokenAmount, address recipient) public payable{
        ethForTokenBasic(tokenAmount, recipient);
    }

    //used for implicit calling
    function ethForTokenImplicit(uint256 tokenAmount) public payable {
        ethForTokenBasic(tokenAmount, msg.sender);
    }

    //
    function tokenForEthSwap(uint256 ipTokenAmount, uint256 opEthAmount) public {
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();

        uint256 ethRecieved = getOutputAmount(ipTokenAmount, tokenReserve, ethReserve);

        require(ethRecieved >= opEthAmount, "Amount swapped does not meet your stipulated amount, reverting swap");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), ipTokenAmount);
        (bool sent, ) = (msg.sender).call{value: opEthAmount}("");
        require(sent, "Transaction of ETH to recipient failed");
        emit SwapForEth(msg.sender, ipTokenAmount, ethRecieved);
    }


    function tokenToTokenSwap(uint256 ipTokenAmount, uint256 opTokenAmount, address opTokenAddress) public {
        require(opTokenAddress != address(0), "Token address is invalid");
        require(ipTokenAmount > 0, "Invalid input token amount");
        address opTokenExchangeAddress = IFactory(factoryAddress).getExchange(opTokenAddress);

        require(opTokenExchangeAddress != address(this) && opTokenExchangeAddress != address(0),"Invalid exchange address");

        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        
        uint256 ethAmount = getOutputAmount(ipTokenAmount, tokenReserve, ethReserve);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), ipTokenAmount);
        IPair(opTokenExchangeAddress).ethToTokenTransfer{value: ethAmount}(opTokenAmount, msg.sender);

    }
}

