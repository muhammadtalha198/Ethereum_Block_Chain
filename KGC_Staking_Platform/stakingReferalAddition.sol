// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "hardhat/console.sol";


interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}
interface IPancakeRouter01 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

 /*
     level 1 =        50 %
     level 2 =        10  %    
     level 3 to 5 =    5 %
     level 6 to 10 =   3 %
     level 11 to 30 =  2 %
     level 31 to 50  = 1 %
    
    */

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
    uint256[] public rewardLevelPercentages;
    address usdcAddress;
    address kgcAddress;


    struct UserRegistered{
        bool hasReferal;
        bool registered;
        address ownerOf;
        uint256 noOfStakes;
        uint256 totalReward;
        uint256 referalRewards;
    }
    
    struct OwnerInfo{
        uint256[] levelNo;
        address[] ownerIs;
        uint256[] deducteAmount;
    }

    struct StakeInfo {
        bool staked;
        uint256 rewardDays;
        uint256 stakeAmount;
        uint256 stakeEndTime;
        uint256 stakedRewards;
        uint256 stakeStartTime;
    }

    // struct ReferalInfo{
    //     uint256 previousRewardDays;
    //     uint256 withdrawlTime;
    // }
   
   
    mapping(address  => OwnerInfo) ownerInfo;
    mapping(address => UserRegistered) public userRegistered;
    mapping(address => mapping (uint256 => StakeInfo)) public stakeInfo;
    mapping(address => mapping (address => mapping(uint256 => uint256))) public referalInfo;

    
    event Withdraw(address _userAddress, uint256 withdrawAmount );
    event Register(address regissteredUser, address referalPerson, uint256 _fee);
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
        minimumAmount = 2 * 1e18;
        maximumAmount = 50 * 1e18;
        directReferalPercentage = 1000; // 10%
        minimumWithdrawlAmount = /*10 * 1e18*/ 300000000000000;
        withdrawlDeductionPercentage = 500;  // 5%
        perdayPercentage = 40 ;  // 0.40%
        usdcAddress = _usdcToken;
        kgcAddress = _kgcToken;
        pancakeRouter = IPancakeRouter01(_pancakeRouter);

        // setRewardPercentages();
    }
    
    function registerUser(uint256 _fee, address referalAddress) external {
        
        require(referalAddress != msg.sender && referalAddress != address(0), "invalid referal Address!");
        require (_fee >= registrerationFee, "Invalid fee.");
        require(!userRegistered[msg.sender].registered, "You already registered!");

        userRegistered[msg.sender].hasReferal = true;
        userRegistered[msg.sender].registered = true;
        userRegistered[msg.sender].ownerOf = referalAddress;


        if (userRegistered[msg.sender].hasReferal) {
            
            if(!userRegistered[referalAddress].hasReferal){
                ownerInfo[referalAddress].levelNo.push(1);
                ownerInfo[referalAddress].ownerIs.push(msg.sender);
            }
            else{
                    _updateChainOfOwnership(msg.sender,referalAddress,1);
            }
        
        }

         usdcToken.transferFrom(msg.sender, address(this), _fee);
         emit Register(msg.sender,referalAddress, _fee);

    }

    // Internal function to update the chain of ownership recursively
    function _updateChainOfOwnership(address originalOwner, address _referalAddress,uint256 level) private {
       
        ownerInfo[_referalAddress].ownerIs.push(originalOwner);  
        ownerInfo[_referalAddress].levelNo.push(level);
        address previousReferal = userRegistered[_referalAddress].ownerOf;
        if (previousReferal != address(0)) {
            _updateChainOfOwnership(originalOwner, previousReferal, level + 1);
        
        }
    }

    // Getter function to retrieve level numbers and owners for a given address
    function getOwnInfo(address _owner) external view returns (uint256[] memory, address[] memory) {
        return (ownerInfo[_owner].levelNo, ownerInfo[_owner].ownerIs);
    }

   
    function stakeTokens(uint256 _amount) external  {

        
        require(_amount >= minimumAmount && _amount <= maximumAmount, "invalid amount!");
        require(userRegistered[msg.sender].registered, "Plaese register!");

        // uint256 kgcTokenAmount = getKGCAmount(_amount);
        uint256 kgcTokenAmount = _amount;

        require(kgcTokenAmount > 0,"Kgc amounyt canot be zero");
        require(kgcToken.balanceOf(msg.sender) >= kgcTokenAmount,"insufficient Kgc balancce.");
        
        uint256 stakeId = userRegistered[msg.sender].noOfStakes;
        console.log("stakeId: ", stakeId);
        

        
        stakeInfo[msg.sender][stakeId].staked = true;
        stakeInfo[msg.sender][stakeId].stakeAmount = kgcTokenAmount;
        stakeInfo[msg.sender][stakeId].stakeStartTime = block.timestamp;
        stakeInfo[msg.sender][stakeId].stakeEndTime = block.timestamp + 20 minutes;
        userRegistered[msg.sender].noOfStakes++;

        address _referalPerson;
        
        if(userRegistered[msg.sender].hasReferal){
            _referalPerson = userRegistered[msg.sender].ownerOf;
            userRegistered[_referalPerson].referalRewards += calculatePercentage(kgcTokenAmount, directReferalPercentage);
            userRegistered[_referalPerson].totalReward += userRegistered[_referalPerson].referalRewards;
        }

        kgcToken.transferFrom(msg.sender, address(this), kgcTokenAmount);

        emit Stake(msg.sender, kgcTokenAmount, _referalPerson, calculatePercentage(kgcTokenAmount, directReferalPercentage));
        
    }


   function WithdrawAmount(uint256 _amount) external  {

        require(_amount != 0, "invalid Amount1");
        
        uint256 minimumWithdrawl = getKGCAmount( minimumWithdrawlAmount);
        _amount = getKGCAmount( _amount);

        require(_amount >= minimumWithdrawl,"invalid Amount.");

        if(userRegistered[msg.sender].noOfStakes > 0){


            uint256 totalStakeIds = userRegistered[msg.sender].noOfStakes;

            if(userRegistered[msg.sender].totalReward < _amount){
        
                for(uint256 i=0; i<totalStakeIds; i++){

                    uint256 stakeId = i;
                    
                    if(stakeInfo[msg.sender][stakeId].rewardDays < 20){

                        if(block.timestamp > stakeInfo[msg.sender][stakeId].stakeEndTime){

                            uint256 totaldays = 20 - stakeInfo[msg.sender][stakeId].rewardDays;
                            stakeInfo[msg.sender][stakeId].rewardDays += totaldays;
                            
                            uint256 totalPercentage = perdayPercentage.mul(totaldays);
                            uint256 totalReward = calculatePercentage(stakeInfo[msg.sender][stakeId].stakeAmount, totalPercentage);
                            
                            userRegistered[msg.sender].totalReward += totalReward;
                        }
                        else{

                            uint256 totaldays = calculateTotalMinutes(stakeInfo[msg.sender][stakeId].stakeStartTime, block.timestamp);
                            stakeInfo[msg.sender][stakeId].rewardDays += totaldays;
                            
                            require(totaldays > 0,"please wait for atlseat day!");
                            
                            uint256 totalPercentage = perdayPercentage.mul(totaldays);
                            uint256 totalReward = calculatePercentage(stakeInfo[msg.sender][stakeId].stakeAmount, totalPercentage);
                            
                            userRegistered[msg.sender].totalReward += totalReward;
                            stakeInfo[msg.sender][stakeId].stakeStartTime = block.timestamp;
                        }
                    }
                }
            }
        }
        
        
        require( userRegistered[msg.sender].totalReward >= _amount, "not enough reward Amount!");
        
        userRegistered[msg.sender].totalReward -= _amount;
        
        uint256 deductedAmount = calculatePercentage( _amount,withdrawlDeductionPercentage);
        _amount -= deductedAmount;
        
        require(kgcToken.balanceOf(address(this)) >= _amount, "Admin need to topup the wallet!");
        
        kgcToken.transfer(msg.sender, _amount);
        
        emit Withdraw(msg.sender, _amount);
    }

    
    
    
    function WithdrawReferal(uint256 _amount) external  {

        require(_amount != 0, "invalid Amount1");
        
        uint256 minimumWithdrawl = getKGCAmount( minimumWithdrawlAmount);
        _amount = getKGCAmount( _amount);

        require(_amount >= minimumWithdrawl,"invalid Amount.");
        

        for (uint i=0; i < ownerInfo[msg.sender].ownerIs.length; i++){

            uint256 ownerTotalStakeCount = userRegistered[ownerInfo[msg.sender].ownerIs[i]].noOfStakes;

            

            for(uint j=0; j< ownerTotalStakeCount; j++){

                uint256 ownerStakeAmount = stakeInfo[ownerInfo[msg.sender].ownerIs[i]][j].stakeAmount;

                require(block.timestamp > stakeInfo[ownerInfo[msg.sender].ownerIs[i]][j].stakeStartTime,
                    "couldent be ablee to get reward before stake started.");

                if(block.timestamp > stakeInfo[ownerInfo[msg.sender].ownerIs[i]][j].stakeEndTime){

                    referalRewardCalculation(
                        stakeInfo[ownerInfo[msg.sender].ownerIs[i]][j].stakeStartTime,
                        stakeInfo[ownerInfo[msg.sender].ownerIs[i]][j].stakeEndTime,
                        msg.sender,
                        ownerInfo[msg.sender].ownerIs[i],
                        ownerStakeAmount,j,i);

                }else{

                    referalRewardCalculation(
                        stakeInfo[ownerInfo[msg.sender].ownerIs[i]][j].stakeStartTime,
                        block.timestamp,
                        msg.sender,
                        ownerInfo[msg.sender].ownerIs[i],
                        ownerStakeAmount,j,i);
                }

            }

            uint256 previousWithdrawlAmount = ownerInfo[msg.sender].deducteAmount[i];
        }
    }

    
    function referalRewardCalculation(
        uint256 startTime,
        uint256 endTime,
        address referalPerson, 
        address owner,
        uint256 ownerStakeAmount,
        uint256 stakeCount,
        uint256 ownerCount) private {
       
        uint256 totaldays = calculateTotalMinutes(startTime,endTime);
        
        uint256 previousDays = referalInfo[referalPerson][owner][stakeCount];
        uint256 rewardDays = totaldays.sub(previousDays);
        
        // require(rewardDays > 0,"please wait for atlseat day!");
        referalInfo[referalPerson][owner][stakeCount] = totaldays;
        
        uint256 totalPercentage = perdayPercentage.mul(rewardDays);

        uint256 totalReward = calculatePercentage(ownerStakeAmount, totalPercentage);

        uint256 Ownerlevel = ownerInfo[referalPerson].levelNo[ownerCount];

        uint256 referalPercantage = getPercentage(Ownerlevel);
        uint256 referalReward = calculatePercentage(totalReward, referalPercantage);
        userRegistered[referalPerson].totalReward += referalReward;
    }


    function getPercentage(uint level) private pure returns (uint256) {
    if (level == 1) {
        return 50 * 100;
    } else if (level == 2) {
        return 10 * 100;
    } else if (level >= 3 && level <= 5) {
        return 5 * 100;
    } else if (level >= 6 && level <= 10) {
        return 3 * 100;
    } else if (level >= 11 && level <= 30) {
        return 2 * 100;
    } else if (level >= 31 && level <= 50) {
        return 1 * 100;
    } else {
        return 50;
    }
}


     function calculateTotalMinutes(uint256 _startTime, uint256 _endTime) public pure returns(uint256) {
        require(_endTime > _startTime, "End time must be greater than start time");

        uint256 timeDifference = _endTime - _startTime;
        uint256 totalMinutes = (timeDifference / 1 minutes);

        return totalMinutes;
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

        return _kgcAmount[1];

    } 


    // function setRewardPercentages() private {
        
    //     rewardLevelPercentages.push(50);  // 50%
    //     rewardLevelPercentages.push(10);  // 10%
    //     rewardLevelPercentages.push(5);   // 5%
    //     rewardLevelPercentages.push(3);   // 3%
    //     rewardLevelPercentages.push(2);   // 2%
    //     rewardLevelPercentages.push(1);   // 1%
    // }


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

// KGC = 0x7Fd1b9De1eca936A3F840036A14654C62BDE2E3d
// USDC = 0x7721CD0E41f213D58Cf815EFdb730Aca23e4E87E
// router = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1

// 0x0000000000000000000000000000000000000000

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
// 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
// 0x17F6AD8Ef982297579C203069C1DbfFE4348c372
// 0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678

// org1 = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148
// org2 = 0x583031D1113aD414F02576BD6afaBfb302140225
// org3 = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB
// fiscl = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C

//  mint :0xf8e81D47203A594245E36C48e151709F0C19fBe8
// mrkt = 0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47


// how much busd aginst one gen.
    // function getKGCPrice(uint256 _kgcAmount) public view  returns(uint256){
        
    //     address[] memory pathTogetKGCPrice = new address[](2);
    //     pathTogetKGCPrice[0] = kgcAddress;
    //     pathTogetKGCPrice[1] = usdcAddress;

    //     uint256[] memory _kgcPrice;
    //     _kgcPrice = pancakeRouter.getAmountsOut(_kgcAmount,pathTogetKGCPrice);
        
    //     return _kgcPrice[1];
    // }
