// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract Arena is ERC20 {
    
    using SafeMath for uint256;

    uint256 private initialPrice = 2;
    uint256 private afterPrice = 15;
    
    AggregatorV3Interface internal priceFeed;

    
    address private _owner;
    address treasuryWallet = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    
    constructor() ERC20 ("ARENA","ARN") {
        
        _mint(msg.sender, 10000 * (10 ** uint256(decimals())));
        _owner = msg.sender;
        priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);

    }

    function getInitialPriceRate() public view returns (uint256) {
        
        (, int price,,,) = priceFeed.latestRoundData();
        
        uint256 adjust_price = uint256(price) * 1e10;
        uint256 usd = initialPrice.mul(1e18);
        uint256 rate = (usd.mul(1e18)).div(adjust_price);
        
        return rate;
    }

     function getAfterPriceRate() public view returns (uint256) {
        
        (, int price,,,) = priceFeed.latestRoundData();
        
        uint256 adjust_price = uint256(price) * 1e10;
        uint256 usd = afterPrice.mul(1e18);
        uint256 rate = (usd.mul(1e18)).div(adjust_price);
        
        return rate;
    }
    
    
    function sell(uint256 amount) external {
        
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(msg.sender != address(0), "ERC20: approve to the zero address");
        require(balanceOf(msg.sender) >= amount, "You do not have sufficient amount of balance.");
        
        if(balanceOf(treasuryWallet) > 20000000){

            uint256 sendAmount = amount.mul(getAfterPriceRate());
        
            require(address(this).balance >= sendAmount, "You do not have sufficient amount of balance.");
            _transfer(msg.sender, _owner, amount.mul(1e18));    

            payable(msg.sender).transfer(sendAmount);
        }
        else{

            uint256 sendAmount = amount.mul(getInitialPriceRate()); 
            
            require(address(this).balance >= sendAmount, "You do not have sufficient amount of balance.");
            _transfer(msg.sender, _owner, amount.mul(1e18));
            
            payable(msg.sender).transfer(sendAmount);
        }
    }

    function sendEtherToContract() external payable {

    }

    function contractBalance() public view returns(uint256){
        return address(this).balance;
    }

    function setInitialPrice(uint256 _initialPrice) external onlyOwner {
        initialPrice = _initialPrice;
    }

    function setAfterPrice(uint256 _afterPrice) external onlyOwner {
        afterPrice = _afterPrice;
    }

    function getInitialPrice() public view returns(uint256){
        return initialPrice;
    }

    function getAfterPrice() public view returns(uint256){
        return afterPrice;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "only Owner can call this function.");
        _;
    }


}