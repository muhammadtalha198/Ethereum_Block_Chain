// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";


contract Market is Ownable {

    ERC20 public usdcToken;

    struct MarketInfo {

        uint256 endTime;
        uint256 totalBets;
        uint256 totalAmount;
        uint256[2] initialPrice;
        uint256 totalBetsOnYes;
        uint256 totalBetsOnNo;
    }

    struct UserInfo{
        
        uint256 noOfBets;
        uint256 noBetAmount;
        uint256 yesBetAmount;
        uint256 rewardAmount;
    }

    struct BetInfo{
        bool bet;
        bool buyed;
        bool setForSale;
        address owner; 
        uint256 betOn;
        uint256 onPrice;
        uint256 betAmount;
        uint256 buyAmount;
        uint256 saleAmount;
        uint256 noOfShares; 
    }

    uint256 public totalUsers;

    mapping(uint256 => address) public eachUser;
    mapping(address => UserInfo) public userInfo;
    mapping(address => MarketInfo) public marketInfo;
    mapping(address => mapping(uint256 => BetInfo)) public betInfo;
    

   
    event WithdrawWinner (uint256 indexed outcomeIndex);
    event MarketResolved(uint256 indexed winningOutcomeIndex);
    event RemainingTransfer(address owner,uint256 remainingBalance);
    event Bet(address indexed user,uint256 indexed _amount,uint256 _betOn);
    event SellShare(address indexed user, uint256 noOfShares, uint256 ofBet, uint256 onPrice);
    event BuyShare(address buyer, address seller, uint256 _noOfShares, uint256 ofBet, uint256 onPrice);


    constructor(
        address initialOwner,
        address _usdcToken,
        uint256 _endTime ) 

        Ownable(initialOwner) {

            marketInfo[address(this)].endTime = _endTime;
            marketInfo[address(this)].initialPrice[0] = 500000000000000000;
            marketInfo[address(this)].initialPrice[1] = 500000000000000000;
            usdcToken = ERC20(_usdcToken);
            


    }

    function bet(uint256 _amount, uint256 _betOn) external {
       
        require(_betOn == 0 || _betOn == 1, "you either bet yes or no.");
        require(_amount > 0, "Bet amount must be greater than 0");
        require(block.timestamp < marketInfo[address(this)].endTime, "Market is closed.");
        

        if(userInfo[msg.sender].noOfBets != 0){     
            
            eachUser[totalUsers] = msg.sender;
            totalUsers++;
        }
        
        uint256 _noOfShares;


        if(_betOn == 0 ){

            marketInfo[address(this)].totalBetsOnNo++;
            userInfo[msg.sender].noBetAmount += _amount;
            // _noOfShares = calculateShares(userInfo[msg.sender].noBetAmount, _betOn);

        }else {

            marketInfo[address(this)].totalBetsOnYes++;  
            userInfo[msg.sender].yesBetAmount += _amount;
            // _noOfShares = calculateShares(userInfo[msg.sender].yesBetAmount, _betOn);
        }


        marketInfo[address(this)].totalAmount += _amount;

        
        
        betInfo[msg.sender][userInfo[msg.sender].noOfBets].bet = true;
        betInfo[msg.sender][userInfo[msg.sender].noOfBets].betOn = _betOn;
        betInfo[msg.sender][userInfo[msg.sender].noOfBets].owner = msg.sender;
        betInfo[msg.sender][userInfo[msg.sender].noOfBets].betAmount = _amount;
        betInfo[msg.sender][userInfo[msg.sender].noOfBets].betOn = _betOn;
        betInfo[msg.sender][userInfo[msg.sender].noOfBets].betOn = _betOn;
        
        if 
        

        console.log("_noOfShares: ", _noOfShares);

        userInfo[msg.sender].noOfShares = _noOfShares;
        userInfo[msg.sender].owner = msg.sender;

        userInfo[msg.sender].noOfBets++;


        (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = 
            PriceCalculation(marketInfo[address(this)].totalBetsOnNo, marketInfo[address(this)].totalBetsOnYes);

            console.log("NoPrice: ",marketInfo[address(this)].initialPrice[0]);
            console.log("YesPrice: ",marketInfo[address(this)].initialPrice[1]);
       
        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

         emit Bet(msg.sender, _amount, _betOn);
    }


    function PriceCalculation(uint256 NoUsers, uint256 yesUsers) public view returns(uint256, uint256){
        
         uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
         uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];

        if(NoUsers != 0){
            
            originalNoPrice = ((NoUsers * 100)/(yesUsers + NoUsers));
            originalNoPrice *= 10000000000000000;
        }
        if(yesUsers != 0){
           
            originalYesPrice = ((yesUsers * 100)/(yesUsers + NoUsers));
            originalYesPrice *= 10000000000000000;
        }

        return(originalNoPrice, originalYesPrice);
    } 



    function sellShare(uint256 _noOfShares,uint256 _shareOf, uint256 _onPrice) external {
        
        require(userInfo[msg.sender].bet, "didnt bet!");
        require(_onPrice > 0, "amount must be greater than 0");
        require(_noOfShares <= userInfo[msg.sender].noOfShares, "not enough shares.");
        require(_shareOf == userInfo[msg.sender].betOn, "wrong bet.");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        // require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");
        

        userInfo[msg.sender].setForSale = true;
        userInfo[msg.sender].saleAmount +=  _noOfShares;
        userInfo[msg.sender].onPrice = _onPrice;


        emit SellShare(msg.sender, _noOfShares, _noOfShares, _onPrice);
    }

    function buyShare(uint256 _noOfShares,uint256 _shareOf, uint256 _onPrice, address _owner) external {
        
        require(userInfo[msg.sender].bet, "didnt bet!");
        require(_noOfShares > 0 && _noOfShares <= userInfo[msg.sender].saleAmount,
            "amount must be greater than 0");
        require(_shareOf == userInfo[msg.sender].betOn, "wrong bet.");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        require(_onPrice == userInfo[msg.sender].onPrice * _noOfShares, "wrong price!");
        require(_owner == userInfo[address(this)][_owner].owner,"You are not owner");

        userInfo[msg.sender].buyed = true;
        userInfo[msg.sender].betOn = _shareOf;
        userInfo[msg.sender].buyAmount += _onPrice;

        userInfo[address(this)][_owner].saleAmount -=  _noOfShares;
        userInfo[address(this)][_owner].noOfShares -=  _noOfShares;

        bool success = usdcToken.transferFrom(msg.sender, _owner, _onPrice);
        require(success, "Transfer failed");

        emit BuyShare(msg.sender,_owner, _noOfShares, _shareOf, _onPrice);
    }

    function resolveMarket(uint256 winningIndex) external   {
        
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

    function calculateShares(uint256 _amount, uint256 _betOn ) public view returns (uint256) {
        
        uint256 result;
       
        if(_betOn == 0){
             result=  divide( _amount,  marketInfo[address(this)].initialPrice[_betOn]);
        }else{
             result =  divide( _amount,  marketInfo[address(this)].initialPrice[_betOn]);
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

    function calculateInvestment(uint256 shares, uint256 _betOn) public view returns (uint256) {
        
        require(shares > 0, "Shares must be greater than zero");
        uint256 amountInCents = (shares * marketInfo[address(this)].initialPrice[_betOn]) / 100;
        
        return amountInCents;
    }

    function getInitialPrices() public view returns (uint256, uint256) {
        return (marketInfo[address(this)].initialPrice[0], marketInfo[address(this)].initialPrice[1]);
    }


}
