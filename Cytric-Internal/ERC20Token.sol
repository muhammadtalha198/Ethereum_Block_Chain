
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}


interface IUniswapV2Router01 {
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
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}



interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.0/contracts/access/Ownable.sol";



contract MyToken is ERC20, Ownable {
    
    
    IUniswapV2Router02 public  uniswapV2Router;
    address public  uniswapV2Pair;
    
    bool private isLiquidityAdded;
    uint256 private antiBotBlocks;
    uint256 private liquidityBotBlock;
    uint256 private taxPercentage;
    address private marketingWallet;

    uint256 public _buyFee; // 200 = 2.00%
    uint256 public _sellFee; // 100 = 1.00%
    uint256 public totalBuyingTax;
    uint256 public totalSellingTax;



    mapping(address => bool) public whiteListed;
    mapping(address => bool) isExcludedFromFee;
    mapping(address => uint256) internal _balances;

    constructor(

        address[] memory wallets,
        uint256[] memory tokenAmounts,
        uint256 initialLiquidity,
        uint256 _buyTaxPercentage,
        uint256 _sellTaxPercentage,
        uint256 _antiBotBlocks,
        address _marketingWallet

    ) ERC20("MyToken", "MTK") {

        require(wallets.length == tokenAmounts.length, "Invalid input");

        for (uint256 i = 0; i < wallets.length; i++) {
            _mint(wallets[i], tokenAmounts[i]);
        }

        _mint(address(this), initialLiquidity);

        _buyFee = _buyTaxPercentage * 100;
        _sellFee = _sellTaxPercentage * 100;
        antiBotBlocks = _antiBotBlocks;
        marketingWallet = _marketingWallet;
        isLiquidityAdded = false;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        
        uniswapV2Router = _uniswapV2Router;

    }

    
    function addLiquidity( uint256 ethAmount) external payable liquidityAdded onlyOwner {
        
        uint256 tokenAmount = balanceOf(address(this));
        
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, 
            0,
            owner(),
            block.timestamp
        ); 

        liquidityBotBlock = block.number;
        isLiquidityAdded = true;
    }


    function _transfer(address sender, address recipient, uint256 amount) internal override
    beforeliquidityNotAdded(sender,recipient ) {


        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        uint256 transferAmount = amount;

        if(block.number < liquidityBotBlock + antiBotBlocks){
            transferAmount = FullFee(sender,amount);
        }
        else if(whiteListed[sender] || whiteListed[recipient]){
            transferAmount = amount;     
        }
        else{

            if(isExcludedFromFee[sender] && isExcludedFromFee[recipient]){
                transferAmount = amount;
            }
            if(isExcludedFromFee[sender] && !isExcludedFromFee[recipient]){
                transferAmount = BuyFee(sender,amount);
            }
            if(!isExcludedFromFee[sender] && isExcludedFromFee[recipient]){
                transferAmount = SellFee(sender,amount);
            }
        }   

        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + transferAmount;
        
        emit Transfer(sender, recipient, transferAmount);
    }

    function FullFee(address account, uint256 amount) private returns (uint256) {
        
        uint256 transferAmount = amount;

        uint256 _fullFee = 10000; // 100 %
        uint256 fullFee = amount * (_fullFee) / (10000);

        if (fullFee > 0){
            transferAmount = transferAmount - (fullFee);
            _balances[marketingWallet] = _balances[marketingWallet] + (fullFee);
            totalBuyingTax = totalBuyingTax + (fullFee);
            emit Transfer(account,marketingWallet,fullFee);
        }
        return transferAmount;
     }


     function BuyFee(address account, uint256 amount) private returns (uint256) {
        
        uint256 transferAmount = amount;
        uint256 buyFee = amount * (_buyFee) / (10000);

        if (buyFee > 0){
            transferAmount = transferAmount - (buyFee);
            _balances[marketingWallet] = _balances[marketingWallet] + (buyFee);
            totalBuyingTax = totalBuyingTax + (buyFee);
            emit Transfer(account,marketingWallet,buyFee);
        }
        return transferAmount;
     }

     function SellFee(address account, uint256 amount) private  returns (uint256) {
        
        uint256 transferAmount = amount;
        uint256 sellFee = amount * (_sellFee) / (10000);

        if (sellFee > 0){
            transferAmount = transferAmount - (sellFee);
            _balances[marketingWallet] = _balances[marketingWallet] + (sellFee);
            totalSellingTax = totalSellingTax + (sellFee);
            emit Transfer(account,marketingWallet,sellFee);
        }
       
        return transferAmount;
    }
    


     modifier beforeliquidityNotAdded(address sender, address recipient) {
        
        if (sender != owner() && recipient != owner()){
            require(!isLiquidityAdded, "Liquidity already added");
        }
        _;
    }

    modifier liquidityAdded() {
        require(!isLiquidityAdded, "Liquidity already added.");
        _;
    }



}



// function transfer(address recipient, uint256 amount) public override onlyNonContract liquidityAdded returns (bool) {
    //     _taxTransfer(_msgSender(), recipient, amount);
    //     return true;
    // }

    // function transferFrom(address sender, address recipient, uint256 amount) public override onlyNonContract liquidityAdded returns (bool) {
    //     _taxTransfer(sender, recipient, amount);
    //     _approve(sender, _msgSender(), allowance(sender, _msgSender()) - amount);
    //     return true;
    // }

    // function _taxTransfer(address sender, address recipient, uint256 amount) private {
    //     if (taxPercentage == 0 || antiBotBlocks > block.number) {
    //         _transfer(sender, recipient, amount);
    //     } else {
    //         uint256 taxAmount = (amount * taxPercentage) / 100;
    //         uint256 transferAmount = amount - taxAmount;

    //         _transfer(sender, recipient, transferAmount);
    //         _transfer(sender, address(this), taxAmount);

    //         _swapTokensForETH(address(this).balance);
    //         _transferETHToMarketingWallet();
    //     }
    // }

    // function _swapTokensForETH(uint256 tokenAmount) private {
    //     address[] memory path = new address[](2);
    //     path[0] = address(this);
    //     path[1] = uniswapRouter.WETH();

    //     _approve(address(this), uniswapRouter, tokenAmount);
    //     uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
    //         tokenAmount,
    //         0,
    //         path,
    //         address(this),
    //         block.timestamp
    //     );
    // }

    // function _transferETHToMarketingWallet() private {
    //     uint256 contractBalance = address(this).balance;
    //     if (contractBalance > 0) {
    //         payable(marketingWallet).transfer(contractBalance);
    //     }
    // }
