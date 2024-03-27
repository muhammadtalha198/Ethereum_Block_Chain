// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";


interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}
interface IPancakeRouter01 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract KGCStakingContract is Ownable {

    IBEP20 public kgcToken;
    IBEP20 public usdcToken;
    IPancakeRouter01 public pancakeRouter;

    uint256 private contractBalance;
    // address routeraddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; BNBTestNet : PancakeSwapV2

    uint256  public constant registrerationFee = 5 * 1e18;
    uint256 public constant minimumAmount = 10 * 1e18;
    uint256 public constant maximumAmount = 1000 * 1e18;
    uint256 public constant perdayPercentage = 40 ;  // 0.40%

    uint256 public constant minimumWithdrawlAmount= 10 * 1e18;
    uint256 public constant withdrawlDeductionPercentage = 500;  // 5%
    uint256 public constant directReferalPercentage = 1000; // 10%
    
    address usdcAddress;
    address kgcAddress;


    struct UserRegistered{
        bool registered;
        address ownerOf;
        uint256 noOfStakes;
        uint256 totalReward;
        uint256 referalRewards;
        uint256 withdrawedAmount;
        uint256 totalStakedAmount;

    }
    

    struct StakeInfo {
        bool staked;
        uint256 previousDays;
        uint256 stakeAmount;
        uint256 stakeEndTime;
        uint256 stakedRewards;
        uint256 stakeStartTime;
    }

    mapping(address => UserRegistered) public userRegistered;
    mapping(address => mapping (uint256 => StakeInfo)) public stakeInfo;

    
    event Withdraw(address indexed _userAddress, uint256 withdrawAmount );
    event KGCTransfer(address indexed _from, address indexed _to, uint256 _amount);
    event amountAdded(address indexed _sender, uint256 indexed _amount,uint256 contractBalance);
    event Register(address indexed regissteredUser, address indexed referalPerson, uint256 _fee);
    event Stake(address indexed _staker, uint256 indexed _stakeAmount, address indexed _directReferal, uint256 _directreferalBonus);
    
    
    constructor(address initialOwner, address _kgcToken, address _usdcToken, address _pancakeRouter) Ownable(initialOwner) {

        kgcToken = IBEP20(_kgcToken);
        usdcToken = IBEP20(_usdcToken);

        usdcAddress = _usdcToken;
        kgcAddress = _kgcToken;
        pancakeRouter = IPancakeRouter01(_pancakeRouter);

    }

    function registerUser(uint256 _fee, address referalAddress) external  {
        
        require(referalAddress != msg.sender && referalAddress != address(0), "invalid referal Address!");
        require (_fee == registrerationFee, "Invalid fee.");
        require(!userRegistered[msg.sender].registered, "You already registered!");

        userRegistered[msg.sender].registered = true;
        userRegistered[msg.sender].ownerOf = referalAddress;

        bool success = usdcToken.transferFrom(msg.sender, owner(), _fee);
        require(success, "Transfer failed");
        emit Register(msg.sender,referalAddress, _fee);

    }

   
    function stakeTokens(uint256 _amount) external  {

        require(_amount >= minimumAmount && _amount <= maximumAmount, "invalid amount!");
        // require(userRegistered[msg.sender].registered, "Plaese register!");
        require(userRegistered[msg.sender].noOfStakes <= 100,"Use different acccount for newStakes!");

        require(kgcToken.balanceOf(msg.sender) >= _amount,"insufficient Kgc balancce.");
        
        uint256 stakeId = userRegistered[msg.sender].noOfStakes;
        
        stakeInfo[msg.sender][stakeId].staked = true;
        stakeInfo[msg.sender][stakeId].stakeAmount = _amount;
        stakeInfo[msg.sender][stakeId].stakeStartTime = block.timestamp;
        stakeInfo[msg.sender][stakeId].stakeEndTime = block.timestamp + (60 minutes);
        userRegistered[msg.sender].totalStakedAmount = userRegistered[msg.sender].totalStakedAmount + (_amount);
        userRegistered[msg.sender].noOfStakes++;
        
            
       address _referalPerson = userRegistered[msg.sender].ownerOf;
        
        userRegistered[_referalPerson].referalRewards = userRegistered[_referalPerson].referalRewards + 
        (calculatePercentage(_amount, directReferalPercentage));
        userRegistered[_referalPerson].totalReward = userRegistered[_referalPerson].totalReward + 
        (calculatePercentage(_amount, directReferalPercentage));

        bool success = kgcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        emit Stake(msg.sender, _amount, _referalPerson, calculatePercentage(_amount, directReferalPercentage));
        
    }


