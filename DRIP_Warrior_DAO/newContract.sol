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
    event BuyEvent(address indexed user,uint256 indexed outcomeIndex,uint256 amount);
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

    function BUY(uint256 _amount, uint256 _betOn) external {
       
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

        // emit BuyEvent(msg.sender, _amount);
    }


    function PriceCalculation(uint256 NoUsers, uint256 yesUsers) public pure returns(uint256 yesPrice, uint256 noPrice){
       
        yesPrice = ((yesUsers * 100)/(yesUsers + NoUsers));
        noPrice = ((NoUsers * 100)/(yesUsers + NoUsers));

        return(noPrice * 10000000000000000, yesPrice * 10000000000000000);
    } 



    function SELL(uint256 _noOfShares,uint256 _buyOf, uint256 _onPrice) external {
        
        require(userInfo[address(this)][msg.sender].bet, "didnt bet!");
        require(_onPrice > 0, "amount must be greater than 0");
        require(_noOfShares <= userInfo[address(this)][msg.sender].noOfShares, "not enough shares.");
        require(_buyOf == userInfo[address(this)][msg.sender].betOn, "wrong bet.");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        // require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");
        

        userInfo[address(this)][msg.sender].setForSale = true;
        userInfo[address(this)][msg.sender].saleAmount +=  _noOfShares;
        userInfo[address(this)][msg.sender].onPrice = _onPrice;


        // emit SellEvent(msg.sender, outcomeIndex, _noOfShares, returnAmount);
    }

    function buySold(uint256 _noOfShares,uint256 _buyOf, uint256 _onPrice, address _owner) external {
        
        require(userInfo[address(this)][msg.sender].bet, "didnt bet!");
        require(_noOfShares > 0 && _noOfShares <= userInfo[address(this)][msg.sender].saleAmount,
            "amount must be greater than 0");
        require(_buyOf == userInfo[address(this)][msg.sender].betOn, "wrong bet.");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        require(_onPrice == userInfo[address(this)][msg.sender].onPrice * _noOfShares, "wrong price!");
        require(_owner == userInfo[address(this)][_owner].owner,"You are not owner");

        userInfo[address(this)][msg.sender].buyed = true;
        userInfo[address(this)][msg.sender].betOn = _buyOf;
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

                uint256 _rewardAmount = calculatePotentialReturn(userInfo[address(this)][msg.sender].noOfShares);
                userInfo[address(this)][eachUser[i]].rewardAmount = _rewardAmount;
            }
        }
        
        // Emit the MarketResolved event
        // emit MarketResolved(winningOutcomeIndex);
    }

    function calculateShares(uint256 _amount, uint256 _buyOf ) public view returns (uint256) {
        
        uint256 result;
       
        if(_buyOf == 0){
             result=  divide( _amount,  marketInfo[address(this)].initialPrice[_buyOf]);
        }else{
             result =  divide( _amount,  marketInfo[address(this)].initialPrice[_buyOf]);
        }
        return (result);
    }

    function divide(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        
        require(denominator != 0, "Denominator cannot be zero");
        uint256 result = (numerator * 100) / denominator;

        return result;
    }

    // Function to calculate potential return
    function calculatePotentialReturn(uint256 _shares) private view returns (uint256) {
    
        uint256 potentialReturn = _shares * 1e18 ;
        return potentialReturn;
    }

    function calculateInvestment(uint256 shares, uint256 _buyOf) public view returns (uint256) {
        
        require(shares > 0, "Shares must be greater than zero");
        uint256 amountInCents = (shares * marketInfo[address(this)].initialPrice[_buyOf]) / 100;
        
        return amountInCents;
    }


    


//     function _userShareAmount(address _user, uint256 outcomeIndex)public view returns (uint256){

//         uint256 userSharePercentage = (userBalances[_user][outcomeIndex] *100) / outcomes[outcomeIndex].totalBets;

//            return userSharePercentage;
//     }

//     function withdrawWinnings() external {
        
//         uint256 outcomeIndex = result ;
        
