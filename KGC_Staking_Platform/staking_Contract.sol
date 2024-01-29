// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
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


    uint256 public registrerationFee;
    uint256 public minimumAmount;
    uint256 public maximumAmount;
    uint256 public totalDuration;
    uint256[] public rewardLevelPercentages;

    address usdcAddress;
    address kgcAddress;


    struct UserRegistered{
        bool haveReferal;
        bool registered;
        uint256 noOfreferals;
    }
    
    struct Stake {
        uint256 stakeAmount;
        uint256 totalStakedReward;
        uint256 totalReferalReward;
    }
   
   
    mapping(address => Stake) public stakeInfo;
    mapping(address => UserRegistered) public userRegistered;
    mapping(address => mapping(uint256 => address)) public referalPerson;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public referalPersonLevel;
    
    event Registered(address regissteredUser, address referalPerson, uint256 _fee);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _kgcToken, address _usdcToken, address _pancakeRouter) initializer public {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        kgcToken = IBEP20(_kgcToken);
        usdcToken = IBEP20(_usdcToken);
        registrerationFee = 5 * 1e18;
        minimumAmount = 2 * 1e18;
        maximumAmount = 50 * 1e18;
        totalDuration = 500 days;
        usdcAddress = _usdcToken;
        kgcAddress = _kgcToken;
        pancakeRouter = IPancakeRouter01(_pancakeRouter);

        setRewardPercentages();
    }
    function registerUser(uint256 _fee, address referalAddress) external {
        
        require(referalAddress != msg.sender && referalAddress != address(0), "invalid referal Address!");
        require (_fee >= registrerationFee, "Invalid fee.");

        userRegistered[msg.sender].haveReferal = true;
        userRegistered[msg.sender].registered = true;


        if(userRegistered[msg.sender].haveReferal){

            if(!userRegistered[referalAddress].haveReferal){

                userRegistered[msg.sender].noOfreferals = 1;
                referalPerson[msg.sender][0] = referalAddress;
                referalPersonLevel[msg.sender][0][referalAddress] = 1;

            }else{
                
                uint256 previousReferal = userRegistered[referalAddress].noOfreferals;
               
                for(uint256 i=0; i < previousReferal; i++){
                    
                    referalPerson[msg.sender][i] = referalPerson[referalAddress][i];
                    referalPersonLevel[msg.sender][i][referalPerson[msg.sender][i]] = 
                    (referalPersonLevel[referalAddress][i][referalPerson[referalAddress][i]] + 1);
                    userRegistered[msg.sender].noOfreferals ++;

                }
                    referalPerson[msg.sender][previousReferal] = referalAddress;
                    referalPersonLevel[msg.sender][previousReferal][referalAddress] =  1;
                    userRegistered[msg.sender].noOfreferals++;
            }
        }

    }





   
    function stakeTokens(uint256 _amount) external  {
        
        require(_amount >= minimumAmount && _amount <= maximumAmount, "invalid amount!");
        require(userRegistered[msg.sender].registered, "Plaese register!");

        uint256 kgcTokenAmount = getKGCAmount(_amount);

        require(kgcToken.balanceOf(msg.sender) >= kgcTokenAmount,"insufficient Kgc balancce.");

        stakeInfo[msg.sender].stakeAmount = _amount;

    }

    function getKGCAmount(uint256 _usdcAmount) public view returns(uint256){
        
        address[] memory pathTogetKGC = new address[](2);
        pathTogetKGC[0] = usdcAddress;
        pathTogetKGC[1] = kgcAddress;

        uint256[] memory _kgcAmount;
        _kgcAmount = pancakeRouter.getAmountsOut(_usdcAmount,pathTogetKGC);

        return _kgcAmount[1];

    } 

    // how much busd aginst one gen.
    function getKGCPrice(uint256 _kgcAmount) public  view returns(uint256){
        
        address[] memory pathTogetKGCPrice = new address[](2);
        pathTogetKGCPrice[0] = kgcAddress;
        pathTogetKGCPrice[1] = usdcAddress;

        uint256[] memory _kgcPrice;
        _kgcPrice = pancakeRouter.getAmountsOut(_kgcAmount,pathTogetKGCPrice);

        return _kgcPrice[1];
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

// 0x0000000000000000000000000000000000000000

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB


// org1 = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148
// org2 = 0x583031D1113aD414F02576BD6afaBfb302140225
// org3 = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB
// fiscl = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C

//  mint :0xf8e81D47203A594245E36C48e151709F0C19fBe8
// mrkt = 0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47