   function withdrawAmount(uint256 _amount) external  {

        require(_amount != 0, "invalid Amount");
        require(userRegistered[msg.sender].registered, "Plaese register!");  

        require(_amount >= minimumWithdrawlAmount,"invalid Amount.");

        if(userRegistered[msg.sender].totalReward < _amount){

            if(userRegistered[msg.sender].noOfStakes > 0){

                uint256 totalStakeIds = userRegistered[msg.sender].noOfStakes;

                for(uint256 i=0; i<totalStakeIds; i++){ 
                
                    if(stakeInfo[msg.sender][i].previousDays < 60){
                
                        if(block.timestamp > stakeInfo[msg.sender][i].stakeEndTime){

                            uint256 previousDays = stakeInfo[msg.sender][i].previousDays;                           
                            uint256 rewardDays = 60 - previousDays;
                            
                            stakeInfo[msg.sender][i].previousDays = 60;
                            stakeRewardCalculation(rewardDays, msg.sender, i);
                        }
                        else{

                            uint256 totaldays = calculateTotalDays(stakeInfo[msg.sender][i].stakeStartTime, block.timestamp);
                                                       
                            if(totaldays > 0){

                                uint256 previousDays = stakeInfo[msg.sender][i].previousDays;
                                uint256 rewardDays= totaldays - (previousDays);

                                stakeInfo[msg.sender][i].previousDays = totaldays;
                               
                                if(rewardDays > 0){
                                    stakeRewardCalculation(rewardDays, msg.sender, i);
                                }
                                
                            }
                        }
                    }
                }
            }
        }

        
        require( userRegistered[msg.sender].totalReward >= _amount, "not enough reward Amount!");
        
        userRegistered[msg.sender].totalReward = userRegistered[msg.sender].totalReward - (_amount);      
        userRegistered[msg.sender].withdrawedAmount = userRegistered[msg.sender].withdrawedAmount + (_amount);
        
        uint256 deductedAmount = calculatePercentage( _amount,withdrawlDeductionPercentage);
        _amount = _amount - (deductedAmount);
        
        require(kgcToken.balanceOf(address(this)) >= _amount, "Admin need to topup the wallet!");
        
        bool success =  kgcToken.transfer(msg.sender, _amount);
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, _amount);
    }



    function stakeRewardCalculation(uint256 totaldays, address userAddress, uint256 stakeId) private  {
                            
            uint256 totalPercentage = perdayPercentage * (totaldays);
            uint256 totalReward = calculatePercentage(stakeInfo[userAddress][stakeId].stakeAmount, totalPercentage);

            userRegistered[userAddress].totalReward = userRegistered[userAddress].totalReward + (totalReward);

            stakeInfo[userAddress][stakeId].stakedRewards = stakeInfo[userAddress][stakeId].stakedRewards + (totalReward);
    }


    function sendKGC(address recipient, uint256 amount) external {
        
        require(amount != 0, "amount canot be zero.");
        require(recipient != address(0), "recipient address canot be zero.");
       
        bool succes = kgcToken.transferFrom(msg.sender, recipient, amount); 
        require(succes, "Transfer failed");
        
        emit KGCTransfer(msg.sender, recipient,amount);
    }

    function calculateTotalDays(uint256 _startTime, uint256 _endTime) private pure returns(uint256) {
        require(_endTime > _startTime, "End time must be greater than start time");

        uint256 timeDifference = _endTime - (_startTime);
        uint256 totalDays = (timeDifference / (1 minutes));

        return totalDays;
    }


    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        require(_totalStakeAmount !=0 , "_totalStakeAmount can not be zero");
        require(percentageNumber !=0 , "_totalStakeAmount can not be zero");
        uint256 serviceFee = _totalStakeAmount * (percentageNumber) / (10000);
        
        return serviceFee;
    }
    
    
    function getKGCAmount(uint256 _usdcAmount) public view returns(uint256){
        
        address[] memory pathTogetKGC = new address[](2);
        pathTogetKGC[0] = usdcAddress;
        pathTogetKGC[1] = kgcAddress;

        uint256[] memory _kgcAmount;
        _kgcAmount = pancakeRouter.getAmountsOut(_usdcAmount,pathTogetKGC);
        require(_kgcAmount.length > 0, "wrong value from excahnge!");
        
        return _kgcAmount[1];

    } 
    
    function getKGCPrice(uint256 _kgcAmount) public view  returns(uint256){
        
        address[] memory pathTogetKGCPrice = new address[](2);
        pathTogetKGCPrice[0] = kgcAddress;
        pathTogetKGCPrice[1] = usdcAddress;

        uint256[] memory _kgcPrice;
        _kgcPrice = pancakeRouter.getAmountsOut(_kgcAmount,pathTogetKGCPrice);
        require( _kgcPrice.length > 0, "wrong value from excahnge!");
        
        return _kgcPrice[1];
    }

    function topUpContarctWallet(uint256 _amount) external {
       
        require(_amount != 0, "amount canot be zero.");

        bool success = kgcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        emit amountAdded(msg.sender, _amount, kgcToken.balanceOf(address(this)));
    }

    function Contractbalance() external view returns (uint256 balance){
       return kgcToken.balanceOf(address(this));
    }


}

