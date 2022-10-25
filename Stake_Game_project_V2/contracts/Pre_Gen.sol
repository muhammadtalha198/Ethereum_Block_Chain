// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GEN is ERC20, Ownable {

    using SafeMath for uint256;

    uint256 genTokenPrice = 5000000; // wei  in eth 0.000000000005
    address public _owner;

    //Texsation percentages
    uint256 private winnerCirclePercentage = 100; // 1% 
    uint256 private areenaTokenPercentage = 200; // 2%
    uint256 private liquidityPoolPercentage = 400; // 4%
    uint256 private insuranceFundPercentage = 400; // 4%
    uint256 private treasuryPercentage = 200; // 2%
    uint256 private burnPercentage = 200; // 2%
    
    
    uint256 private insuranceFundPercentageSale = 500; // 5%
    uint256 private treasuryPercentageSale = 300; // 3%

    //Wallets
    address private ownerWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private treasuryWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private insuranceFundWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private marketingDevelopmentWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private areenaTokenFundWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private liquidityPoolWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private winnerCircleWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private A1 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    


    constructor() ERC20 ("GEN","Gen") {

        _owner = msg.sender;
        _mint(msg.sender, 2000000 * (10 ** uint256(decimals())));
    }

    
    
    //--------------------Buy Token-----------------------------------

        
    function buy(uint256 _amount) external payable {
        
        require(msg.value >= _amount * genTokenPrice, "Need to send exact amount of wei");
        require(msg.sender != _owner, "Owner canot be able to buy his own tokens.");

        uint256 noOftokens = _amount.mul(1000000000000000000);
        require(balanceOf(_owner) >= noOftokens, "there are no more tokens left to Buy.");

       uint256 winnerCircleAmount = calculateWinnerCirclePercentage(noOftokens); // 1%
        uint256 areenaTokenAmount = calculateAreenaTokenPercentage (noOftokens);// 2%
        uint256 liquidityPoolAmount = calculateLiquidityPoolPercentage (noOftokens);// 4%
        uint256 insuranceFundAmount = calculateInsuranceFundPercentage(noOftokens);// 4%
        uint256 treasuryAmount = calculateTreasuryPercentage(noOftokens);// 2%
        uint256 burnAmount = calculateBurnPercentage(noOftokens);// 2%
        
        uint256 totaldeductedTokens =  winnerCircleAmount + areenaTokenAmount + liquidityPoolAmount + insuranceFundAmount + treasuryAmount + burnAmount;
        uint256 afterdeductionTokens = noOftokens - totaldeductedTokens;

        
        _transfer(_owner, msg.sender, afterdeductionTokens);
        _transfer(_owner, winnerCircleWallet, winnerCircleAmount); // require address
        _transfer(_owner, areenaTokenFundWallet, areenaTokenAmount);
        _transfer(_owner, liquidityPoolWallet, liquidityPoolAmount);
        _transfer(_owner, insuranceFundWallet, insuranceFundAmount);
        _transfer(_owner, treasuryWallet, treasuryAmount);
        _burn(_owner ,burnAmount);

        payable(_owner).transfer(msg.value);

    }

    //---------------------------Sell Token----------------------------------
    
    function sell(uint256 _amount) external {

      
        uint256 noOftokens = _amount.mul(1000000000000000000);
        require(balanceOf(msg.sender) >= noOftokens, " You donot have that amount of tokens to sell.");


        uint256 winnerCircleAmount = calculateWinnerCirclePercentage(noOftokens); // 1%
        uint256 areenaTokenAmount = calculateAreenaTokenPercentage (noOftokens); // 2%
        uint256 liquidityPoolAmount = calculateLiquidityPoolPercentage (noOftokens);// 4%
        uint256 insuranceFundAmount = calculateInsuranceFundPercentageSale(noOftokens); // 5%
        uint256 treasuryAmount = calculateTreasuryPercentageSale(noOftokens); // 3%
        uint256 burnAmount = calculateBurnPercentage(noOftokens); // 2%
        
        uint256 totaldeductedTokens =  winnerCircleAmount + areenaTokenAmount + liquidityPoolAmount + insuranceFundAmount + treasuryAmount + burnAmount;
        uint256 afterdeductionTokens = noOftokens - totaldeductedTokens;

       
        _transfer(msg.sender, address(this), noOftokens);
        _transfer(address(this), _owner, afterdeductionTokens);
        _transfer(address(this), winnerCircleWallet, winnerCircleAmount); // require address
        _transfer(address(this), areenaTokenFundWallet, areenaTokenAmount);
        _transfer(address(this), liquidityPoolWallet, liquidityPoolAmount);
        _transfer(address(this), insuranceFundWallet, insuranceFundAmount);
        _transfer(address(this), treasuryWallet, treasuryAmount);
        _burn(address(this) ,burnAmount);
        
     }
    


    
    function calculatePercentage(uint256 percentageValue, uint amount) public pure returns(uint256){

        require(percentageValue <= 10000, "ERC2981: royalty fee will exceed salePrice");
        return amount.mul(percentageValue).div(10000); 
    }

    
    
    function calculateWinnerCirclePercentage(uint _amount) private view returns(uint256){
        return calculatePercentage(winnerCirclePercentage, _amount);
    }
    
    function calculateAreenaTokenPercentage (uint _amount) private view returns(uint256){

        return calculatePercentage(areenaTokenPercentage, _amount);
    }

    function calculateLiquidityPoolPercentage (uint _amount) private view returns(uint256){

        return calculatePercentage(liquidityPoolPercentage, _amount);
    }

    function calculateInsuranceFundPercentage(uint _amount) private view returns(uint256){

        return calculatePercentage(insuranceFundPercentage, _amount);
    }

    
    function calculateTreasuryPercentage(uint _amount) private view returns(uint256){

        return calculatePercentage(treasuryPercentage, _amount);
    }
    
    function calculateBurnPercentage(uint _amount) private view returns(uint256){

        return calculatePercentage(burnPercentage, _amount);
    }

    function calculateInsuranceFundPercentageSale(uint _amount) private view returns(uint256){

        return calculatePercentage(insuranceFundPercentageSale, _amount);
    }

    
    function calculateTreasuryPercentageSale(uint _amount) private view returns(uint256){

        return calculatePercentage(treasuryPercentageSale, _amount);
    }


}