//         require(state == MarketState.Resolved, "Market is not resolved");
//         require(outcomeIndex < outcomes.length, "Invalid outcome index");
//         require(userBalances[msg.sender][outcomeIndex] > 0,"You are not a winner");
         
//         if (outcomes[0].totalBets == 0 || outcomes[1].totalBets == 0 ) {
            
//             uint256 userShare = userBalances[msg.sender][outcomeIndex];
//             userBalances[msg.sender][outcomeIndex] = 0;

//             // Transfer the user's winnings
//             require(usdcToken.transfer(msg.sender, userShare), "Withdraw failed");

//         }else {
            
//             uint256 abc;
            
//             if(0 == outcomeIndex){

//                 admin = outcomes[1].totalBets * 10 / 100;
//                 abc = (outcomes[1].totalBets - admin ) * _userShareAmount(msg.sender, outcomeIndex) / 100;

//             }else if (1 == outcomeIndex){

//                 admin = outcomes[0].totalBets * 10 / 100;
//                 abc = (outcomes[0].totalBets - admin ) * _userShareAmount(msg.sender, outcomeIndex) / 100;
//             }

//             // Transfer the user's winnings
//             require(usdcToken.transfer(msg.sender, abc+userBalances[msg.sender][outcomeIndex]), "Withdraw failed");
        
//         }    
        
//         // Reset the user's balance for the outcome to prevent reentrant attacks
//         userBalances[msg.sender][outcomeIndex] = 0;
        
//         emit WithdrawWinner(outcomeIndex);
//     }

//     function getAdminAmount() external returns (uint256 adminAmount) {
    
//         uint256 outcomeIndex = result ;
    
//         require(state == MarketState.Resolved, "Market is not resolved");
//         require(outcomeIndex < outcomes.length, "Invalid outcome index");

//         // Calculate the admin amount based on the winning outcome
//         if (outcomeIndex == 0) {
           
//             adminAmount = outcomes[1].totalBets * 10 / 100;

//         } else if (outcomeIndex == 1) {
//             adminAmount = outcomes[0].totalBets * 10 / 100;

//         } else {
//             adminAmount = 0; // Invalid outcome index
//         }

//         // Transfer the admin amount to the admin
//         if (adminAmount > 0) {
//             require(usdcToken.transfer(owner(), adminAmount), "Admin transfer failed");
//         }
    
//     return adminAmount;
    
// }

//     function RemainingTokens() external onlyOwner {
        
//         uint256 remainingBalance = usdcToken.balanceOf(address(this));
        
//         require(remainingBalance >0, "No balance in the market");
        
//         // Transfer the remaining tokens to the owner
//         require(usdcToken.transfer(owner(), remainingBalance), "Transfer failed");
       
//         emit RemainingTransfer(owner(),remainingBalance );
//     }

//     function getTotalBetsCombined() external view returns (uint256) {
        
//         uint256 totalCombinedBets = 0;
        
//         for (uint256 i = 0; i < outcomes.length; i++) {
//             totalCombinedBets = totalCombinedBets + (outcomes[i].totalBets);
//         }
        
//         return totalCombinedBets;
//     }

//     function resultPercentage() external view returns (uint256 yesPercentage , uint256 noPercentage ) {
       
//         uint256 totalBets = outcomes[0].totalBets + outcomes[1].totalBets;  
        
//         if (totalBets == 0) {
//             return (0, 0);
//         }
        
//         yesPercentage = (outcomes[1].totalBets * 100) / totalBets;
//         noPercentage = (outcomes[0].totalBets * 100) / totalBets;
//     }

//     // Function to get information about a specific outcome
//     function getOutcomeInfo(uint256 index)external view returns (string memory description,uint256 totalBets,uint256 totalSharess){
        
//         require(index < outcomes.length, "Invalid outcome index");
//         OutcomeInfo memory outcome = outcomes[index];
        
//         return (outcome.description, outcome.totalBets, outcome.totalSharess);
//     }


}
