pragma solidity ^0.5.16;

import './interfaces/IEelswapPair.sol';
import './EelswapERC20.sol';
import './interfaces/IEelswapFactory.sol';
import './interfaces/IERC20.sol';
import './libraries/Math.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract EelswapPair is IEelswapPair, EelswapERC20{
    using SafeMath for uint;
    
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));


    address public factory;
    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() public {
        factory = msg.sender;
    }

    function initialize (address _token0, address _token1) external {
        require(msg.sender == factory, "NOT ALLOWED");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast){
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    //updates reserves and timestamp of last transaction
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private{
        require(balance0 <= type(uint256).max && balance1 <= type(uint256).max, "OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        // uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function mint(address to) external lock returns (uint liquidity){
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token0).balanceOf(address(this));
        
        //need these values to calculate amount of LPtokens
        //These values are the amount of tokens added into the pool most recently
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        //The totalSupply variable is inherited from EelswapERC20
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0){
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            //This is done to keep a minimum amount in the pool
            _mint(address(0), MINIMUM_LIQUIDITY);
        }else{

            //The amount of LPtokens is the lesser input token amount over original amt
            liquidity = Math.min(amount0.mul(_totalSupply)/_reserve0, amount1.mul(_totalSupply)/_reserve1);

        }

        require(liquidity > 0, "INVALID LIQUIDITY MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);

    }


    function burn(address to) external lock returns(uint amount0, uint amount1){
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        uint _totalSupply = totalSupply;

        //get the amount of tokens respectively according to the fraction of lptokens the user has
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT LIQUIDITY BURNED");
        
        //Then burn the liudity
        _burn(address(this), liquidity);

        //Transfer the tokens back to the user
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'INSUFFICIENT OUTPUT AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT LIQUIDITY");

        uint balance0;
        uint balance1;

        // These brackets apparently are to avoid stack too deep errors
        // {
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, "INVALID_RECIEPIENT");
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
        // if(data.length > 0) 
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        // }

        //Sanity check to make sure we dont lose money from the swap
        //If value was indeed xfer'd out then balance = reserve - amountOut and therefore 
        //amount in should be 0
        //If balance > reserve - amountOut it prob means amountOut is 0, reserve isnt the live value
        //So we assign amount in to be live balance - the last udpated balance (reserve)
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT INPUT AMOUNT");

        // This is if tx fee applies
        // uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        // uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        // require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');

        //No tx fee
        require(balance0.mul(balance1) >= uint(_reserve0).mul(_reserve1), "K VALUE NO MATCH");

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    //This function is used to force update balances values
    function skim(address to) external lock{
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    //This function is used to force update reserve values
    function sync() external lock{
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}