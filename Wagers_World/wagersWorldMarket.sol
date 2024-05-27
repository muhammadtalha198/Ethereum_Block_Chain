// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

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
        uint256[2] YesOrNo;
        uint256 totalAmount;
    }

    struct UserInfo{
        bool bet;
        uint256 beton;
        uint256 betAmount;
    }

    uint256 public noOfTotalUsers;

    mapping(uint256 =>address) public eachUser;
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
            usdcToken = IERC20(_usdcToken);


    }

    function BUY(uint256 _amount, uint256 _betOn) external {
       
        require(_betOn == 0 || _betOn == 1, "you either bet yes or no.");
        require(_amount > 0, "Bet amount must be greater than 0");
        require(marketInfo[address(this)].marketOpen, "Market is not open");
        require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");

        userInfo[address(this)][msg.sender].bet = true;
        userInfo[address(this)][msg.sender].betOn = _betOn;
        userInfo[address(this)][msg.sender].betAmount = _amount;
       
        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        emit BuyEvent(msg.sender, _amount);
    }

    function SELL(uint256 outcomeIndex, uint256 _amount) external {
        
        require(state == MarketState.Open, "Market is not open");
        require(outcomeIndex < outcomes.length, "Invalid outcome index");
        require(block.timestamp < endTime, "Market has ended");
        require(_amount > 0, "Sell amount must be greater than 0");
        
        require(userBalances[msg.sender][outcomeIndex] >= _amount,"Insufficient balance");

        // Calculate the amount to return to the user based on their share of the outcome
        uint256 returnAmount = (_amount * outcomes[outcomeIndex].totalBets) / outcomes[outcomeIndex].totalSharess;

        // Update user balance and total bets for the outcome
        userBalances[msg.sender][outcomeIndex] -=  _amount;
        outcomes[outcomeIndex].totalBets -= _amount;
        outcomes[outcomeIndex].totalSharess -= returnAmount;

        require(usdcToken.transfer(msg.sender, returnAmount));

        emit SellEvent(msg.sender, outcomeIndex, _amount, returnAmount);
    }

     // Function to resolve the market and determine the winning outcome
    function resolveMarket(uint256 winningOutcomeIndex) external onlyOwner {
        
        require(state == MarketState.Open, "Market is not open");
        require(block.timestamp > endTime, "Market has not ended");
        require(winningOutcomeIndex < outcomes.length, "Invalid outcome index");

        // Update the state of the market to Resolved
        state = MarketState.Resolved;
        result = winningOutcomeIndex;

        // Emit the MarketResolved event
        emit MarketResolved(winningOutcomeIndex);
    }

    function _userShareAmount(address _user, uint256 outcomeIndex)public view returns (uint256){

        uint256 userSharePercentage = (userBalances[_user][outcomeIndex] *100) / outcomes[outcomeIndex].totalBets;

           return userSharePercentage;
    }

    function withdrawWinnings() external {
        
        uint256 outcomeIndex = result ;
        
        require(state == MarketState.Resolved, "Market is not resolved");
        require(outcomeIndex < outcomes.length, "Invalid outcome index");
        require(userBalances[msg.sender][outcomeIndex] > 0,"You are not a winner");
         
        if (outcomes[0].totalBets == 0 || outcomes[1].totalBets == 0 ) {
            
            uint256 userShare = userBalances[msg.sender][outcomeIndex];
            userBalances[msg.sender][outcomeIndex] = 0;

            // Transfer the user's winnings
            require(usdcToken.transfer(msg.sender, userShare), "Withdraw failed");

        }else {
            
            uint256 abc;
            
            if(0 == outcomeIndex){

                admin = outcomes[1].totalBets * 10 / 100;
                abc = (outcomes[1].totalBets - admin ) * _userShareAmount(msg.sender, outcomeIndex) / 100;

            }else if (1 == outcomeIndex){

                admin = outcomes[0].totalBets * 10 / 100;
                abc = (outcomes[0].totalBets - admin ) * _userShareAmount(msg.sender, outcomeIndex) / 100;
            }

            // Transfer the user's winnings
            require(usdcToken.transfer(msg.sender, abc+userBalances[msg.sender][outcomeIndex]), "Withdraw failed");
        
        }    
        
        // Reset the user's balance for the outcome to prevent reentrant attacks
        userBalances[msg.sender][outcomeIndex] = 0;
        
        emit WithdrawWinner(outcomeIndex);
    }

    function getAdminAmount() external returns (uint256 adminAmount) {
    
        uint256 outcomeIndex = result ;
    
        require(state == MarketState.Resolved, "Market is not resolved");
        require(outcomeIndex < outcomes.length, "Invalid outcome index");

        // Calculate the admin amount based on the winning outcome
        if (outcomeIndex == 0) {
           
            adminAmount = outcomes[1].totalBets * 10 / 100;

        } else if (outcomeIndex == 1) {
            adminAmount = outcomes[0].totalBets * 10 / 100;

        } else {
            adminAmount = 0; // Invalid outcome index
        }

        // Transfer the admin amount to the admin
        if (adminAmount > 0) {
            require(usdcToken.transfer(owner(), adminAmount), "Admin transfer failed");
        }
    
    return adminAmount;
    
}

    function RemainingTokens() external onlyOwner {
        
        uint256 remainingBalance = usdcToken.balanceOf(address(this));
        
        require(remainingBalance >0, "No balance in the market");
        
        // Transfer the remaining tokens to the owner
        require(usdcToken.transfer(owner(), remainingBalance), "Transfer failed");
       
        emit RemainingTransfer(owner(),remainingBalance );
    }

    function getTotalBetsCombined() external view returns (uint256) {
        
        uint256 totalCombinedBets = 0;
        
        for (uint256 i = 0; i < outcomes.length; i++) {
            totalCombinedBets = totalCombinedBets + (outcomes[i].totalBets);
        }
        
        return totalCombinedBets;
    }

    function resultPercentage() external view returns (uint256 yesPercentage , uint256 noPercentage ) {
       
        uint256 totalBets = outcomes[0].totalBets + outcomes[1].totalBets;  
        
        if (totalBets == 0) {
            return (0, 0);
        }
        
        yesPercentage = (outcomes[1].totalBets * 100) / totalBets;
        noPercentage = (outcomes[0].totalBets * 100) / totalBets;
    }

    // Function to get information about a specific outcome
    function getOutcomeInfo(uint256 index)external view returns (string memory description,uint256 totalBets,uint256 totalSharess){
        
        require(index < outcomes.length, "Invalid outcome index");
        OutcomeInfo memory outcome = outcomes[index];
        
        return (outcome.description, outcome.totalBets, outcome.totalSharess);
    }


}
