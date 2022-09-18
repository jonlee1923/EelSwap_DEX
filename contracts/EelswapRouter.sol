pragma solidity ^0.5.16 ;


import "./interfaces/IEelswapFactory.sol";
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

// import './'
import './interfaces/IEelswapRouter.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './libraries/EelswapLibrary.sol';

contract EelswapRouter is IEelswapRouter{
    address public factory;
    address public WETH;

    modifier ensure(uint deadline){
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    // Code fallback function

    // This function calculates how much of tokenA and tokenB are added to the liquidity pool
    function _addLiqudity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private returns (uint amountA, uint amountB){

        //This creates a pair contract if it has not been made yet
        if (IEelswapFactory(factory).getPair(tokenA, tokenB) == address(0)){
            IEelswapFactory(factory).createPair(tokenA, tokenB);
        }

        (uint reserveA, uint reserveB) = EelswapLibrary.getReserves(factory, tokenA, tokenB);

        //If this is a new pool the initial liquidity will define the ratio so can just add in
        if(reserveA == 0 && reserveB == 0){
            (amountA, amountB) = (amountADesired, amountBDesired);

        } else {//For a already created pool we have to check the ratio 
    
            uint amountBOptimal = EelswapLibrary.quote(amountADesired, reserveA, reserveB);
            if(amountBOptimal <= amountBDesired){
                require(amountBOptimal >= amountBMin, 'INSUFFICIENT AMOUNT OF B');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            }else{
                uint amountAOptimal = EelswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'INSUFFICIENT AMOUNT OF A');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity){
        (amountA, amountB) = _addLiqudity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = EelswapLibrary.pairFor(factory, tokenA, tokenB);
        //not sure if these will work with my test tokens
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IEelswapPair(pair).mint(to);
    }

    function AddLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )external payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity){
        (amountToken, amountETH) = _addLiqudity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        address pair = EelswapLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        // IWETH(WETH).deposit{value: amountETH}();
        IWETH(WETH).deposit.value(amountETH)();

        //ensures transfer returns true and transfers weth to the pair
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IEelswapPair(pair).mint(to);
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);

    }




}