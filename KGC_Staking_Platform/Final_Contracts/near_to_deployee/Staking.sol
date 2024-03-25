// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";


interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}
interface IPancakeRouter01 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract MyContract is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    
    IBEP20 public kgcToken;
    IBEP20 public usdcToken;
    IPancakeRouter01 public pancakeRouter;  
    // address routeraddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; BNBTestNet : PancakeSwapV2

    using SafeMathUpgradeable for uint256;

    uint256 public registrerationFee;
    uint256 public minimumAmount;
    uint256 public maximumAmount;
    uint256 public perdayPercentage;

    uint256 public minimumWithdrawlAmount;
    uint256 public withdrawlDeductionPercentage;
    uint256 public directReferalPercentage;
    address usdcAddress;
    address kgcAddress;


    struct UserRegistered{
        bool hasReferal;
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

    
    event Withdraw(address _userAddress, uint256 withdrawAmount );
    event Register(address regissteredUser, address referalPerson, uint256 _fee);
    event KGCTransfer(address _from, address _to, uint256 _amount);
    event Stake(address _staker, uint256 _stakeAmount, address _directReferal, uint256 _directreferalBonus);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _kgcToken, address _usdcToken, address _pancakeRouter) initializer external {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        kgcToken = IBEP20(_kgcToken);
        usdcToken = IBEP20(_usdcToken);
        registrerationFee = 5 * 1e18;
        minimumAmount = 50 * 1e18;
        maximumAmount = 5000 * 1e18;
        directReferalPercentage = 1000; // 10%
        minimumWithdrawlAmount = 10 * 1e18;
        withdrawlDeductionPercentage = 500;  // 5%
        perdayPercentage = 40 ;  // 0.40%
        usdcAddress = _usdcToken;
        kgcAddress = _kgcToken;
        pancakeRouter = IPancakeRouter01(_pancakeRouter);

    }
    
    function registerUser(uint256 _fee, address referalAddress) external whenNotPaused {
        
        require(referalAddress != msg.sender && referalAddress != address(0), "invalid referal Address!");
        require (_fee >= registrerationFee, "Invalid fee.");
        require(!userRegistered[msg.sender].registered, "You already registered!");

        userRegistered[msg.sender].hasReferal = true;
        userRegistered[msg.sender].registered = true;
        userRegistered[msg.sender].ownerOf = referalAddress;

        bool success = usdcToken.transferFrom(msg.sender, owner(), _fee);
        require(success, "Transfer failed");
        emit Register(msg.sender,referalAddress, _fee);

    }

   
    function stakeTokens(uint256 _amount) external whenNotPaused {

        require(_amount >= minimumAmount && _amount <= maximumAmount, "invalid amount!");
        require(userRegistered[msg.sender].registered, "Plaese register!");
        require(userRegistered[msg.sender].noOfStakes <= 100,"Use different acccount for newStakes!");

        uint256 kgcTokenAmount = getKGCAmount(_amount);
        

        require(kgcTokenAmount > 0,"Kgc amounyt canot be zero");
        require(kgcToken.balanceOf(msg.sender) >= kgcTokenAmount,"insufficient Kgc balancce.");
        
        uint256 stakeId = userRegistered[msg.sender].noOfStakes;
        
        stakeInfo[msg.sender][stakeId].staked = true;
        stakeInfo[msg.sender][stakeId].stakeAmount = kgcTokenAmount;
        stakeInfo[msg.sender][stakeId].stakeStartTime = block.timestamp;
        stakeInfo[msg.sender][stakeId].stakeEndTime = block.timestamp.add(500 days);
        userRegistered[msg.sender].totalStakedAmount = userRegistered[msg.sender].totalStakedAmount.add(kgcTokenAmount);
        userRegistered[msg.sender].noOfStakes++;

        address _referalPerson;
        
        if(userRegistered[msg.sender].hasReferal){
            _referalPerson = userRegistered[msg.sender].ownerOf;
            userRegistered[_referalPerson].referalRewards =userRegistered[_referalPerson].referalRewards.add
            (calculatePercentage(kgcTokenAmount, directReferalPercentage));
            userRegistered[_referalPerson].totalReward = userRegistered[_referalPerson].totalReward.add
            (userRegistered[_referalPerson].referalRewards);
        }

        bool success = kgcToken.transferFrom(msg.sender, owner(), kgcTokenAmount);
        require(success, "Transfer failed");

        emit Stake(msg.sender, kgcTokenAmount, _referalPerson, calculatePercentage(kgcTokenAmount, directReferalPercentage));
        
    }


   function WithdrawAmount(uint256 _amount) external whenNotPaused {

        require(_amount != 0, "invalid Amount");  
        
        uint256 minimumWithdrawl = getKGCAmount( minimumWithdrawlAmount);

        require(_amount >= minimumWithdrawl,"invalid Amount.");

        if(userRegistered[msg.sender].totalReward < _amount){

            if(userRegistered[msg.sender].noOfStakes > 0){

                uint256 totalStakeIds = userRegistered[msg.sender].noOfStakes;

                for(uint256 i=0; i<totalStakeIds; i++){ 
                
                    if(stakeInfo[msg.sender][i].previousDays < 500){
                
                        if(block.timestamp > stakeInfo[msg.sender][i].stakeEndTime){

                            uint256 previousDays = stakeInfo[msg.sender][i].previousDays;                           
                            uint256 rewardDays = 500 - previousDays;
                            
                            stakeInfo[msg.sender][i].previousDays = 500;
                            StakeRewardCalculation(rewardDays, msg.sender, i);
                        }
                        else{

                            uint256 totaldays = calculateTotalDays(stakeInfo[msg.sender][i].stakeStartTime, block.timestamp);
                                                       
                            if(totaldays > 0){

                                uint256 previousDays = stakeInfo[msg.sender][i].previousDays;
                                uint256 rewardDays= totaldays.sub(previousDays);

                                stakeInfo[msg.sender][i].previousDays = totaldays;
                               
                                if(rewardDays > 0){
                                    StakeRewardCalculation(rewardDays, msg.sender, i);
                                }
                                
                            }
                        }
                    }
                }
            }
        }

        
        require( userRegistered[msg.sender].totalReward >= _amount, "not enough reward Amount!");
        
        userRegistered[msg.sender].totalReward = userRegistered[msg.sender].totalReward.sub(_amount);      
        userRegistered[msg.sender].withdrawedAmount = userRegistered[msg.sender].withdrawedAmount.add(_amount);
        
        uint256 deductedAmount = calculatePercentage( _amount,withdrawlDeductionPercentage);
        _amount = _amount.sub( deductedAmount);
        
        require(kgcToken.balanceOf(owner()) >= _amount, "Admin need to topup the wallet!");
        
        bool success =  kgcToken.transferFrom(owner(),msg.sender, _amount); 
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, _amount);
    }



    function StakeRewardCalculation(uint256 totaldays, address userAddress, uint256 stakeId) private  {
                            
            uint256 totalPercentage = perdayPercentage.mul(totaldays);
            uint256 totalReward = calculatePercentage(stakeInfo[userAddress][stakeId].stakeAmount, totalPercentage);

            userRegistered[userAddress].totalReward = userRegistered[userAddress].totalReward.add(totalReward);

            stakeInfo[userAddress][stakeId].stakedRewards = stakeInfo[userAddress][stakeId].stakedRewards.add(totalReward);
    }


    function SendKGC(address recipient, uint256 amount) external {
        
        require(amount != 0, "amount canot be zero.");
        require(recipient != address(0), "recipient address canot be zero.");
        
        uint256 sendOnePercent = calculatePercentage(amount, 100);
        uint256 remainingAmount = amount.sub(sendOnePercent);

        bool success =  kgcToken.transferFrom(msg.sender, owner(), sendOnePercent); 
        require(success, "Transfer failed");
       
        bool succes = kgcToken.transferFrom(msg.sender, recipient, remainingAmount); 
        require(succes, "Transfer failed");
        emit KGCTransfer(msg.sender, recipient,amount);
    }

    function calculateTotalDays(uint256 _startTime, uint256 _endTime) private pure returns(uint256) {
        require(_endTime > _startTime, "End time must be greater than start time");

        uint256 timeDifference = _endTime.sub(_startTime);
        uint256 totalDays = (timeDifference.div(1 days));

        return totalDays;
    }


    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        require(_totalStakeAmount !=0 , "_totalStakeAmount can not be zero");
        require(percentageNumber !=0 , "_totalStakeAmount can not be zero");
        uint256 serviceFee = _totalStakeAmount.mul(percentageNumber).div(10000);
        
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


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}


