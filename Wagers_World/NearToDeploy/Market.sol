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

        address owner; 
        uint256 listNo;
        uint256 noBetAmount;
        uint256 rewardAmount;
        uint256 yesBetAmount;
        mapping(uint256 => bool) betOn;
    }

    struct SellInfo{
        bool list;
        bool sold;
        address owner;
        uint256 price;
        uint256 amount;
        mapping(uint256 => bool) sellOn;
    }

    uint256 public totalUsers;

    mapping(uint256 => address) public eachUser;
    mapping(address => UserInfo) public userInfo;
    mapping(address => MarketInfo) public marketInfo;
    mapping(address => mapping(uint256 => SellInfo)) public sellInfo;
    

   
    event WithdrawWinner (uint256 indexed outcomeIndex);
    event MarketResolved(uint256 indexed winningOutcomeIndex);
    event RemainingTransfer(address owner,uint256 remainingBalance);
    event Bet(address indexed user,uint256 indexed _amount,uint256 _betOn);
    event SellShare(address indexed user, uint256 listNo,  uint256 onPrice);
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
        

        if(!userInfo[msg.sender].betOn[_betOn] && !userInfo[msg.sender].betOn[_betOn]){     
            eachUser[totalUsers] = msg.sender;
            totalUsers++;
        }

        if(_betOn == 0 ){

            marketInfo[address(this)].totalBetsOnNo++;
            userInfo[msg.sender].noBetAmount += _amount;

        }else {

            marketInfo[address(this)].totalBetsOnYes++;  
            userInfo[msg.sender].yesBetAmount += _amount;
        }

        marketInfo[address(this)].totalAmount += _amount;
        userInfo[msg.sender].betOn[_betOn] = true;


        (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = 
            PriceCalculation(marketInfo[address(this)].totalBetsOnNo, marketInfo[address(this)].totalBetsOnYes);

            console.log("NoPrice: ",marketInfo[address(this)].initialPrice[0]);
            console.log("YesPrice: ",marketInfo[address(this)].initialPrice[1]);
       
        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        emit Bet(msg.sender, _amount, _betOn);
    }


    function PriceCalculation(uint256 totalBetsOnNo, uint256 totalBetsOnYes) public view returns(uint256, uint256){
        
         uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
         uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];
         
         uint256 totalBets = totalBetsOnNo + totalBetsOnYes;

        if(totalBetsOnNo != 0){
            
            originalNoPrice = ((totalBetsOnNo * 100)/(totalBets));
            originalNoPrice *= 10000000000000000;
        }
        if(totalBetsOnYes != 0){
           
            originalYesPrice = ((totalBetsOnYes * 100)/(totalBets));
            originalYesPrice *= 10000000000000000;
        }

        return(originalNoPrice, originalYesPrice);
    } 



    function sellShare(uint256 _amount, uint256 _price, uint256 _sellOf) external {
        
        require(userInfo[msg.sender].betOn[_sellOf], "wrong user.");
        require(_price > 0, "price must be greater than 0");
        require(_amount > 0, "amount must be greater than 0");
        require(_sellOf == 0 || _sellOf == 1, "you either list yes or no.");
        require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");
        
        userInfo[msg.sender].listNo++;

        sellInfo[msg.sender][userInfo[msg.sender].listNo].list = true;
        sellInfo[msg.sender][userInfo[msg.sender].listNo].price = _price; 

        if(_sellOf == 0){
            sellInfo[msg.sender][userInfo[msg.sender].listNo].sellOn[_sellOf] = true;
        } else {
            sellInfo[msg.sender][userInfo[msg.sender].listNo].onYes = true;
        }
    
        emit SellShare(msg.sender, userInfo[msg.sender].listNo, _price);
    }

    function buyShare(uint256 _listNo, address _owner) external {
        
        require(sellInfo[_owner][_listNo].list, "Not listeed!");


        // userInfo[msg.sender].buyed = true;
        // userInfo[msg.sender].betOn = _shareOf;
        // userInfo[msg.sender].buyAmount += _onPrice;

        // userInfo[address(this)][_owner].saleAmount -=  _noOfShares;
        // userInfo[address(this)][_owner].noOfShares -=  _noOfShares;

        // bool success = usdcToken.transferFrom(msg.sender, _owner, _onPrice);
        // require(success, "Transfer failed");

        // emit BuyShare(msg.sender,_owner, _noOfShares, _shareOf, _onPrice);
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

        uint256 price =  marketInfo[address(this)].initialPrice[_betOn];
        
        require(price != 0, "_price cannot be zero");
        uint256 result = (_amount * 100) / price;
        
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
