// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

contract Market is Ownable {

    IERC20 public usdcToken;

    struct MarketInfo {

        bool marketOpen;
        uint256 endTime;
        uint256 totalBets;
        uint256 totalAmount;
        uint256[2] initialPrice;
        uint256 totalBetsOnYes;
        uint256 totalBetsOnNo;
    }

    struct UserInfo{
        bool bet;
        bool buyed;
        bool setForSale;
        uint256 betOn;
        uint256 onPrice;
        uint256 betAmount;
        uint256 buyAmount;
        uint256 saleAmount;
        uint256 noOfShares;
        address owner;
        uint256 rewardAmount;

    }

    uint256 public totalUsers;

    mapping(uint256 => address) public eachUser;
    mapping(address => MarketInfo) public marketInfo;
    mapping(address => mapping(address => UserInfo)) public userInfo;
    

   
    event WithdrawWinner (uint256 indexed outcomeIndex);
    event MarketResolved(uint256 indexed winningOutcomeIndex);
    event RemainingTransfer(address owner,uint256 remainingBalance);
    event BuyEvent(address indexed user,uint256 indexed _amount,uint256 _betOn);
    event SellEvent(address indexed user, uint256 outcomeIndex, uint256 _amount, uint256 returnAmount);


    constructor(
        address initialOwner,
        address _usdcToken,
        uint256 _endTime ) 

        Ownable(initialOwner) {

            marketInfo[address(this)].endTime = _endTime;
            marketInfo[address(this)].marketOpen = true ;
            marketInfo[address(this)].initialPrice[0] = 500000000000000000;
            marketInfo[address(this)].initialPrice[1] = 500000000000000000;
            usdcToken = IERC20(_usdcToken);
            


    }

    function Bet(uint256 _amount, uint256 _betOn) external {
       
        require(_betOn == 0 || _betOn == 1, "you either bet yes or no.");
        require(_amount > 0, "Bet amount must be greater than 0");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        // require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");

        userInfo[address(this)][msg.sender].bet = true;
        userInfo[address(this)][msg.sender].betOn = _betOn;
        userInfo[address(this)][msg.sender].betAmount += _amount;
        uint256 _noOfShares = calculateShares( userInfo[address(this)][msg.sender].betAmount, _betOn);
        userInfo[address(this)][msg.sender].noOfShares = _noOfShares;
        userInfo[address(this)][msg.sender].owner = msg.sender;

        eachUser[totalUsers] = msg.sender;
        totalUsers++;

        if(_betOn == 0 ){
          marketInfo[address(this)].totalBetsOnNo++;  

        }else {
          marketInfo[address(this)].totalBetsOnYes++;  
        }

        (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = 
            PriceCalculation(marketInfo[address(this)].totalBetsOnNo, marketInfo[address(this)].totalBetsOnYes);
       

        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        //  emit BuyEvent(msg.sender, _amount, _betOn);
    }


    function PriceCalculation(uint256 NoUsers, uint256 yesUsers) public pure returns(uint256 yesPrice, uint256 noPrice){
       
        yesPrice = ((yesUsers * 100)/(yesUsers + NoUsers));
        noPrice = ((NoUsers * 100)/(yesUsers + NoUsers));

        return(noPrice * 10000000000000000, yesPrice * 10000000000000000);
    } 



    function sellShare(uint256 _noOfShares,uint256 _shareOf, uint256 _onPrice) external {
        
        require(userInfo[address(this)][msg.sender].bet, "didnt bet!");
        require(_onPrice > 0, "amount must be greater than 0");
        require(_noOfShares <= userInfo[address(this)][msg.sender].noOfShares, "not enough shares.");
        require(_shareOf == userInfo[address(this)][msg.sender].betOn, "wrong bet.");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        // require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");
        

        userInfo[address(this)][msg.sender].setForSale = true;
        userInfo[address(this)][msg.sender].saleAmount +=  _noOfShares;
        userInfo[address(this)][msg.sender].onPrice = _onPrice;


        // emit SellEvent(msg.sender, outcomeIndex, _noOfShares, returnAmount);
    }

    function buyShare(uint256 _noOfShares,uint256 _shareOf, uint256 _onPrice, address _owner) external {
        
        require(userInfo[address(this)][msg.sender].bet, "didnt bet!");
        require(_noOfShares > 0 && _noOfShares <= userInfo[address(this)][msg.sender].saleAmount,
            "amount must be greater than 0");
        require(_shareOf == userInfo[address(this)][msg.sender].betOn, "wrong bet.");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        require(_onPrice == userInfo[address(this)][msg.sender].onPrice * _noOfShares, "wrong price!");
        require(_owner == userInfo[address(this)][_owner].owner,"You are not owner");

        userInfo[address(this)][msg.sender].buyed = true;
        userInfo[address(this)][msg.sender].betOn = _shareOf;
        userInfo[address(this)][msg.sender].buyAmount += _onPrice;

        userInfo[address(this)][_owner].saleAmount -=  _noOfShares;
        userInfo[address(this)][_owner].noOfShares -=  _noOfShares;

        bool success = usdcToken.transferFrom(msg.sender, _owner, _onPrice);
        require(success, "Transfer failed");

        // emit BuySold(msg.sender, outcomeIndex, _noOfShares, returnAmount);
    }

    function resolveMarket(uint256 winningIndex) external onlyOwner  {
        
        require(winningIndex == 0 || winningIndex == 1, " either bet yes or no.");
        require(block.timestamp >  marketInfo[address(this)].endTime, "Market has not ended");

        for (uint256 i = 0; i < totalUsers; i++) {
            
            if( userInfo[address(this)][eachUser[i]].betOn == winningIndex) {

                uint256 _rewardAmount = calculatePotentialReturn(userInfo[address(this)][eachUser[i]].noOfShares);
                userInfo[address(this)][eachUser[i]].rewardAmount = _rewardAmount;
                
                bool success = usdcToken.transferFrom(address(this),eachUser[i], _rewardAmount);
                require(success, "Transfer failed");
            }
        }
    }

    function calculateShares(uint256 _amount, uint256 _shareOf ) public view returns (uint256) {
        
        uint256 result;
       
        if(_shareOf == 0){
             result=  divide( _amount,  marketInfo[address(this)].initialPrice[_shareOf]);
        }else{
             result =  divide( _amount,  marketInfo[address(this)].initialPrice[_shareOf]);
        }
        return (result);
    }

    function divide(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        
        require(denominator != 0, "Denominator cannot be zero");
        uint256 result = (numerator * 100) / denominator;

        return result;
    }

    // Function to calculate potential return
    function calculatePotentialReturn(uint256 _shares) private pure returns (uint256) {
    
        uint256 potentialReturn = _shares * 1e18 ;
        return potentialReturn;
    }

    function calculateInvestment(uint256 shares, uint256 _shareOf) public view returns (uint256) {
        
        require(shares > 0, "Shares must be greater than zero");
        uint256 amountInCents = (shares * marketInfo[address(this)].initialPrice[_shareOf]) / 100;
        
        return amountInCents;
    }


}
