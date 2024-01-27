// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


 import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


import "https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FixedPoint96.sol";
import "https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol";
import "https://github.com/pancakeswap/pancake-v3-contracts/blob/main/projects/v3-core/contracts/interfaces/IPancakeV3Factory.sol";
import "https://github.com/pancakeswap/pancake-v3-contracts/blob/main/projects/v3-core/contracts/interfaces/IPancakeV3Pool.sol";

contract TokenPriceCalculator {

    constructor(){
    }

    address public _PoolContract;
    uint256 public numberOne;
    uint256 public numberTwo;
    uint256 public numberThree;
    uint256 public _sqrtPriceX96;


    function calculatePriceFromLiquidity(
    address token0,
    address token1,
    uint24 fee,
    address factory
    ) public  returns (uint256) {


         _PoolContract = IPancakeV3Factory(factory).getPool(token0, token1, fee);
        
        (uint160 sqrtPriceX96, , , , , , ) = IPancakeV3Pool(_PoolContract).slot0();
        _sqrtPriceX96 = sqrtPriceX96;
        
        uint256 amount0 = FullMath.mulDiv(IPancakeV3Pool(_PoolContract).liquidity(), FixedPoint96.Q96, sqrtPriceX96);
        numberOne = amount0;
        
        uint256 amount1 = FullMath.mulDiv(IPancakeV3Pool(_PoolContract).liquidity(), sqrtPriceX96, FixedPoint96.Q96);
        
        
        numberTwo = amount1;
        
        numberThree =  (amount1 * 10**ERC20(token0).decimals()) / amount0;
        
        return sqrtPriceX96;
    }



    
    uint256 public numberOne2_1;
    uint256 public numberTwo2_1;
    uint256 public numberThree2_1;
    uint256 public _sqrtPriceX962_1;



    function calculatePriceFromLiquidity2to1(
    address token0,
    address token1,
    uint24 fee,
    address factory
    ) public  returns (uint256) {


         _PoolContract = IPancakeV3Factory(factory).getPool(token0, token1, fee);
        
        (uint160 sqrtPriceX96, , , , , , ) = IPancakeV3Pool(_PoolContract).slot0();
        _sqrtPriceX962_1 = sqrtPriceX96;
        
        uint256 amount0 = FullMath.mulDiv(IPancakeV3Pool(_PoolContract).liquidity(), FixedPoint96.Q96, sqrtPriceX96);
        numberOne2_1 = amount0;
        
        uint256 amount1 = FullMath.mulDiv(IPancakeV3Pool(_PoolContract).liquidity(), sqrtPriceX96, FixedPoint96.Q96);
        
        
        numberTwo2_1 = amount1;
        
        numberThree2_1 =  (amount0 * 10**ERC20(token0).decimals()) / amount1;
        
        return _sqrtPriceX962_1;
    }

    function WhenLiquidityNotZero(
    address token0,
    address token1,
    uint24 fee,
    address factory
    ) public  returns (uint256) {


         _PoolContract = IPancakeV3Factory(factory).getPool(token0, token1, fee);
        
        (uint160 sqrtPriceX96, , , , , , ) = IPancakeV3Pool(_PoolContract).slot0();
        // _sqrtPriceX96 = sqrtPriceX96;
        
        require(IPancakeV3Pool(_PoolContract).liquidity() !=0, "liquidity is zero");
        
        uint256 amount0 = FullMath.mulDiv(IPancakeV3Pool(_PoolContract).liquidity(), FixedPoint96.Q96, sqrtPriceX96);
        // numberOne = amount0;
        
        uint256 amount1 = FullMath.mulDiv(IPancakeV3Pool(_PoolContract).liquidity(), sqrtPriceX96, FixedPoint96.Q96);
        
        
        // numberTwo = amount1;
        
        return  (amount1 * 10**ERC20(token0).decimals()) / amount0;
        
        
    }

    uint256 public _sqrtPriceX96_1;
    uint256 public numberTwo2;
    uint256 public numberThree3;

    function sqrtPriceX96ToUint(
    address token0,
    address token1,
    uint24 fee,
    address factory)
    public 
    
    returns (uint256){

        _PoolContract = IPancakeV3Factory(factory).getPool(token0, token1, fee);
        
        (uint160 sqrtPriceX96, , , , , , ) = IPancakeV3Pool(_PoolContract).slot0();

        _sqrtPriceX96_1 = sqrtPriceX96;

        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        uint256 numerator2 = 10**ERC20(token0).decimals();
        return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
    }
}

