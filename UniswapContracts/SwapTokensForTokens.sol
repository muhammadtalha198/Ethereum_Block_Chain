// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20 {
   
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)external returns (bool);
    function allowance(address owner, address spender)external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
interface IUniswapV2Factory {
    
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
}

interface IUniswapV2Router02{
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract SwapTokenContract is Ownable{

    address public tokenA ; 
    address public tokenB;

    IUniswapV2Router02 public  uniswapV2Router;
    address public  uniswapV2Pair; 
    
    event Log(uint256 amountTokenA, uint256 amountTokenB, uint256 totalyLiquidityTokens);

    constructor (address _tokenA, address _tokenB){

        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
             .createPair(_tokenA, _tokenB);
        
        
    }

    function addLiqidity(uint256 _amountTokenA, uint256 _amountTokenB) external onlyOwner{
        
        IERC20(tokenA).transferFrom(msg.sender, address(this), _amountTokenA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), _amountTokenB);

        IERC20(tokenA).approve( address(uniswapV2Router), _amountTokenA);
        IERC20(tokenB).approve( address(uniswapV2Router), _amountTokenB);

        (uint256 amountTokenA, uint256 amountTokenB, uint256 totalyLiquidityTokens)=
        uniswapV2Router.addLiquidity(
            tokenA,
            tokenB,
            _amountTokenA,
            _amountTokenB,
            0,
            0,
            owner(),
            block.timestamp
        );

        emit Log(amountTokenA, amountTokenB, totalyLiquidityTokens);

    }

    function swapTokens() external {

    }
}
