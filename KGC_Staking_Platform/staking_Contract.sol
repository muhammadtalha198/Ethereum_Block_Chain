// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";



interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
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
    IBEP20 public usdtToken;


    struct Stake {
        uint256 stakeAmount;
        uint256 totalReward;
    }




    
    uint256 public registrerationFee;
    uint256 public minimumAmount;
    uint256 public maximumAmount;
    uint256 public totalDuration;
    uint256[] public rewardLevelPercentages;




    
    
    
    mapping(address => Stake) public stakeInfo;


    event Registered(address registeredUser, uint256 fee);

    
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _kgcToken, address _usdtToken) initializer public {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        kgcToken = IBEP20(_kgcToken);
        usdtToken = IBEP20(_usdtToken);
        registrerationFee = 5 * 1e18;
        minimumAmount = 2 * 1e18;
        maximumAmount = 50 * 1e18;
        totalDuration = 500 days;

        setRewardPercentages();
    }


    struct UserRegistered{
        bool registered;
        address directReferal;
        mapping(uint256 => ReferalInfo) referalInfo;
    }

    struct ReferalInfo{
        uint256 referalLevel;
        address referalPerson;
    }
    
    mapping(address => UserRegistered) public userRegistered;
    mapping(address => mapping(address => bool)) public referrals;



    function registerUser(uint256 _fee, address referalAddress) external {
        
        require(referalAddress != msg.sender && referalAddress != address(0), "invalid referal Address!");
        require (_fee >= registrerationFee, "Invalid fee.");



        userRegistered[msg.sender].registered = true;

        if(userRegistered[referalAddress].registered){
             userRegistered[msg.sender][i] = userRegistered[referalAddress].directReferal;

        }

        for(uint256 i=0; i<userRegistered[msg.sender].noOfRefferals; i++){
            userRegistered[msg.sender].referalInfo[i].referalLevel = i + 1;

        }
        
        
        
        usdtToken.transferFrom(msg.sender, owner(), _fee);

        emit Registered(msg.sender,_fee);
    }

   
   
   
   
   
   
   
   
   
    function stakeTokens(uint256 _amount, address referalAddress) external  {
        
        require(_amount >= minimumAmount && _amount <= maximumAmount, "invalid amount!");
        require(userRegistered[msg.sender].registered, "Plaese register!");

        stakeInfo[msg.sender].stakeAmount = _amount;
        stakeInfo[msg.sender].referalPerson = referalAddress;
        stakeInfo[msg.sender].noOfRefferals += 1;






    }






    function setRewardPercentages() private {
        
        rewardLevelPercentages.push(50);  // 50%
        rewardLevelPercentages.push(10);  // 10%
        rewardLevelPercentages.push(5);   // 5%
        rewardLevelPercentages.push(3);   // 3%
        rewardLevelPercentages.push(2);   // 2%
        rewardLevelPercentages.push(1);   // 1%
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
